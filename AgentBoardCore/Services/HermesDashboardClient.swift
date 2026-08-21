import Foundation

/// Raw HTTP + auth wrapper around a **remote** Hermes dashboard
/// (`http://<host>:9119`), used by `HTTPKanbanBackend` to read that host's
/// kanban board over `/api/plugins/kanban/*` instead of the local
/// `~/.hermes/kanban.db` that `KanbanDataService` reads.
///
/// The dashboard has three possible auth postures, distinguished lazily on
/// first use by probing an unauthenticated `GET /api/plugins/kanban/board`
/// and caching the result for the client's lifetime:
///  - **Gated** (typical remote host): the probe 401s with a body carrying
///    `"reason":"no_cookie"` (or a `login_url`). Auth is
///    `POST /auth/password-login` -> session cookies.
///  - **Ungated/loopback**: the probe 401s with a bare `{"detail":"Unauthorized"}`.
///    Auth is a token scraped out of the dashboard SPA's HTML
///    (`window.__HERMES_SESSION_TOKEN__="..."`), sent back as
///    `X-Hermes-Session-Token`. Loopback-only.
///  - **None**: the probe already returns `200` — some hosts run with
///    `auth_required = false`.
public actor HermesDashboardClient {
    public struct Credentials: Sendable {
        public let username: String
        public let password: String

        public init(username: String, password: String) {
            self.username = username
            self.password = password
        }
    }

    public enum DashboardError: LocalizedError {
        case notAuthenticated(String)
        case requestFailed(String)
        case decodingFailed(String)
        case unsupportedAuthMode(String)
        case unsupportedQuery(String)

        public var errorDescription: String? {
            switch self {
            case let .notAuthenticated(message):
                "Not authenticated with the Hermes dashboard: \(message)"
            case let .requestFailed(message):
                "Hermes dashboard request failed: \(message)"
            case let .decodingFailed(message):
                "Could not decode Hermes dashboard response: \(message)"
            case let .unsupportedAuthMode(message):
                "Unsupported Hermes dashboard auth mode: \(message)"
            case let .unsupportedQuery(message):
                "Unsupported Hermes dashboard query: \(message)"
            }
        }
    }

    /// Which credential (if any) the dashboard is currently asking for.
    /// `.gated`'s cookie lives separately in `cookieHeader`, not in the case
    /// itself, because a login can refresh the cookie without changing mode.
    private enum AuthMode {
        case none
        case gated
        case tokenLoopback(String)
    }

    private let baseURL: URL
    private let credentials: Credentials?
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    private var authMode: AuthMode?
    /// Captured from `Set-Cookie` on a successful gated login, replayed as a
    /// `Cookie` request header. Captured and replayed manually — rather than
    /// relying on the injected `URLSession`'s own `httpCookieStorage` — so
    /// gated auth behaves identically regardless of which session
    /// configuration the caller injects (shared, ephemeral, or a
    /// `MockURLProtocol`-backed test session, whose cookie-jar wiring through
    /// a custom `URLProtocol` isn't guaranteed).
    private var cookieHeader: String?

    public init(baseURL: URL, credentials: Credentials?, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.credentials = credentials
        self.session = session
    }

    // MARK: - Public API

    /// Issues `GET path`, authenticating with whatever credential the
    /// current auth mode needs. A `401` triggers exactly one
    /// re-authentication + retry (dashboard sessions expire); a second
    /// consecutive `401` throws `notAuthenticated`.
    public func get<T: Decodable>(_ path: String, as type: T.Type) async throws -> T {
        try await request(method: "GET", path: path, body: nil, as: type)
    }

    /// Issues `POST path` with a JSON-encoded `body`, authenticating with
    /// whatever credential the current auth mode needs.
    ///
    /// A `401` triggers exactly one re-authentication + retry, same as
    /// `get`. Retrying a non-idempotent POST like this is safe because a
    /// `401` is rejected by the dashboard's auth layer *before* the route
    /// handler runs — the first attempt never reached application code, so
    /// nothing was applied server-side for the retry to duplicate. The
    /// retry is really the first attempt that gets a chance to execute.
    public func post<Body: Encodable & Sendable, T: Decodable>(
        _ path: String,
        body: Body,
        as type: T.Type
    ) async throws -> T {
        try await request(method: "POST", path: path, body: encodeBody(body), as: type)
    }

    /// Issues `PATCH path` with a JSON-encoded `body`. See `post(_:body:as:)`
    /// for why retrying after a single `401` is safe for a mutating request.
    public func patch<Body: Encodable & Sendable, T: Decodable>(
        _ path: String,
        body: Body,
        as type: T.Type
    ) async throws -> T {
        try await request(method: "PATCH", path: path, body: encodeBody(body), as: type)
    }

    private func encodeBody<Body: Encodable>(_ body: Body) throws -> Data {
        do {
            return try encoder.encode(body)
        } catch {
            throw DashboardError.requestFailed("failed to encode request body: \(error)")
        }
    }

    private func request<T: Decodable>(
        method: String,
        path: String,
        body: Data?,
        as type: T.Type
    ) async throws -> T {
        let mode = try await resolvedAuthMode()
        let (data, response) = try await performRequest(path: path, mode: mode, method: method, body: body)
        let http = try httpResponse(response, path: path)

        guard http.statusCode == 401 else {
            try validateSuccess(http, data: data, path: path)
            return try decode(data, path: path)
        }

        try await reauthenticate(mode: mode)
        let retryMode = authMode ?? mode
        let (retryData, retryResponse) = try await performRequest(path: path, mode: retryMode, method: method, body: body)
        let retryHTTP = try httpResponse(retryResponse, path: path)

        guard retryHTTP.statusCode != 401 else {
            throw DashboardError.notAuthenticated(
                "session expired and re-authentication did not resolve a second 401 for \(path)"
            )
        }
        try validateSuccess(retryHTTP, data: retryData, path: path)
        return try decode(retryData, path: path)
    }

    // MARK: - Auth-mode resolution

    private func resolvedAuthMode() async throws -> AuthMode {
        if let authMode {
            try await ensureCredentialed(for: authMode)
            return authMode
        }
        let mode = try await detectAuthMode()
        authMode = mode
        try await ensureCredentialed(for: mode)
        return mode
    }

    /// Detection already fetches the loopback token as a side effect (it has
    /// to, to tell gated apart from ungated), so only gated mode needs an
    /// extra step here: log in once, up front, so the very first real
    /// request doesn't eat a guaranteed 401.
    private func ensureCredentialed(for mode: AuthMode) async throws {
        guard case .gated = mode, cookieHeader == nil else { return }
        try await performGatedLogin()
    }

    private func reauthenticate(mode: AuthMode) async throws {
        switch mode {
        case .none:
            // The server's auth requirement flipped out from under us since
            // the last detection; redetect from scratch.
            authMode = nil
            _ = try await resolvedAuthMode()
        case .gated:
            try await performGatedLogin()
        case .tokenLoopback:
            let token = try await fetchLoopbackToken()
            authMode = .tokenLoopback(token)
        }
    }

    private func detectAuthMode() async throws -> AuthMode {
        let request = URLRequest(url: endpointURL("api/plugins/kanban/board"))
        let (data, response) = try await send(request)
        let http = try httpResponse(response, path: "api/plugins/kanban/board")

        if http.statusCode == 200 {
            return .none
        }
        guard http.statusCode == 401 else {
            throw DashboardError.requestFailed(
                "unexpected status \(http.statusCode) while probing auth mode"
            )
        }
        if isGatedUnauthenticatedBody(data) {
            return .gated
        }
        return .tokenLoopback(try await fetchLoopbackToken())
    }

    private func isGatedUnauthenticatedBody(_ data: Data) -> Bool {
        guard let probe = try? decoder.decode(UnauthenticatedProbe.self, from: data) else { return false }
        return probe.reason == "no_cookie" || probe.loginURL != nil
    }

    // MARK: - Gated (cookie) auth

    private func performGatedLogin() async throws {
        guard let credentials else {
            throw DashboardError.notAuthenticated(
                "the dashboard requires a login (gated auth mode) but no credentials were configured"
            )
        }

        let provider = await discoverPasswordProvider()
        var request = URLRequest(url: endpointURL("auth/password-login"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(
            LoginRequest(provider: provider, username: credentials.username, password: credentials.password)
        )

        let (data, response) = try await send(request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DashboardError.notAuthenticated("password login failed: \(body.prefix(200))")
        }
        storeCookies(from: http)
    }

    private func discoverPasswordProvider() async -> String {
        let request = URLRequest(url: endpointURL("api/auth/providers"))
        guard let (data, response) = try? await send(request),
              let http = response as? HTTPURLResponse,
              http.statusCode == 200,
              let payload = try? decoder.decode(AuthProvidersResponse.self, from: data),
              let provider = payload.providers.first(where: { $0.supportsPassword == true }) else {
            return "basic"
        }
        return provider.name
    }

    private func storeCookies(from response: HTTPURLResponse) {
        guard let url = response.url,
              let headerFields = response.allHeaderFields as? [String: String] else { return }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: headerFields, for: url)
        guard !cookies.isEmpty else { return }
        cookieHeader = HTTPCookie.requestHeaderFields(with: cookies)["Cookie"]
    }

    // MARK: - Ungated/loopback (token) auth

    private func fetchLoopbackToken() async throws -> String {
        guard isLoopbackHost else {
            throw DashboardError.unsupportedAuthMode(
                "host \(baseURL.host ?? "?") is not loopback; the SPA session-token auth path is loopback-only"
            )
        }

        let (data, response) = try await send(URLRequest(url: baseURL))
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw DashboardError.requestFailed("could not load the dashboard root to scrape a session token")
        }
        guard let html = String(data: data, encoding: .utf8),
              let token = Self.extractSessionToken(from: html)?.nilIfEmpty else {
            throw DashboardError.notAuthenticated("no window.__HERMES_SESSION_TOKEN__ found in dashboard HTML")
        }
        return token
    }

    private var isLoopbackHost: Bool {
        guard let host = baseURL.host?.lowercased() else { return false }
        return host == "127.0.0.1" || host == "localhost" || host == "::1"
    }

    static func extractSessionToken(from html: String) -> String? {
        let marker = "window.__HERMES_SESSION_TOKEN__=\""
        guard let markerRange = html.range(of: marker) else { return nil }
        let remainder = html[markerRange.upperBound...]
        guard let closingQuote = remainder.firstIndex(of: "\"") else { return nil }
        return String(remainder[remainder.startIndex ..< closingQuote])
    }

    // MARK: - Request plumbing

    private func performRequest(
        path: String,
        mode: AuthMode,
        method: String,
        body: Data?
    ) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: endpointURL(path))
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        applyAuthHeaders(&request, mode: mode)
        return try await send(request)
    }

    private func applyAuthHeaders(_ request: inout URLRequest, mode: AuthMode) {
        switch mode {
        case .none:
            break
        case .gated:
            if let cookieHeader {
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }
        case let .tokenLoopback(token):
            request.setValue(token, forHTTPHeaderField: "X-Hermes-Session-Token")
        }
    }

    private func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch {
            throw DashboardError.requestFailed("\(request.url?.absoluteString ?? "?"): \(error.localizedDescription)")
        }
    }

    private func httpResponse(_ response: URLResponse, path: String) throws -> HTTPURLResponse {
        guard let http = response as? HTTPURLResponse else {
            throw DashboardError.requestFailed("no HTTP response for \(path)")
        }
        return http
    }

    private func validateSuccess(_ http: HTTPURLResponse, data: Data, path: String) throws {
        guard (200 ... 299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw DashboardError.requestFailed("\(path) returned HTTP \(http.statusCode): \(body.prefix(200))")
        }
    }

    private func decode<T: Decodable>(_ data: Data, path: String) throws -> T {
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw DashboardError.decodingFailed("\(path): \(error)")
        }
    }

    private func endpointURL(_ path: String) -> URL {
        baseURL.appending(path: path)
    }
}

// MARK: - Auth DTOs

private struct UnauthenticatedProbe: Decodable {
    let reason: String?
    let loginURL: String?

    enum CodingKeys: String, CodingKey {
        case reason
        case loginURL = "login_url"
    }
}

private struct AuthProvidersResponse: Decodable {
    struct Provider: Decodable {
        let name: String
        let supportsPassword: Bool?

        enum CodingKeys: String, CodingKey {
            case name
            case supportsPassword = "supports_password"
        }
    }

    let providers: [Provider]
}

private struct LoginRequest: Encodable {
    let provider: String
    let username: String
    let password: String
}
