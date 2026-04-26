import AgentBoardCore
import Nuke
import NukeUI
import SwiftUI

// MARK: - AttachmentContainerView

/// Routes an attachment to the correct display view based on its type.
struct AttachmentContainerView: View {
    let attachment: ChatAttachment
    var onTap: (() -> Void)?

    var body: some View {
        switch attachment.type {
        case .image:
            ImageAttachmentView(attachment: attachment, onTap: onTap)
        case .video:
            VideoAttachmentView(attachment: attachment, onTap: onTap)
        case .file:
            FileAttachmentView(attachment: attachment)
        case .audio:
            AudioAttachmentView(attachment: attachment)
        case .voiceRecording:
            VoiceAttachmentView(attachment: attachment)
        case .linkPreview:
            if case let .linkPreview(payload) = attachment.payload {
                LinkPreviewCard(payload: payload)
            }
        }
    }
}

// MARK: - ImageAttachmentView

struct ImageAttachmentView: View {
    let attachment: ChatAttachment
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let remoteURL = remoteURL {
                LazyImage(url: remoteURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if state.error != nil {
                        placeholder(icon: "photo.badge.exclamationmark", label: "Failed to load")
                    } else {
                        placeholder(icon: "photo", label: "Loading...")
                            .overlay(ProgressView())
                    }
                }
                .processors([ImageProcessors.Resize(width: 300)])
            } else if let localURL = localURL {
                if let data = try? Data(contentsOf: localURL),
                   let uiImage = PlatformImage(data: data) {
                    Image(platformImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholder(icon: "photo", label: "Local image")
                }
            } else {
                placeholder(icon: "photo", label: "No image")
            }
        }
        .frame(maxWidth: 280, maxHeight: 200)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { onTap?() }
    }

    private var remoteURL: URL? {
        if case let .image(payload) = attachment.payload {
            return payload.remoteURL
        }
        return nil
    }

    private var localURL: URL? {
        if case let .image(payload) = attachment.payload {
            return payload.localURL
        }
        return nil
    }

    private func placeholder(icon: String, label: String) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(NeuPalette.surface)
            .frame(width: 200, height: 140)
            .overlay {
                VStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(NeuPalette.textSecondary)
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(NeuPalette.textSecondary)
                }
            }
    }
}

// MARK: - VideoAttachmentView

struct VideoAttachmentView: View {
    let attachment: ChatAttachment
    var onTap: (() -> Void)?

