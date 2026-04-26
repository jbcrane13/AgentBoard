import AgentBoardCore
import SwiftUI
#if canImport(UIKit)
    import UIKit
#endif
#if canImport(AppKit)
    import AppKit
#endif

// MARK: - Attachment Context Menu Modifier

/// Adds long-press context menu to attachment views with Copy, Save, Share actions.
struct AttachmentContextMenu: ViewModifier {
    let attachment: ChatAttachment

    func body(content: Content) -> some View {
        content.contextMenu {
            if let localURL = attachment.payload.localURL {
                Button {
                    copyToClipboard(localURL)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }

                Button {
                    saveToFiles(localURL)
                } label: {
                    Label("Save to Files", systemImage: "square.and.arrow.down")
                }

                #if os(iOS)
                    Button {
                        shareFile(localURL)
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                #endif
            }

            if let remoteURL = attachment.remoteURL {
                Button {
                    copyURLToClipboard(remoteURL)
                } label: {
                    Label("Copy Link", systemImage: "link")
                }
            }
        }
    }

    private func copyToClipboard(_ url: URL) {
        #if canImport(UIKit)
            if attachment.type == .image,
               let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                UIPasteboard.general.image = image
            } else {
                UIPasteboard.general.url = url
            }
        #else
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            if attachment.type == .image,
               let data = try? Data(contentsOf: url),
               let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            } else {
                pasteboard.writeObjects([url as NSURL])
            }
        #endif
    }

    private func copyURLToClipboard(_ url: URL) {
        #if canImport(UIKit)
            UIPasteboard.general.url = url
        #else
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([url.absoluteString as NSString])
        #endif
    }

    private func saveToFiles(_ url: URL) {
        #if os(iOS)
            let controller = UIDocumentPickerViewController(forExporting: [url])
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(controller, animated: true)
            }
        #else
            let panel = NSSavePanel()
            panel.nameFieldStringValue = url.lastPathComponent
            panel.begin { response in
                if response == .OK, let destination = panel.url {
                    try? FileManager.default.copyItem(at: url, to: destination)
                }
            }
        #endif
    }

    #if os(iOS)
        private func shareFile(_ url: URL) {
            let controller = UIActivityViewController(
                activityItems: [url],
                applicationActivities: nil
            )
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let root = scene.windows.first?.rootViewController {
                root.present(controller, animated: true)
            }
        }
    #endif
}

// MARK: - Paste from Clipboard

/// Modifier that detects clipboard paste and calls the handler with the pasted content.
struct ClipboardPasteModifier: ViewModifier {
    let onPaste: (ChatAttachment) -> Void

    func body(content: Content) -> some View {
        content
        #if os(macOS)
        .onPasteCommand(of: [.image, .fileURL]) { providers in
            for provider in providers {
                handleProvider(provider)
            }
        }
        #endif
    }

    #if os(macOS)
        private func handleProvider(_ provider: NSItemProvider) {
            if provider.hasItemConformingToTypeIdentifier("public.image") {
                provider.loadDataRepresentation(forTypeIdentifier: "public.image") { data, _ in
                    guard let data else { return }
                    let url = saveToTemp(data: data, ext: "png")
                    let attachment = ChatAttachment(
                        type: .image,
                        payload: .image(ImageAttachmentPayload(localURL: url))
                    )
                    Task { @MainActor in onPaste(attachment) }
                }
            } else if provider.hasItemConformingToTypeIdentifier("public.file-url") {
                provider.loadItem(forTypeIdentifier: "public.file-url") { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    let attachment = ChatAttachment(
                        type: .file,
                        payload: .file(FileAttachmentPayload(
                            localURL: url,
                            fileName: url.lastPathComponent
                        ))
                    )
                    Task { @MainActor in onPaste(attachment) }
                }
            }
        }

        private func saveToTemp(data: Data, ext: String) -> URL {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("paste-\(UUID().uuidString).\(ext)")
            try? data.write(to: url)
            return url
        }
    #endif
}

// MARK: - View Extensions

extension View {
    /// Add context menu to an attachment view.
    func attachmentContextMenu(for attachment: ChatAttachment) -> some View {
        modifier(AttachmentContextMenu(attachment: attachment))
    }

    /// Enable clipboard paste for attachments.
    func onAttachmentPaste(handler: @escaping (ChatAttachment) -> Void) -> some View {
        modifier(ClipboardPasteModifier(onPaste: handler))
    }
}

// MARK: - macOS Drop Support

#if os(macOS)
    /// Drop target for macOS that accepts file drops onto the composer.
    struct AttachmentDropTarget: ViewModifier {
        let onDrop: (ChatAttachment) -> Void

        func body(content: Content) -> some View {
            content.onDrop(of: [.fileURL], isTargeted: nil) { providers in
                for provider in providers {
                    _ = provider.loadObject(ofClass: URL.self) { url, _ in
                        guard let url else { return }
                        let attachment = attachmentForURL(url)
                        Task { @MainActor in onDrop(attachment) }
                    }
                }
                return true
            }
        }

        private func attachmentForURL(_ url: URL) -> ChatAttachment {
            let ext = url.pathExtension.lowercased()
            let imageExts = ["jpg", "jpeg", "png", "gif", "heic", "webp"]
            let videoExts = ["mp4", "mov", "m4v"]
            let audioExts = ["m4a", "mp3", "wav", "aac"]

            let type: AttachmentType
            if imageExts.contains(ext) {
                type = .image
            } else if videoExts.contains(ext) {
                type = .video
            } else if audioExts.contains(ext) {
                type = .audio
            } else {
                type = .file
            }

            let payload: AnyAttachmentPayload
            switch type {
            case .image:
                payload = .image(ImageAttachmentPayload(localURL: url))
            case .video:
                payload = .video(VideoAttachmentPayload(localURL: url))
            case .audio:
                payload = .audio(AudioAttachmentPayload(localURL: url))
            default:
                payload = .file(FileAttachmentPayload(
                    localURL: url,
                    fileName: url.lastPathComponent
                ))
            }

            return ChatAttachment(type: type, payload: payload)
        }
    }

    extension View {
        func attachmentDropTarget(handler: @escaping (ChatAttachment) -> Void) -> some View {
            modifier(AttachmentDropTarget(onDrop: handler))
        }
    }
#endif
