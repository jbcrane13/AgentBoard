import Foundation

final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    typealias Handler = @Sendable (URLRequest) throws -> (HTTPURLResponse, Data)

    private static let sessionHeader = "X-AgentBoard-Mock-Session"
    private static let lock = NSLock()
    // swiftformat:disable:next modifierOrder
    nonisolated(unsafe) private static var handlers: [String: Handler] = [:]

    static func makeSession(handler: @escaping Handler) -> URLSession {
        let sessionID = UUID().uuidString
        lock.lock()
        defer { lock.unlock() }
        handlers[sessionID] = handler

        let configuration = URLSessionConfiguration.ephemeral
        configuration.httpAdditionalHeaders = [sessionHeader: sessionID]
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let sessionID = request.value(forHTTPHeaderField: Self.sessionHeader),
              let handler = Self.handler(for: sessionID) else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    private static func handler(for sessionID: String) -> Handler? {
        lock.lock()
        defer { lock.unlock() }
        return handlers[sessionID]
    }
}

func makeMockSession(handler: @escaping MockURLProtocol.Handler) -> URLSession {
    MockURLProtocol.makeSession(handler: handler)
}
