import Foundation
import os

// MARK: - LinkPreviewService

/// Detects URLs in message text and fetches Open Graph metadata for rich previews.
public final class LinkPreviewService: Sendable {
    private let logger = Logger(subsystem: "com.agentboard", category: "LinkPreview")
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Extract URLs from text content.
    public func detectURLs(in text: String) -> [URL] {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) else {
            return []
        }
        let range = NSRange(text.startIndex ..< text.endIndex, in: text)
        let matches = detector.matches(in: text, options: [], range: range)
        return matches.compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            let urlString = String(text[range])
            return URL(string: urlString)
        }
    }

    /// Fetch Open Graph metadata for a URL.
    public func fetchMetadata(for url: URL) async throws -> LinkPreviewPayload {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue(
            "Mozilla/5.0 (compatible; AgentBoard/1.0)",
            forHTTPHeaderField: "User-Agent"
        )

        let (data, _) = try await session.data(for: request)
        guard let html = String(data: data, encoding: .utf8) else {
            return LinkPreviewPayload(url: url)
        }

        return LinkPreviewPayload(
            url: url,
            title: extractMetaContent(from: html, property: "og:title")
                ?? extractTitle(from: html),
            description: extractMetaContent(from: html, property: "og:description")
                ?? extractMetaContent(from: html, name: "description"),
            imageURL: extractMetaContent(from: html, property: "og:image")
                .flatMap { URL(string: $0) },
            siteName: extractMetaContent(from: html, property: "og:site_name")
                ?? url.host()
        )
    }

    /// Build link preview attachments for all URLs in a message.
    public func buildPreviews(for text: String) async -> [ChatAttachment] {
        let urls = detectURLs(in: text)
        guard !urls.isEmpty else { return [] }

        // Only preview the first 3 URLs to avoid spam
        let previewURLs = Array(urls.prefix(3))

        var attachments: [ChatAttachment] = []
        for url in previewURLs {
            do {
                let payload = try await fetchMetadata(for: url)
                // Only create preview if we got meaningful metadata
                if payload.title != nil || payload.description != nil {
                    let attachment = ChatAttachment(
                        type: .linkPreview,
                        payload: .linkPreview(payload)
                    )
                    attachments.append(attachment)
                }
            } catch {
                logger.debug("Failed to fetch link preview for \(url): \(error.localizedDescription)")
            }
        }
        return attachments
    }

    // MARK: - HTML Parsing Helpers

    private func extractMetaContent(from html: String, property: String) -> String? {
        // Match <meta property="og:title" content="...">
        let pattern = #"<meta[^>]*property="\#(property)"[^>]*content="([^"]*)"[^>]*>"#
        if let match = extractFirstCapture(from: html, pattern: pattern) {
            return match
        }
        // Also try content before property
        let reversePattern = #"<meta[^>]*content="([^"]*)"[^>]*property="\#(property)"[^>]*>"#
        return extractFirstCapture(from: html, pattern: reversePattern)
    }

    private func extractMetaContent(from html: String, name: String) -> String? {
        let pattern = #"<meta[^>]*name="\#(name)"[^>]*content="([^"]*)"[^>]*>"#
        return extractFirstCapture(from: html, pattern: pattern)
    }

    private func extractTitle(from html: String) -> String? {
        let pattern = #"<title[^>]*>([^<]*)</title>"#
        return extractFirstCapture(from: html, pattern: pattern)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractFirstCapture(from html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(
                  in: html,
                  options: [],
                  range: NSRange(html.startIndex ..< html.endIndex, in: html)
              ),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: html) else {
            return nil
        }
        let result = String(html[range])
        return result.isEmpty ? nil : result
    }
}
