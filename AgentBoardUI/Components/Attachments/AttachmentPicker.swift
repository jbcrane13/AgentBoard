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
        @State private var cameraAvailable = false
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
                            dismiss()
                            presentIOSFilePicker()
                        } label: {
                            Label("Files", systemImage: "folder")
                        }
                        .accessibilityIdentifier("attachment_picker_files")

                        Button {
                            if cameraAvailable {
                                dismiss()
                                presentIOSCamera()
                            }
                        } label: {
                            Label(
                                cameraAvailable ? "Camera" : "Camera (unavailable)",
                                systemImage: "camera"
                            )
                        }
                        .disabled(!cameraAvailable)
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
                MultiPhotoPicker { urls in
                    for url in urls {
                        let attachment = ChatAttachment(
                            type: .image,
                            payload: .image(ImageAttachmentPayload(localURL: url))
                        )
                        onPick(attachment)
                    }
                }
            }
            .onAppear {
                cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
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

    // MARK: - iOS File Picker (UIKit — avoids ViewBridge crash from nested SwiftUI modals)

    #if os(iOS)
        private func presentIOSFilePicker() {
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: [.data, .image, .audio, .movie],
                asCopy: true
            )
            picker.allowsMultipleSelection = true
            picker.delegate = IOSFilePickerDelegate.shared
            IOSFilePickerDelegate.shared.onPick = { urls in
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
            presentFromRoot(picker)
        }

        private func presentIOSCamera() {
            let picker = UIImagePickerController()
            picker.sourceType = .camera
            picker.cameraCaptureMode = .photo
            picker.delegate = IOSCameraDelegate.shared
            IOSCameraDelegate.shared.onPick = { image in
                let url = Self.saveTempImage(image)
                let attachment = ChatAttachment(
                    type: .image,
                    payload: .image(ImageAttachmentPayload(localURL: url))
                )
                onPick(attachment)
            }
            presentFromRoot(picker)
        }

        private func presentFromRoot(_ viewController: UIViewController) {
            guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let root = scene.windows.first?.rootViewController else { return }

            // Find the topmost presented VC to present from
            var topVC = root
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            topVC.present(viewController, animated: true)
        }
    #endif

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

// MARK: - iOS UIKit Delegate Singletons

#if os(iOS)
    /// Singleton delegate for UIImagePickerController (camera).
    /// Prevents delegate deallocation and avoids nested SwiftUI modal issues.
    private final class IOSCameraDelegate: NSObject, UIImagePickerControllerDelegate,
        UINavigationControllerDelegate {
        static let shared = IOSCameraDelegate()
        var onPick: ((UIImage) -> Void)?

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                onPick?(image)
            }
            onPick = nil
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
            onPick = nil
        }
    }

    /// Singleton delegate for UIDocumentPickerViewController (file import).
    private final class IOSFilePickerDelegate: NSObject, UIDocumentPickerDelegate {
        static let shared = IOSFilePickerDelegate()
        var onPick: (([URL]) -> Void)?

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            controller.dismiss(animated: true)
            onPick?(urls)
            onPick = nil
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            controller.dismiss(animated: true)
            onPick = nil
        }
    }
#endif

// MARK: - AttachmentPreviewStrip

/// Horizontal scroll of pending attachment thumbnails with remove buttons.
struct AttachmentPreviewStrip: View {
    @Binding var attachments: [ChatAttachment]

    var body: some View {
        if attachments.isEmpty {
            EmptyView()
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(attachments.enumerated()), id: \.offset) { index, attachment in
                        ZStack(alignment: .topTrailing) {
                            attachmentThumbnail(attachment)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            Button {
                                attachments.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.6)))
                            }
                            .offset(x: 4, y: -4)
                        }
                    }
                }
                .padding(.horizontal)
            }
            .frame(height: 70)
        }
    }

    @ViewBuilder
    private func attachmentThumbnail(_ attachment: ChatAttachment) -> some View {
        switch attachment.payload {
        case let .image(payload):
            #if os(iOS)
                if let data = try? Data(contentsOf: payload.localURL),
                   let uiImage = UIImage(data: data) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholderThumbnail(systemImage: "photo")
                }
            #else
                if let data = try? Data(contentsOf: payload.localURL),
                   let nsImage = NSImage(data: data) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    placeholderThumbnail(systemImage: "photo")
                }
            #endif
        case let .file(payload):
            VStack(spacing: 2) {
                Image(systemName: "doc.fill")
                    .font(.title3)
                Text(payload.fileName)
                    .font(.system(size: 8))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(width: 60, height: 60)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        default:
            placeholderThumbnail(systemImage: "paperclip")
        }
    }

    private func placeholderThumbnail(systemImage: String) -> some View {
        ZStack {
            Color.gray.opacity(0.2)
            Image(systemName: systemImage)
                .foregroundColor(.secondary)
        }
        .frame(width: 60, height: 60)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - MultiPhotoPicker (PhotosUI — unchanged)

#if os(iOS)
    struct MultiPhotoPicker: UIViewControllerRepresentable {
        let onPick: ([URL]) -> Void

        func makeUIViewController(context: Context) -> PHPickerViewController {
            var config = PHPickerConfiguration()
            config.selectionLimit = 0
            config.filter = .images
            let picker = PHPickerViewController(configuration: config)
            picker.delegate = context.coordinator
            return picker
        }

        func updateUIViewController(_: PHPickerViewController, context _: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator(parent: self)
        }

        final class Coordinator: NSObject, PHPickerViewControllerDelegate {
            let parent: MultiPhotoPicker

            init(parent: MultiPhotoPicker) {
                self.parent = parent
            }

            func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
                picker.dismiss(animated: true)
                var urls: [URL] = []
                let lock = NSLock()
                let group = DispatchGroup()
                for result in results where result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                    group.enter()
                    result.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                        if let uiImage = image as? UIImage {
                            let url = FileManager.default.temporaryDirectory
                                .appendingPathComponent("ab-\(UUID().uuidString).jpg")
                            if let data = uiImage.jpegData(compressionQuality: 0.85) {
                                try? data.write(to: url)
                                lock.lock()
                                urls.append(url)
                                lock.unlock()
                            }
                        }
                        group.leave()
                    }
                }
                group.notify(queue: .main) {
                    self.parent.onPick(urls)
                }
            }
        }
    }
#endif
