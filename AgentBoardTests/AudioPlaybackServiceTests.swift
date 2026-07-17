import AgentBoardCore
import AVFoundation
import Foundation
import Testing

@Suite(.serialized)
@MainActor
struct AudioPlaybackServiceTests {
    @Test
    func togglePlaybackStartsPlaybackAndSetsActiveAttachment() throws {
        let service = AudioPlaybackService()
        let url = try Self.makeSilentWAVFile()
        let attachmentID = UUID()

        try service.togglePlayback(attachmentID: attachmentID, url: url)

        #expect(service.isPlaying)
        #expect(service.activeAttachmentID == attachmentID)
    }

    @Test
    func togglePlaybackOnSameAttachmentPauses() throws {
        let service = AudioPlaybackService()
        let url = try Self.makeSilentWAVFile()
        let attachmentID = UUID()

        try service.togglePlayback(attachmentID: attachmentID, url: url)
        #expect(service.isPlaying)

        try service.togglePlayback(attachmentID: attachmentID, url: url)

        #expect(!service.isPlaying)
        #expect(service.activeAttachmentID == attachmentID)
    }

    @Test
    func togglePlaybackOnDifferentAttachmentStealsPlayback() throws {
        let service = AudioPlaybackService()
        let firstURL = try Self.makeSilentWAVFile()
        let secondURL = try Self.makeSilentWAVFile()
        let firstID = UUID()
        let secondID = UUID()

        try service.togglePlayback(attachmentID: firstID, url: firstURL)
        #expect(service.activeAttachmentID == firstID)

        try service.togglePlayback(attachmentID: secondID, url: secondURL)

        #expect(service.activeAttachmentID == secondID)
        #expect(service.isPlaying)
    }

    @Test
    func togglePlaybackWithBogusURLThrowsCannotPlay() {
        let service = AudioPlaybackService()
        let bogusURL = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString).wav")

        #expect(throws: AudioPlaybackService.PlaybackError.self) {
            try service.togglePlayback(attachmentID: UUID(), url: bogusURL)
        }
    }

    // MARK: - Helpers

    private static func makeSilentWAVFile() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test-\(UUID().uuidString).wav")
        let format = try #require(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)

        let frameCount: AVAudioFrameCount = 8820 // ~0.2s at 44.1kHz
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount
        try file.write(from: buffer)

        return url
    }
}
