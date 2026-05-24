@testable import AgentBoardCore
import Foundation
import Testing

@Suite("Attachment Models")
struct AttachmentModelsTests {
    // MARK: - AttachmentType

    @Test("AttachmentType Codable round-trip")
    func attachmentTypeCodable() throws {
        for type in AttachmentType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(AttachmentType.self, from: data)
            #expect(decoded == type)
        }
    }

    // MARK: - LocalAttachmentState

    @Test("LocalAttachmentState.pendingUpload round-trip")
    func pendingUploadState() throws {
        try roundTrip(LocalAttachmentState.pendingUpload)
    }

    @Test("LocalAttachmentState.uploading round-trip")
    func uploadingState() throws {
        try roundTrip(LocalAttachmentState.uploading(progress: 0.42))
    }

    @Test("LocalAttachmentState.uploaded round-trip")
    func uploadedState() throws {
        try roundTrip(LocalAttachmentState
            .uploaded(remoteURL: #require(URL(string: "https://example.com/img.jpg"))))
    }

    @Test("LocalAttachmentState.uploadingFailed round-trip")
    func uploadingFailedState() throws {
        try roundTrip(LocalAttachmentState.uploadingFailed(error: "Network timeout"))
    }

    @Test("LocalAttachmentState.downloaded round-trip")
    func downloadedState() throws {
        try roundTrip(LocalAttachmentState.downloaded(localURL: URL(fileURLWithPath: "/tmp/test.jpg")))
    }

    @Test("LocalAttachmentState.downloading round-trip")
    func downloadingState() throws {
        try roundTrip(LocalAttachmentState.downloading(progress: 0.75))
    }

    // MARK: - Payload Types

    @Test("ImageAttachmentPayload round-trip")
    func imagePayload() throws {
        let payload = ImageAttachmentPayload(
            localURL: URL(fileURLWithPath: "/tmp/photo.jpg"),
            width: 1920,
            height: 1080,
            mimeType: "image/jpeg"
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(ImageAttachmentPayload.self, from: data)
        #expect(decoded.localURL == payload.localURL)
        #expect(decoded.width == 1920)
        #expect(decoded.height == 1080)
        #expect(decoded.mimeType == "image/jpeg")
    }

    @Test("VideoAttachmentPayload round-trip")
    func videoPayload() throws {
        let payload = VideoAttachmentPayload(
            localURL: URL(fileURLWithPath: "/tmp/video.mp4"),
            duration: 120.5,
            mimeType: "video/mp4"
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(VideoAttachmentPayload.self, from: data)
        #expect(decoded.localURL == payload.localURL)
        #expect(decoded.duration == 120.5)
    }

    @Test("FileAttachmentPayload round-trip")
    func filePayload() throws {
        let payload = FileAttachmentPayload(
            localURL: URL(fileURLWithPath: "/tmp/doc.pdf"),
            fileName: "report.pdf",
            fileSize: 1024,
            mimeType: "application/pdf"
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(FileAttachmentPayload.self, from: data)
        #expect(decoded.fileName == "report.pdf")
        #expect(decoded.fileSize == 1024)
    }

    @Test("AudioAttachmentPayload round-trip")
    func audioPayload() throws {
        let payload = AudioAttachmentPayload(
            localURL: URL(fileURLWithPath: "/tmp/audio.m4a"),
            duration: 60.0
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(AudioAttachmentPayload.self, from: data)
        #expect(decoded.duration == 60.0)
        #expect(decoded.mimeType == "audio/m4a")
    }

    @Test("VoiceRecordingPayload round-trip")
    func voiceRecordingPayload() throws {
        let payload = VoiceRecordingPayload(
            localURL: URL(fileURLWithPath: "/tmp/voice.m4a"),
            duration: 15.0,
            waveformSamples: [0.1, 0.5, 0.8, 0.3, 0.6]
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(VoiceRecordingPayload.self, from: data)
        #expect(decoded.waveformSamples.count == 5)
        #expect(decoded.waveformSamples[2] == 0.8)
    }

    @Test("LinkPreviewPayload round-trip")
    func linkPreviewPayload() throws {
        let payload = try LinkPreviewPayload(
            url: #require(URL(string: "https://example.com")),
            title: "Example",
            description: "An example site",
            siteName: "Example.com"
        )
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(LinkPreviewPayload.self, from: data)
        #expect(decoded.title == "Example")
        #expect(decoded.siteName == "Example.com")
    }

    // MARK: - AnyAttachmentPayload

    @Test("AnyAttachmentPayload Codable for each type")
    func anyAttachmentPayloadCodable() throws {
        let cases: [AnyAttachmentPayload] = try [
            .image(ImageAttachmentPayload(localURL: URL(fileURLWithPath: "/tmp/i.jpg"))),
            .video(VideoAttachmentPayload(localURL: URL(fileURLWithPath: "/tmp/v.mp4"))),
            .file(FileAttachmentPayload(localURL: URL(fileURLWithPath: "/tmp/f.pdf"), fileName: "f.pdf")),
            .audio(AudioAttachmentPayload(localURL: URL(fileURLWithPath: "/tmp/a.m4a"))),
            .voiceRecording(VoiceRecordingPayload(localURL: URL(fileURLWithPath: "/tmp/vr.m4a"))),
            .linkPreview(LinkPreviewPayload(url: #require(URL(string: "https://example.com"))))
        ]

        for payload in cases {
            let data = try JSONEncoder().encode(payload)
            let decoded = try JSONDecoder().decode(AnyAttachmentPayload.self, from: data)
            #expect(decoded.type == payload.type)
        }
    }

    // MARK: - ChatAttachment

    @Test("ChatAttachment round-trip")
    func chatAttachmentCodable() throws {
        let attachment = ChatAttachment(
            id: "test-id-123",
            type: .image,
            state: .uploading(progress: 0.5),
            payload: .image(ImageAttachmentPayload(
                localURL: URL(fileURLWithPath: "/tmp/photo.jpg"),
                width: 800,
                height: 600
            ))
        )
        let data = try JSONEncoder().encode(attachment)
        let decoded = try JSONDecoder().decode(ChatAttachment.self, from: data)
        #expect(decoded.id == "test-id-123")
        #expect(decoded.type == .image)
        #expect(decoded.state == .uploading(progress: 0.5))
    }

    // MARK: - ConversationMessage backward compatibility

    @Test("ConversationMessage decodes without attachments field")
    func conversationMessageBackwardCompat() throws {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "conversationID": "\(UUID().uuidString)",
            "role": "user",
            "content": "Hello",
            "createdAt": \(Date().timeIntervalSince1970),
            "isStreaming": false
        }
        """
        let jsonData = Data(json.utf8)

        let decoded = try JSONDecoder().decode(ConversationMessage.self, from: jsonData)
        #expect(decoded.content == "Hello")
        #expect(decoded.attachments.isEmpty)
    }

    @Test("ConversationMessage decodes with attachments field")
    func conversationMessageWithAttachments() throws {
        let msg = ConversationMessage(
            conversationID: UUID(),
            role: .user,
            content: "Check this image",
            attachments: [
                ChatAttachment(
                    type: .image,
                    payload: .image(ImageAttachmentPayload(localURL: URL(fileURLWithPath: "/tmp/i.jpg")))
                )
            ]
        )
        let data = try JSONEncoder().encode(msg)
        let decoded = try JSONDecoder().decode(ConversationMessage.self, from: data)
        #expect(decoded.attachments.count == 1)
        #expect(decoded.attachments.first?.type == .image)
    }

    // MARK: - Helpers

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        #expect(decoded == value)
    }
}
