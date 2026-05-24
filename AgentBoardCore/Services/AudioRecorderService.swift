import AVFoundation
import Foundation
import Observation
import os

// MARK: - AudioRecorderService

/// Records audio and generates waveform samples for voice messages.
@MainActor
@Observable
public final class AudioRecorderService: NSObject {
    private let logger = Logger(subsystem: "com.agentboard", category: "AudioRecorder")

    public private(set) var isRecording = false
    public private(set) var isPaused = false
    public private(set) var duration: TimeInterval = 0
    public private(set) var waveformSamples: [Float] = []

    @ObservationIgnored private var audioRecorder: AVAudioRecorder?
    @ObservationIgnored private var meterTask: Task<Void, Never>?
    @ObservationIgnored private var recordingURL: URL?

    override public init() {
        super.init()
    }

    /// Request microphone permission.
    public func requestPermission() async -> Bool {
        #if os(iOS)
            await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        #else
            return true
        #endif
    }

    /// Start recording audio.
    public func startRecording() throws {
        #if os(iOS)
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
        #endif

        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent("voice-\(UUID().uuidString).m4a")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.isMeteringEnabled = true
        recorder.delegate = self
        recorder.record()

        audioRecorder = recorder
        isRecording = true
        isPaused = false
        duration = 0
        waveformSamples = []

        startMetering()
    }

    /// Pause recording.
    public func pauseRecording() {
        audioRecorder?.pause()
        isPaused = true
        stopMetering()
    }

    /// Resume recording.
    public func resumeRecording() {
        audioRecorder?.record()
        isPaused = false
        startMetering()
    }

    /// Stop recording and return the result.
    public func stopRecording() -> VoiceRecordingResult? {
        guard let recorder = audioRecorder else { return nil }

        let finalDuration = duration
        let finalSamples = waveformSamples
        let url = recorder.url

        recorder.stop()
        audioRecorder = nil
        isRecording = false
        isPaused = false
        stopMetering()

        #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false)
        #endif

        return VoiceRecordingResult(
            url: url,
            duration: finalDuration,
            waveformSamples: finalSamples
        )
    }

    /// Cancel recording without saving.
    public func cancelRecording() {
        if let recorder = audioRecorder {
            recorder.stop()
            recorder.deleteRecording()
        }
        audioRecorder = nil
        isRecording = false
        isPaused = false
        stopMetering()
        #if os(iOS)
            try? AVAudioSession.sharedInstance().setActive(false)
        #endif
    }

    // MARK: - Metering loop

    private func startMetering() {
        meterTask?.cancel()
        meterTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                guard let self else { return }
                self.updateMeter()
            }
        }
    }

    private func stopMetering() {
        meterTask?.cancel()
        meterTask = nil
    }

    private func updateMeter() {
        guard let recorder = audioRecorder, recorder.isRecording else { return }
        recorder.updateMeters()

        duration = recorder.currentTime

        let power = recorder.averagePower(forChannel: 0)
        // Normalize power from -160...0 to 0...1
        let normalized = max(0, min(1, (power + 160) / 160))
        waveformSamples.append(normalized)

        // Keep last 100 samples for display
        if waveformSamples.count > 100 {
            waveformSamples.removeFirst(waveformSamples.count - 100)
        }
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecorderService: AVAudioRecorderDelegate {
    // swiftlint:disable:next modifier_order
    public nonisolated func audioRecorderDidFinishRecording(_: AVAudioRecorder, successfully _: Bool) {
        Task { @MainActor in
            isRecording = false
            stopMetering()
        }
    }

    // swiftlint:disable:next modifier_order
    public nonisolated func audioRecorderEncodeErrorDidOccur(_: AVAudioRecorder, error: Error?) {
        Task { @MainActor in
            logger.error("Audio recording error: \(error?.localizedDescription ?? "unknown")")
            isRecording = false
            stopMetering()
        }
    }
}

// MARK: - VoiceRecordingResult

public struct VoiceRecordingResult: Sendable {
    public let url: URL
    public let duration: TimeInterval
    public let waveformSamples: [Float]

    public init(url: URL, duration: TimeInterval, waveformSamples: [Float]) {
        self.url = url
        self.duration = duration
        self.waveformSamples = waveformSamples
    }

    /// Convert to a ChatAttachment for sending.
    public func toAttachment() -> ChatAttachment {
        ChatAttachment(
            type: .voiceRecording,
            payload: .voiceRecording(VoiceRecordingPayload(
                localURL: url,
                duration: duration,
                waveformSamples: waveformSamples
            ))
        )
    }
}
