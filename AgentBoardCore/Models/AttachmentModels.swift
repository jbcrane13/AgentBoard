import Foundation

// MARK: - AttachmentType

public enum AttachmentType: String, Codable, Sendable, CaseIterable {
    case image
    case video
    case audio
    case file
    case voiceRecording
    case linkPreview
}

// MARK: - LocalAttachmentState

public enum LocalAttachmentState: Sendable, Equatable {
    case pendingUpload
    case uploading(progress: Double)
    case uploaded(remoteURL: URL)
    case uploadingFailed(error: String)
    case downloaded(localURL: URL)
    case downloading(progress: Double)
}

extension LocalAttachmentState: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, progress, url, error
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .pendingUpload:
            try container.encode("pendingUpload", forKey: .type)
        case let .uploading(progress):
            try container.encode("uploading", forKey: .type)
            try container.encode(progress, forKey: .progress)
        case let .uploaded(remoteURL):
            try container.encode("uploaded", forKey: .type)
            try container.encode(remoteURL, forKey: .url)
        case let .uploadingFailed(error):
            try container.encode("uploadingFailed", forKey: .type)
            try container.encode(error, forKey: .error)
        case let .downloaded(localURL):
            try container.encode("downloaded", forKey: .type)
            try container.encode(localURL, forKey: .url)
        case let .downloading(progress):
            try container.encode("downloading", forKey: .type)
            try container.encode(progress, forKey: .progress)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "pendingUpload":
            self = .pendingUpload
        case "uploading":
            self = try .uploading(progress: container.decode(Double.self, forKey: .progress))
        case "uploaded":
            self = try .uploaded(remoteURL: container.decode(URL.self, forKey: .url))
        case "uploadingFailed":
            self = try .uploadingFailed(error: container.decode(String.self, forKey: .error))
        case "downloaded":
            self = try .downloaded(localURL: container.decode(URL.self, forKey: .url))
        case "downloading":
            self = try .downloading(progress: container.decode(Double.self, forKey: .progress))
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown LocalAttachmentState type: \(type)"
            ))
        }
    }
}

// MARK: - AttachmentPayload Protocol

public protocol AttachmentPayload: Codable, Sendable, Hashable {
    var type: AttachmentType { get }
}

// MARK: - Concrete Payload Types

public struct ImageAttachmentPayload: AttachmentPayload {
    public let type: AttachmentType = .image
    public var localURL: URL
    public var remoteURL: URL?
    public var width: Int?
    public var height: Int?
    public var mimeType: String

    public init(
        localURL: URL,
        remoteURL: URL? = nil,
        width: Int? = nil,
        height: Int? = nil,
        mimeType: String = "image/jpeg"
    ) {
        self.localURL = localURL
        self.remoteURL = remoteURL
        self.width = width
        self.height = height
        self.mimeType = mimeType
    }

    private enum CodingKeys: String, CodingKey {
        case localURL, remoteURL, width, height, mimeType
    }
}

public struct VideoAttachmentPayload: AttachmentPayload {
    public let type: AttachmentType = .video
    public var localURL: URL
    public var remoteURL: URL?
    public var thumbnailURL: URL?
    public var duration: TimeInterval?
    public var mimeType: String

    public init(
        localURL: URL,
        remoteURL: URL? = nil,
        thumbnailURL: URL? = nil,
        duration: TimeInterval? = nil,
        mimeType: String = "video/mp4"
    ) {
        self.localURL = localURL
        self.remoteURL = remoteURL
        self.thumbnailURL = thumbnailURL
        self.duration = duration
        self.mimeType = mimeType
    }

    private enum CodingKeys: String, CodingKey {
        case localURL, remoteURL, thumbnailURL, duration, mimeType
    }
}

public struct FileAttachmentPayload: AttachmentPayload {
    public let type: AttachmentType = .file
    public var localURL: URL
    public var remoteURL: URL?
    public var fileName: String
    public var fileSize: Int64?
    public var mimeType: String

    public init(
        localURL: URL,
        remoteURL: URL? = nil,
        fileName: String,
        fileSize: Int64? = nil,
        mimeType: String = "application/octet-stream"
    ) {
        self.localURL = localURL
        self.remoteURL = remoteURL
        self.fileName = fileName
        self.fileSize = fileSize
        self.mimeType = mimeType
    }

    private enum CodingKeys: String, CodingKey {
        case localURL, remoteURL, fileName, fileSize, mimeType
    }
}

public struct AudioAttachmentPayload: AttachmentPayload {
    public let type: AttachmentType = .audio
    public var localURL: URL
    public var remoteURL: URL?
    public var duration: TimeInterval?
    public var mimeType: String

    public init(
        localURL: URL,
        remoteURL: URL? = nil,
        duration: TimeInterval? = nil,
        mimeType: String = "audio/m4a"
    ) {
        self.localURL = localURL
        self.remoteURL = remoteURL
        self.duration = duration
        self.mimeType = mimeType
    }

