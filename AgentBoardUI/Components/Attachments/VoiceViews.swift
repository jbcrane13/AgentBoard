import AgentBoardCore
import SwiftUI

// MARK: - VoiceRecordingButton

/// Microphone button that toggles voice recording mode.
struct VoiceRecordingButton: View {
    @Bindable var recorder: AudioRecorderService
    var onRecorded: (VoiceRecordingResult) -> Void
    var onCancel: () -> Void

    @State private var isRecordingMode = false

    var body: some View {
        if isRecordingMode {
            recordingControls
        } else {
            micButton
        }
    }

    private var micButton: some View {
        Button {
            Task {
                let granted = await recorder.requestPermission()
                if granted {
                    try? recorder.startRecording()
                    isRecordingMode = true
                }
            }
        } label: {
            Image(systemName: "mic")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(NeuPalette.accentOrange)
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("chat_button_mic")
    }

    private var recordingControls: some View {
        HStack(spacing: 12) {
            // Cancel
            Button {
                recorder.cancelRecording()
                isRecordingMode = false
                onCancel()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
            }
            .accessibilityIdentifier("voice_button_cancel")

            // Waveform
            WaveformView(samples: recorder.waveformSamples)
                .frame(height: 32)
                .frame(maxWidth: .infinity)

            // Duration
            Text(formatDuration(recorder.duration))
                .font(.caption.monospacedDigit())
                .foregroundStyle(NeuPalette.textSecondary)

            // Pause/Resume
            Button {
                if recorder.isPaused {
                    recorder.resumeRecording()
                } else {
                    recorder.pauseRecording()
                }
            } label: {
                Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                    .foregroundStyle(NeuPalette.textPrimary)
            }
            .accessibilityIdentifier("voice_button_pause")

            // Send
            Button {
                if let result = recorder.stopRecording() {
                    isRecordingMode = false
                    onRecorded(result)
                }
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(NeuPalette.accentCyan)
            }
            .accessibilityIdentifier("voice_button_send")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(NeuPalette.surface, in: RoundedRectangle(cornerRadius: 20))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - WaveformView

/// Animated waveform visualization for voice recording.
struct WaveformView: View {
    let samples: [Float]

    var body: some View {
        GeometryReader { geometry in
            let barCount = max(1, Int(geometry.size.width / 4))
            let step = max(1, samples.count / barCount)
            let bars = stride(from: 0, to: samples.count, by: step).map { i in
                min(1.0, max(0.05, samples[i]))
            }

            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, height in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(NeuPalette.accentCyan)
                        .frame(width: 2, height: CGFloat(height) * geometry.size.height)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - VoicePlaybackView

/// Waveform playback view for voice messages in chat bubbles.
struct VoicePlaybackView: View {
    let attachment: ChatAttachment
    @Environment(AudioPlaybackService.self) private var playback
    @State private var errorMessage: String?

    private var attachmentUUID: UUID? {
        UUID(uuidString: attachment.id)
    }

    private var isActive: Bool {
        attachmentUUID != nil && playback.activeAttachmentID == attachmentUUID
    }

    private var isPlaying: Bool {
        isActive && playback.isPlaying
    }

    private var progress: Double {
        isActive ? playback.progress : 0
    }

    private var remainingTime: TimeInterval {
        guard isActive, playback.duration > 0 else { return 0 }
        return max(0, playback.duration - progress * playback.duration)
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                Task { await togglePlayback() }
            } label: {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(NeuPalette.accentCyan)
            }
            .accessibilityIdentifier("voice_playback_toggle")

            VStack(alignment: .leading, spacing: 4) {
                // Waveform
                if case let .voiceRecording(payload) = attachment.payload {
                    playbackWaveform(samples: payload.waveformSamples, progress: progress)
                        .frame(height: 24)

                    HStack {
                        Text(formatDuration(payload.duration ?? 0))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(NeuPalette.textSecondary)
                        Spacer()
                        Text(formatDuration(remainingTime))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(NeuPalette.textSecondary)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(12)
        .background(NeuPalette.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func togglePlayback() async {
        errorMessage = nil
        guard let attachmentUUID else {
            errorMessage = "Invalid attachment id"
            return
        }
        do {
            if let localURL = attachment.payload.localURL {
                try playback.togglePlayback(attachmentID: attachmentUUID, url: localURL)
            } else if let remoteURL = attachment.remoteURL {
                let (tempURL, _) = try await URLSession.shared.download(from: remoteURL)

                let cachedURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("voice-\(attachmentUUID.uuidString)-\(tempURL.lastPathComponent)")
                if FileManager.default.fileExists(atPath: cachedURL.path) {
                    try? FileManager.default.removeItem(at: cachedURL)
                }
                try FileManager.default.moveItem(at: tempURL, to: cachedURL)

                try playback.togglePlayback(attachmentID: attachmentUUID, url: cachedURL)
            } else {
                errorMessage = "No audio available"
            }
        } catch {
            if case let AudioPlaybackService.PlaybackError.cannotPlay(message) = error {
                errorMessage = message
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func playbackWaveform(samples: [Float], progress: Double) -> some View {
        GeometryReader { geometry in
            let barCount = max(1, Int(geometry.size.width / 4))
            let step = max(1, samples.count / barCount)
            let bars = stride(from: 0, to: samples.count, by: step).map { i in
                min(1.0, max(0.05, samples[i]))
            }
            let playedIndex = Int(progress * Double(bars.count))

            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(bars.enumerated()), id: \.offset) { index, height in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index < playedIndex ? NeuPalette.accentCyan : NeuPalette.textSecondary.opacity(0.4))
                        .frame(width: 2, height: CGFloat(height) * geometry.size.height)
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
