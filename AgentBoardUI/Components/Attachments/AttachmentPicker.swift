import AgentBoardCore
import SwiftUI
#if os(iOS)
    import PhotosUI
#endif

// MARK: - AttachmentPickerSheet

/// Platform-specific attachment picker — Photos/Files/Camera on iOS, NSOpenPanel on macOS.
struct AttachmentPickerSheet: View {
    let onPick: (ChatAttachment) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        #if os(iOS)
            NavigationStack {
                List {
                    Section {
                        Button {
                            dismiss()
                            presentPhotosPicker()
                        } label: {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                        }
                        .accessibilityIdentifier("attachment_picker_photos")

                        Button {
                            dismiss()
                            presentDocumentPicker()
                        } label: {
                            Label("Files", systemImage: "folder")
                        }
                        .accessibilityIdentifier("attachment_picker_files")

                        Button {
                            dismiss()
                            presentCameraPicker()
                        } label: {
                            Label("Camera", systemImage: "camera")
                        }
                        .accessibilityIdentifier("attachment_picker_camera")
                    }
                }
                .navigationTitle("Attach")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
            .presentationDetents([.medium])
        #else
            NavigationStack {
                VStack(alignment: .leading, spacing: 16) {
                    Button {
                        dismiss()
                        presentMacFilePicker()
                    } label: {
                        Label("Choose File...", systemImage: "doc")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("attachment_picker_file")

                    Button {
                        dismiss()
                        presentMacImagePicker()
                    } label: {
                        Label("Choose Image...", systemImage: "photo")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("attachment_picker_image")
                }
                .padding(24)
                .frame(minWidth: 280)
                .navigationTitle("Attach")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        #endif
    }

    #if os(iOS)
        private func presentPhotosPicker() {
            // PhotosUI picker is presented via PhotosPicker in the parent view
            // This triggers the parent to show it
            NotificationCenter.default.post(name: .init("AgentBoard.PresentPhotosPicker"), object: nil)
        }

        private func presentDocumentPicker() {
            NotificationCenter.default.post(name: .init("AgentBoard.PresentDocumentPicker"), object: nil)
        }

        private func presentCameraPicker() {
            NotificationCenter.default.post(name: .init("AgentBoard.PresentCameraPicker"), object: nil)
        }
    #else
        private func presentMacFilePicker() {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.data]

            if panel.runModal() == .OK {
                for url in panel.urls {
                    let attachment = ChatAttachment(
                        type: .file,
                        payload: .file(FileAttachmentPayload(
                            localURL: url,
                            fileName: url.lastPathComponent,
                            fileSize: fileSize(url)
                        ))
                    )
                    onPick(attachment)
                }
            }
        }

        private func presentMacImagePicker() {
            let panel = NSOpenPanel()
            panel.allowsMultipleSelection = true
            panel.canChooseDirectories = false
            panel.canChooseFiles = true
            panel.allowedContentTypes = [.image]

            if panel.runModal() == .OK {
                for url in panel.urls {
                    let attachment = ChatAttachment(
                        type: .image,
                        payload: .image(ImageAttachmentPayload(localURL: url))
                    )
                    onPick(attachment)
                }
            }
        }

        private func fileSize(_ url: URL) -> Int64? {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let size = attrs[.size] as? NSNumber else { return nil }
            return size.int64Value
        }
    #endif
}

// MARK: - AttachmentPreviewStrip

/// Horizontal scroll of pending attachment thumbnails with remove buttons.
struct AttachmentPreviewStrip: View {
    @Binding var attachments: [ChatAttachment]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentThumbnail(attachment: attachment) {
                        attachments.removeAll { $0.id == attachment.id }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - AttachmentThumbnail

private struct AttachmentThumbnail: View {
    let attachment: ChatAttachment
    let onRemove: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            thumbnailContent
                .frame(width: 60, height: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .background(Circle().fill(.black.opacity(0.5)))
            }
            .offset(x: 4, y: -4)
            .accessibilityIdentifier("attachment_preview_remove_\(attachment.id)")
        }
    }

    @ViewBuilder
    private var thumbnailContent: some View {
        switch attachment.type {
        case .image:
            if let localURL = localURL,
               let data = try? Data(contentsOf: localURL),
               let image = platformImage(from: data) {
                Image(platformImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderIcon("photo")
            }
        case .video:
            placeholderIcon("video.fill")
        case .file:
            placeholderIcon("doc.fill")
        case .audio:
            placeholderIcon("waveform")
        case .voiceRecording:
            placeholderIcon("mic.fill")
        case .linkPreview:
            placeholderIcon("link")
        }
    }

    private var localURL: URL? {
        attachment.payload.localURL
    }

    private func placeholderIcon(_ icon: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(NeuPalette.surface)
            Image(systemName: icon)
                .foregroundStyle(NeuPalette.accentCyan)
        }
    }

    private func platformImage(from data: Data) -> PlatformImage? {
        #if canImport(UIKit)
            return UIImage(data: data)
        #else
            return NSImage(data: data)
        #endif
    }
}