    var body: some View {
        ZStack {
            if let thumbnailURL = thumbnailURL {
                LazyImage(url: thumbnailURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(NeuPalette.surface)
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(NeuPalette.surface)
            }

            // Play button overlay
            Circle()
                .fill(.black.opacity(0.5))
                .frame(width: 48, height: 48)
                .overlay {
                    Image(systemName: "play.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                }

            // Duration badge
            if let duration = duration {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(formatDuration(duration))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
                .padding(8)
            }
        }
        .frame(maxWidth: 280, maxHeight: 180)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { onTap?() }
    }

    private var thumbnailURL: URL? {
        if case let .video(payload) = attachment.payload { return payload.thumbnailURL }
        return nil
    }

    private var duration: TimeInterval? {
        if case let .video(payload) = attachment.payload { return payload.duration }
        return nil
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - FileAttachmentView

struct FileAttachmentView: View {
    let attachment: ChatAttachment

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fileIcon)
                .font(.title2)
                .foregroundStyle(NeuPalette.accentCyan)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NeuPalette.textPrimary)
                    .lineLimit(1)

                if let fileSize = fileSize {
                    Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                        .font(.caption)
                        .foregroundStyle(NeuPalette.textSecondary)
                }
            }

            Spacer()

            if attachment.state == .pendingUpload || attachment.state.isUploading {
                if case let .uploading(progress) = attachment.state {
                    ProgressView(value: progress)
                        .frame(width: 40)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: 280)
        .background(NeuPalette.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private var fileName: String {
        if case let .file(payload) = attachment.payload { return payload.fileName }
        return "File"
    }

    private var fileSize: Int64? {
        if case let .file(payload) = attachment.payload { return payload.fileSize }
        return nil
    }

    private var fileIcon: String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.richtext"
        case "doc", "docx": return "doc.text"
        case "xls", "xlsx": return "tablecells"
        case "ppt", "pptx": return "rectangle.on.rectangle"
        case "zip", "tar", "gz": return "archivebox"
        case "txt", "md": return "doc.plaintext"
        default: return "doc"
        }
    }
}

// MARK: - AudioAttachmentView

struct AudioAttachmentView: View {
    let attachment: ChatAttachment

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .font(.title2)
                .foregroundStyle(NeuPalette.accentCyan)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text("Audio")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NeuPalette.textPrimary)

                if case let .audio(payload) = attachment.payload, let duration = payload.duration {
                    Text(formatDuration(duration))
                        .font(.caption)
                        .foregroundStyle(NeuPalette.textSecondary)
                }
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title)
                .foregroundStyle(NeuPalette.accentCyan)
        }
        .padding(12)
        .frame(maxWidth: 280)
        .background(NeuPalette.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - VoiceAttachmentView

struct VoiceAttachmentView: View {
    let attachment: ChatAttachment

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.title3)
                .foregroundStyle(NeuPalette.accentOrange)
                .frame(width: 36, height: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text("Voice Message")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(NeuPalette.textPrimary)

                if case let .voiceRecording(payload) = attachment.payload {
                    // Simple waveform visualization
                    HStack(spacing: 2) {
                        ForEach(waveformBars(payload.waveformSamples), id: \.self) { height in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(NeuPalette.accentCyan.opacity(0.6))
                                .frame(width: 3, height: CGFloat(height) * 20)
                        }
                    }
                    .frame(height: 20)

                    if let duration = payload.duration {
                        Text(formatDuration(duration))
                            .font(.caption2)
                            .foregroundStyle(NeuPalette.textSecondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.title)
                .foregroundStyle(NeuPalette.accentCyan)
        }
        .padding(12)
        .frame(maxWidth: 280)
        .background(NeuPalette.surface, in: RoundedRectangle(cornerRadius: 12))
    }

    private func waveformBars(_ samples: [Float]) -> [Float] {
        guard !samples.isEmpty else { return Array(repeating: 0.3, count: 20) }
        let step = max(1, samples.count / 20)
        return stride(from: 0, to: samples.count, by: step).map { i in
            min(1.0, max(0.1, samples[i]))
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - LinkPreviewCard

struct LinkPreviewCard: View {
    let payload: LinkPreviewPayload

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let imageURL = payload.imageURL {
                LazyImage(url: imageURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 120)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                if let title = payload.title {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(NeuPalette.textPrimary)
                        .lineLimit(2)
                }

                if let description = payload.description {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(NeuPalette.textSecondary)
                        .lineLimit(3)
                }

                HStack(spacing: 4) {
                    Image(systemName: "link")
                        .font(.caption2)
                    Text(payload.siteName ?? payload.url.host() ?? payload.url.absoluteString)
                        .font(.caption2)
                }
                .foregroundStyle(NeuPalette.textSecondary)
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .frame(maxWidth: 280)
        .background(NeuPalette.surface, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Platform Image Helper

#if canImport(UIKit)
    import UIKit

    typealias PlatformImage = UIImage
#else
    import AppKit

    typealias PlatformImage = NSImage
#endif

extension Image {
    init(platformImage: PlatformImage) {
        #if canImport(UIKit)
            self.init(uiImage: platformImage)
        #else
            self.init(nsImage: platformImage)
        #endif
    }
}

// MARK: - LocalAttachmentState helper

extension LocalAttachmentState {
    var isUploading: Bool {
        if case .uploading = self { return true }
        return false
    }
}
