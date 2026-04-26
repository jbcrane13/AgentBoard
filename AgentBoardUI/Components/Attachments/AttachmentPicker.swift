import AgentBoardCore
import SwiftUI
#if os(iOS)
    import PhotosUI
    import UIKit
    import UniformTypeIdentifiers
#endif

// MARK: - AttachmentPickerSheet

/// Platform-specific attachment picker — real pickers on iOS, NSOpenPanel on macOS.
struct AttachmentPickerSheet: View {
    let onPick: (ChatAttachment) -> Void
    @Environment(\.dismiss) private var dismiss

    #if os(iOS)
        @State private var showPhotosPicker = false
        @State private var showDocumentPicker = false
        @State private var showCameraPicker = false
    #endif

    var body: some View {
        #if os(iOS)
            NavigationStack {
                List {
                    Section {
                        Button {
                            showPhotosPicker = true
                        } label: {
                            Label("Photo Library", systemImage: "photo.on.rectangle")
                        }
                        .accessibilityIdentifier("attachment_picker_photos")

                        Button {
                            showDocumentPicker = true
                        } label: {
                            Label("Files", systemImage: "folder")
                        }
                        .accessibilityIdentifier("attachment_picker_files")

                        Button {
                            showCameraPicker = true
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
            .sheet(isPresented: $showPhotosPicker) {
                MultiPhotoPicker { images in
                    for image in images {
                        let url = Self.saveTempImage(image)
                        let attachment = ChatAttachment(
                            type: .image,
                            payload: .image(ImageAttachmentPayload(localURL: url))
                        )
                        onPick(attachment)
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                IOSDocumentPicker { urls in
                    for url in urls {
                        let attachment = ChatAttachment(
                            type: .file,
                            payload: .file(FileAttachmentPayload(
                                localURL: url,
                                fileName: url.lastPathComponent,
                                fileSize: Self.fileSize(url)
                            ))
                        )
                        onPick(attachment)
                    }
                }
            }
            .sheet(isPresented: $showCameraPicker) {
                IOSCameraPicker { image in
                    let url = Self.saveTempImage(image)
                    let attachment = ChatAttachment(
                        type: .image,
                        payload: .image(ImageAttachmentPayload(localURL: url))
                    )
                    onPick(attachment)
                }
            }
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
        private static func saveTempImage(_ image: UIImage) -> URL {
            let dir = FileManager.default.temporaryDirectory
            let url = dir.appendingPathComponent("ab-\(UUID().uuidString).jpg")
            if let data = image.jpegData(compressionQuality: 0.85) {
                try? data.write(to: url)
            }
            return url
        }
    #endif

    private static func fileSize(_ url: URL) -> Int64? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? NSNumber else { return nil }
        return size.int64Value
    }

    #if os(macOS)
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
                            fileSize: Self.fileSize(url)
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
    #endif
}

// MARK: - iOS Multi-Photo Picker

#if os(iOS)
    private struct MultiPhotoPicker: UIViewControllerRepresentable {
        let onPick: ([UIImage]) -> Void
        @Environment(\.dismiss) private var dismiss

        func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
        }

        func makeUIViewController(context: Context) -> PHPickerViewController {
            var config = PHPickerConfiguration()
            config.selectionLimit = 0
            config.filter = .images
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(_: PHPickerViewController, context _: Context) {}

        final class Coordinator: NSObject, PHPickerViewControllerDelegate {
            let parent: MultiPhotoPicker

            init(parent: MultiPhotoPicker) {
                self.parent = parent
            }

            func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                parent.dismiss()
                guard !results.isEmpty else { return }

                var images: [UIImage] = []
                let group = DispatchGroup()

                for result in results where result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                        if let uiImage = image as? UIImage {
                            DispatchQueue.main.async {
                                images.append(uiImage)
                            }
                        }
                        group.leave()
                    }
                }

                group.notify(queue: .main) {
                    self.parent.onPick(images)
                }
            }
        }
    }

    // MARK: - iOS Document Picker

    private struct IOSDocumentPicker: UIViewControllerRepresentable {
        let onPick: ([URL]) -> Void
        @Environment(\.dismiss) private var dismiss

        func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
        }

        func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: [.data, .image, .audio, .movie],
                asCopy: true
            )
            picker.allowsMultipleSelection = true
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(_: UIDocumentPickerViewController, context _: Context) {}

        final class Coordinator: NSObject, UIDocumentPickerDelegate {
            let parent: IOSDocumentPicker

            init(parent: IOSDocumentPicker) {
                self.parent = parent
            }

            func documentPicker(_: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
                parent.dismiss()
                parent.onPick(urls)
            }

            func documentPickerWasCancelled(_: UIDocumentPickerViewController) {
                parent.dismiss()
            }
        }
    }

    // MARK: - iOS Camera Picker

    private struct IOSCameraPicker: UIViewControllerRepresentable {
        let onPick: (UIImage) -> Void
        @Environment(\.dismiss) private var dismiss

        func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
        }

        func makeUIViewController(context: Context) -> UIImagePickerController {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(_: UIImagePickerController, context _: Context) {}

        final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
            let parent: IOSCameraPicker

            init(parent: IOSCameraPicker) {
                self.parent = parent
            }

            func imagePickerController(
                _: UIImagePickerController,
                didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
            ) {
                parent.dismiss()
                if let image = info[.originalImage] as? UIImage {
                    parent.onPick(image)
                }
            }

            func imagePickerControllerDidCancel(_: UIImagePickerController) {
                parent.dismiss()
            }
        }
    }
#endif

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
