import AVFoundation
import Observation

// MARK: - AudioPlaybackService

/// Plays voice-note attachments, tracking a single active player at a time.
@MainActor
@Observable
public final class AudioPlaybackService {
    public enum PlaybackError: Error, Equatable {
        case cannotPlay(String)
    }

    public private(set) var activeAttachmentID: UUID?
    public private(set) var isPlaying = false
    public private(set) var progress: Double = 0 // 0...1
    public private(set) var duration: TimeInterval = 0

    @ObservationIgnored private var player: AVAudioPlayer?
    @ObservationIgnored private var progressTask: Task<Void, Never>?
    /// AVAudioPlayer.delegate is weak, so the helper must be retained here or the
    /// finish callback never fires.
    @ObservationIgnored private var delegate: PlayerDelegate?

    public init() {}

    /// Starts playing `url` for `attachmentID`, pausing/resuming if it's already the active
    /// attachment, or stopping the current player and starting a new one otherwise.
    public func togglePlayback(attachmentID: UUID, url: URL) throws {
        if activeAttachmentID == attachmentID, let player {
            if player.isPlaying {
                player.pause()
                isPlaying = false
                stopProgressTicker()
            } else {
                player.play()
                isPlaying = true
                startProgressTicker()
            }
            return
        }

        stop()

        let newPlayer: AVAudioPlayer
        do {
            newPlayer = try AVAudioPlayer(contentsOf: url)
        } catch {
            throw PlaybackError.cannotPlay(error.localizedDescription)
        }

        let helperDelegate = PlayerDelegate { [weak self] in
            Task { @MainActor in
                self?.handlePlaybackFinished()
            }
        }
        newPlayer.delegate = helperDelegate
        newPlayer.prepareToPlay()
        newPlayer.play()

        player = newPlayer
        delegate = helperDelegate
        activeAttachmentID = attachmentID
        duration = newPlayer.duration
        progress = 0
        isPlaying = true
        startProgressTicker()
    }

    public func stop() {
        player?.stop()
        stopProgressTicker()
        player = nil
        delegate = nil
        activeAttachmentID = nil
        isPlaying = false
        progress = 0
        duration = 0
    }

    private func handlePlaybackFinished() {
        stopProgressTicker()
        player = nil
        delegate = nil
        activeAttachmentID = nil
        isPlaying = false
        progress = 0
    }

    private func startProgressTicker() {
        progressTask?.cancel()
        progressTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard !Task.isCancelled else { return }
                guard let self, let player = self.player, player.duration > 0 else { continue }
                self.progress = player.currentTime / player.duration
            }
        }
    }

    private func stopProgressTicker() {
        progressTask?.cancel()
        progressTask = nil
    }
}

// MARK: - PlayerDelegate

/// Bridges `AVAudioPlayerDelegate` (which requires `NSObjectProtocol`) to the
/// `@MainActor`-isolated `AudioPlaybackService` without making the service itself an `NSObject`.
private final class PlayerDelegate: NSObject, AVAudioPlayerDelegate {
    private let onFinish: @Sendable () -> Void

    init(onFinish: @escaping @Sendable () -> Void) {
        self.onFinish = onFinish
    }

    func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully _: Bool) {
        onFinish()
    }
}