    private enum CodingKeys: String, CodingKey {
        case localURL, remoteURL, duration, mimeType
    }
}

public struct VoiceRecordingPayload: AttachmentPayload {
    public let type: AttachmentType = .voiceRecording
    public var localURL: URL
    public var remoteURL: URL?
    public var duration: TimeInterval?
    public var waveformSamples: [Float]
    public var mimeType: String

    public init(
        localURL: URL,
        remoteURL: URL? = nil,
        duration: TimeInterval? = nil,
        waveformSamples: [Float] = [],
        mimeType: String = "audio/m4a"
    ) {
        self.localURL = localURL
        self.remoteURL = remoteURL
        self.duration = duration
        self.waveformSamples = waveformSamples
        self.mimeType = mimeType
    }

    private enum CodingKeys: String, CodingKey {
        case localURL, remoteURL, duration, waveformSamples, mimeType
    }
}

public struct LinkPreviewPayload: AttachmentPayload {
    public let type: AttachmentType = .linkPreview
    public var url: URL
    public var title: String?
    public var description: String?
    public var imageURL: URL?
    public var siteName: String?

    public init(
        url: URL,
        title: String? = nil,
        description: String? = nil,
        imageURL: URL? = nil,
        siteName: String? = nil
    ) {
        self.url = url
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.siteName = siteName
    }

    private enum CodingKeys: String, CodingKey {
        case url, title, description, imageURL, siteName
    }
}

// MARK: - AnyAttachmentPayload

public enum AnyAttachmentPayload: Sendable, Hashable {
    case image(ImageAttachmentPayload)
    case video(VideoAttachmentPayload)
    case file(FileAttachmentPayload)
    case audio(AudioAttachmentPayload)
    case voiceRecording(VoiceRecordingPayload)
    case linkPreview(LinkPreviewPayload)

    public var type: AttachmentType {
        switch self {
        case .image: return .image
        case .video: return .video
        case .file: return .file
        case .audio: return .audio
        case .voiceRecording: return .voiceRecording
        case .linkPreview: return .linkPreview
        }
    }

    public var localURL: URL? {
        switch self {
        case let .image(payload): return payload.localURL
        case let .video(payload): return payload.localURL
        case let .file(payload): return payload.localURL
        case let .audio(payload): return payload.localURL
        case let .voiceRecording(payload): return payload.localURL
        case .linkPreview: return nil
        }
    }

    public var remoteURL: URL? {
        switch self {
        case let .image(payload): return payload.remoteURL
        case let .video(payload): return payload.remoteURL
        case let .file(payload): return payload.remoteURL
        case let .audio(payload): return payload.remoteURL
        case let .voiceRecording(payload): return payload.remoteURL
        case .linkPreview: return nil
        }
    }
}

extension AnyAttachmentPayload: Codable {
    private enum CodingKeys: String, CodingKey {
        case type, payload
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type.rawValue, forKey: .type)
        switch self {
        case let .image(payload): try container.encode(payload, forKey: .payload)
        case let .video(payload): try container.encode(payload, forKey: .payload)
        case let .file(payload): try container.encode(payload, forKey: .payload)
        case let .audio(payload): try container.encode(payload, forKey: .payload)
        case let .voiceRecording(payload): try container.encode(payload, forKey: .payload)
        case let .linkPreview(payload): try container.encode(payload, forKey: .payload)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let typeRaw = try container.decode(String.self, forKey: .type)
        guard let attachmentType = AttachmentType(rawValue: typeRaw) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unknown attachment type: \(typeRaw)"
            ))
        }
        switch attachmentType {
        case .image:
            self = try .image(container.decode(ImageAttachmentPayload.self, forKey: .payload))
        case .video:
            self = try .video(container.decode(VideoAttachmentPayload.self, forKey: .payload))
        case .file:
            self = try .file(container.decode(FileAttachmentPayload.self, forKey: .payload))
        case .audio:
            self = try .audio(container.decode(AudioAttachmentPayload.self, forKey: .payload))
        case .voiceRecording:
            self = try .voiceRecording(container.decode(VoiceRecordingPayload.self, forKey: .payload))
        case .linkPreview:
            self = try .linkPreview(container.decode(LinkPreviewPayload.self, forKey: .payload))
        }
    }
}

// MARK: - ChatAttachment

public struct ChatAttachment: Identifiable, Sendable, Codable, Hashable {
    public let id: String
    public let type: AttachmentType
    public var state: LocalAttachmentState
    public var payload: AnyAttachmentPayload

    public init(
        id: String = UUID().uuidString,
        type: AttachmentType,
        state: LocalAttachmentState = .pendingUpload,
        payload: AnyAttachmentPayload
    ) {
        self.id = id
        self.type = type
        self.state = state
        self.payload = payload
    }

    public static func == (lhs: ChatAttachment, rhs: ChatAttachment) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// The remote URL if the attachment has been uploaded.
    public var remoteURL: URL? {
        switch state {
        case let .uploaded(url): return url
        default: return payload.remoteURL
        }
    }
}
