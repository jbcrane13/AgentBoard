import Foundation
import os

// MARK: - AttachmentUploadError

public enum AttachmentUploadError: LocalizedError, Sendable {
    case invalidURL
    case fileNotFound(URL)
    case encodingFailed(String)
    case httpError(statusCode: Int, body: String)
    case transportError(String)
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid upload URL."
        case let .fileNotFound(url):
            return "File not found at \(url.path)."
        case let .encodingFailed(detail):
            return "Failed to encode upload: \(detail)"
        case let .httpError(statusCode, body):
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty
                ? "Upload failed with HTTP \(statusCode)."
                : "Upload failed with HTTP \(statusCode): \(trimmed.prefix(200))"
        case let .transportError(message):
            return "Upload transport error: \(message)"
        case .cancelled:
            return "Upload was cancelled."
        }
    }
}

// MARK: - AttachmentUploadService

@MainActor
public final class AttachmentUploadService {
    private let logger = Logger(subsystem: "com.agentboard", category: "AttachmentUpload")
    private let session: URLSession
    private var activeUploads: [String: URLSessionUploadTask] = [:]

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Upload a single attachment to the given endpoint.
    /// Returns the remote URL on success, updates state via the progress callback.
    public func upload(
        attachment: ChatAttachment,
        to uploadURL: URL,
        apiKey: String? = nil,
        progressHandler: @Sendable @escaping (Double) -> Void
    ) async throws -> URL {
        guard let localURL = attachment.payload.localURL else {
            throw AttachmentUploadError.fileNotFound(URL(fileURLWithPath: "/dev/null"))
        }

        guard FileManager.default.fileExists(atPath: localURL.path) else {
            throw AttachmentUploadError.fileNotFound(localURL)
        }

        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: localURL)
        let mimeType = attachment.payload.mimeType ?? "application/octet-stream"
        let fileName = localURL.lastPathComponent

        var body = Data()
        body.append(Data("--\(boundary)\r\n".utf8))
        body.append(Data("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".utf8))
        body.append(Data("Content-Type: \(mimeType)\r\n\r\n".utf8))
        body.append(fileData)
        body.append(Data("\r\n--\(boundary)--\r\n".utf8))

        // Use URLSession upload task for progress tracking
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.uploadTask(with: request, from: body) { [weak self] data, response, error in
                if let error {
                    if let urlError = error as? URLError, urlError.code == .cancelled {
                        continuation.resume(throwing: AttachmentUploadError.cancelled)
                        return
                    }

                    let nsError = error as NSError
                    if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                        continuation.resume(throwing: AttachmentUploadError.cancelled)
                        return
                    }

                    continuation.resume(throwing: AttachmentUploadError.transportError(error.localizedDescription))
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: AttachmentUploadError.invalidURL)
                    return
                }

                guard (200 ... 299).contains(httpResponse.statusCode) else {
                    let body = String(data: data ?? Data(), encoding: .utf8) ?? ""
                    continuation.resume(throwing: AttachmentUploadError.httpError(
                        statusCode: httpResponse.statusCode, body: body
                    ))
                    return
                }

                // Try to extract remote URL from response
                if let data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let urlString = json["url"] as? String,
                   let remoteURL = URL(string: urlString) {
                    continuation.resume(returning: remoteURL)
                } else {
                    // Fallback: construct URL from upload endpoint + filename
                    let remoteURL = uploadURL.appendingPathComponent(fileName)
                    continuation.resume(returning: remoteURL)
                }
            }

            // Observe progress
            let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
                progressHandler(progress.fractionCompleted)
            }

            activeUploads[attachment.id] = task
            task.resume()

            // Clean up observation when done
            Task { @MainActor [weak self] in
                _ = observation // retain
                self?.activeUploads.removeValue(forKey: attachment.id)
            }
        }
    }

    /// Cancel an in-progress upload
    public func cancelUpload(attachmentID: String) {
        activeUploads[attachmentID]?.cancel()
        activeUploads.removeValue(forKey: attachmentID)
    }

    /// Cancel all active uploads
    public func cancelAll() {
        activeUploads.values.forEach { $0.cancel() }
        activeUploads.removeAll()
    }
}

// MARK: - Helper on AnyAttachmentPayload

extension AnyAttachmentPayload {
    var mimeType: String? {
        switch self {
        case let .image(payload): return payload.mimeType
        case let .video(payload): return payload.mimeType
        case let .file(payload): return payload.mimeType
        case let .audio(payload): return payload.mimeType
        case let .voiceRecording(payload): return payload.mimeType
        case .linkPreview: return nil
        }
    }
}
