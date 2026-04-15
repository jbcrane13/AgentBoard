import SwiftUI
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// MARK: - AttachmentPicker

/// A comprehensive attachment picker view supporting file selection,
/// photo picking, screenshot capture, and drag-and-drop.
///
/// Usage:
/// ```swift
/// @State private var attachments: [Attachment] = []
///
/// AttachmentPicker(attachments: $attachments)
/// ```
public struct AttachmentPicker: View {
    @Binding public var attachments: [Attachment]
    @State private var isFilePickerPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var isScreenshotCapturing = false
    @State private var isDropTargetActive = false
    @State private var errorMessage: String?
    @State private var showError = false

    /// Maximum number of attachments allowed
    public var maxAttachments: Int

    /// Maximum file size in bytes (default: 25MB)
    public var maxFileSize: Int64

    /// Whether to allow screenshot capture (macOS only)
    public var allowScreenshots: Bool

    /// Initialize the attachment picker
    /// - Parameters:
    ///   - attachments: Binding to the attachments array
    ///   - maxAttachments: Maximum number of attachments (default: 10)
    ///   - maxFileSize: Maximum file size in bytes (default: 25MB)
    ///   - allowScreenshots: Enable screenshot capture (default: true)
    public init(
        attachments: Binding<[Attachment]>,
        maxAttachments: Int = 10,
        maxFileSize: Int64 = 25 * 1024 * 1024,
        allowScreenshots: Bool = true
    ) {
        self._attachments = attachments
        self.maxAttachments = maxAttachments
        self.maxFileSize = maxFileSize
        self.allowScreenshots = allowScreenshots
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Toolbar with action buttons
            attachmentToolbar

            // Attached files list
            if !attachments.isEmpty {
                attachmentList
            }

            // Drop zone (shown when no attachments or always visible for drag-drop)
            dropZone
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { showError = false }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
    }

    // MARK: - Toolbar

    private var attachmentToolbar: some View {
        HStack(spacing: 12) {
            // File picker button
            Button {
                isFilePickerPresented = true
            } label: {
                Label("File", systemImage: "doc.badge.plus")
            }
            .buttonStyle(.bordered)
            .disabled(attachments.count >= maxAttachments)
            #if canImport(AppKit)
            .fileImporter(
                isPresented: $isFilePickerPresented,
                allowedContentTypes: UTType.supportedAttachmentTypes,
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            #endif

            // Photo picker button
            #if canImport(UIKit)
            Button {
                isPhotoPickerPresented = true
            } label: {
                Label("Photo", systemImage: "photo.on.rectangle.angled")
            }
            .buttonStyle(.bordered)
            .disabled(attachments.count >= maxAttachments)
            .sheet(isPresented: $isPhotoPickerPresented) {
                PhotoPickerView { images in
                    handlePhotoSelection(images)
                }
            }
            #elseif canImport(AppKit)
            Button {
                isPhotoPickerPresented = true
            } label: {
                Label("Photo", systemImage: "photo.on.rectangle.angled")
            }
            .buttonStyle(.bordered)
            .disabled(attachments.count >= maxAttachments)
            .fileImporter(
                isPresented: $isPhotoPickerPresented,
                allowedContentTypes: [.image],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            #endif

            // Screenshot button
            if allowScreenshots {
                Button {
                    captureScreenshot()
                } label: {
                    Label("Screenshot", systemImage: "camera.viewfinder")
                }
                .buttonStyle(.bordered)
                .disabled(attachments.count >= maxAttachments)
            }

            Spacer()

            // Attachment count
            if !attachments.isEmpty {
                Text("\(attachments.count)/\(maxAttachments)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Attachment List

    private var attachmentList: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(attachments) { attachment in
                    AttachmentThumbnail(
                        attachment: attachment,
                        onRemove: {
                            removeAttachment(attachment)
                        }
                    )
                }
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: - Drop Zone

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    isDropTargetActive ? Color.accentColor : Color.secondary.opacity(0.3),
                    style: StrokeStyle(lineWidth: 2, dash: [8])
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDropTargetActive ? Color.accentColor.opacity(0.1) : Color.clear)
                )

            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc.fill")
                    .font(.title2)
                    .foregroundColor(isDropTargetActive ? .accentColor : .secondary)

                Text("Drag and drop files here")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("or use the buttons above")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.7))
            }
        }
        .frame(height: 100)
        .onDrop(of: UTType.supportedAttachmentTypes, isTargeted: $isDropTargetActive) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Actions

    #if canImport(AppKit)
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                guard attachments.count < maxAttachments else { break }

                // Start accessing the security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    showErrorMessage("Unable to access file: \(url.lastPathComponent)")
                    continue
                }
                defer { url.stopAccessingSecurityScopedResource() }

                guard let attachment = Attachment.from(url: url) else {
                    showErrorMessage("Failed to read file: \(url.lastPathComponent)")
                    continue
                }

                if attachment.fileSize > maxFileSize {
                    showErrorMessage("File too large: \(attachment.fileName) (\(attachment.formattedFileSize))")
                    continue
                }

                attachments.append(attachment)
            }
        case .failure(let error):
            showErrorMessage("File selection failed: \(error.localizedDescription)")
        }
    }
    #endif

    #if canImport(UIKit)
    private func handlePhotoSelection(_ images: [UIImage]) {
        for image in images {
            guard attachments.count < maxAttachments else { break }

            guard let data = image.jpegData(compressionQuality: 0.8) else {
                continue
            }

            if Int64(data.count) > maxFileSize {
                showErrorMessage("Image too large")
                continue
            }

            let attachment = Attachment.fromImageData(
                data,
                fileName: "Photo_\(UUID().uuidString.prefix(8)).jpg",
                mimeType: "image/jpeg"
            )
            attachments.append(attachment)
        }
    }
    #endif

    private func captureScreenshot() {
        #if canImport(AppKit)
        isScreenshotCapturing = true

        // Use macOS screencapture tool
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        let tempPath = FileManager.default.temporaryDirectory
            .appendingPathComponent("Screenshot_\(UUID().uuidString).png")
            .path
        task.arguments = ["-i", tempPath]

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                let url = URL(fileURLWithPath: tempPath)
                if let attachment = Attachment.from(url: url) {
                    appendAttachmentIfAllowed(attachment)
                }
            }
        } catch {
            showErrorMessage("Screenshot capture failed: \(error.localizedDescription)")
        }

        isScreenshotCapturing = false
        #elseif canImport(UIKit)
        // On iOS, screenshot capture requires ScreenCaptureKit (iOS 17+) or UIWindow capture
        // For now, show a message that screenshot is not available on iOS
        showErrorMessage("Screenshot capture is available on macOS")
        #endif
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            guard attachments.count < maxAttachments else { break }

            // Try to load as file URL first
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { item, error in
                    if let data = item as? Data,
                       let url = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async {
                            guard let attachment = Attachment.from(url: url) else { return }
                            appendAttachmentIfAllowed(attachment)
                        }
                    }
                }
            }
            // Try to load as image
            else if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.image.identifier) { item, error in
                    #if canImport(AppKit)
                    if let url = item as? URL {
                        DispatchQueue.main.async {
                            guard let attachment = Attachment.from(url: url) else { return }
                            appendAttachmentIfAllowed(attachment)
                        }
                    } else if let data = item as? Data {
                        DispatchQueue.main.async {
                            let attachment = Attachment.fromImageData(data)
                            appendAttachmentIfAllowed(attachment)
                        }
                    }
                    #elseif canImport(UIKit)
                    if let image = item as? UIImage,
                       let data = image.pngData() {
                        DispatchQueue.main.async {
                            let attachment = Attachment.fromImageData(data)
                            appendAttachmentIfAllowed(attachment)
                        }
                    }
                    #endif
                }
            }
        }
        return true
    }

    /// Centralized attachment validation to enforce max count and size limits before append.
    private func appendAttachmentIfAllowed(_ attachment: Attachment) {
        guard attachments.count < maxAttachments else {
            showErrorMessage("Maximum \(maxAttachments) attachments allowed")
            return
        }

        guard attachment.fileSize <= maxFileSize else {
            showErrorMessage("File too large: \(attachment.fileName)")
            return
        }

        attachments.append(attachment)
    }

    private func removeAttachment(_ attachment: Attachment) {
        attachments.removeAll { $0.id == attachment.id }
    }

    private func showErrorMessage(_ message: String) {
        DispatchQueue.main.async {
            errorMessage = message
            showError = true
        }
    }
}

// MARK: - AttachmentThumbnail

/// A compact thumbnail view for a single attachment
public struct AttachmentThumbnail: View {
    public let attachment: Attachment
    public let onRemove: () -> Void

    @State private var thumbnailImage: PlatformImage?

    #if canImport(UIKit)
    public typealias PlatformImage = UIImage
    #elseif canImport(AppKit)
    public typealias PlatformImage = NSImage
    #endif

    public init(attachment: Attachment, onRemove: @escaping () -> Void) {
        self.attachment = attachment
        self.onRemove = onRemove
    }

    public var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail or icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))

                    if let image = thumbnailImage {
                        #if canImport(UIKit)
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        #elseif canImport(AppKit)
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        #endif
                    } else {
                        Image(systemName: attachment.iconName)
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 72, height: 72)

                // Remove button
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.black.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }

            // File name (truncated)
            Text(attachment.fileName)
                .font(.caption2)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: 72)

            // File size
            Text(attachment.formattedFileSize)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        guard attachment.attachmentType == .image,
              let url = attachment.localURL else { return }

        DispatchQueue.global(qos: .background).async {
            #if canImport(UIKit)
            if let image = UIImage(contentsOfFile: url.path) {
                DispatchQueue.main.async {
                    self.thumbnailImage = image
                }
            }
            #elseif canImport(AppKit)
            if let image = NSImage(contentsOfFile: url.path) {
                DispatchQueue.main.async {
                    self.thumbnailImage = image
                }
            }
            #endif
        }
    }
}

// MARK: - PhotoPickerView (UIKit)

#if canImport(UIKit)
import PhotosUI

/// UIKit-based photo picker using PHPickerViewController
struct PhotoPickerView: UIViewControllerRepresentable {
    let onSelection: ([UIImage]) -> Void

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 0 // 0 = no limit

        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelection: onSelection)
    }

    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onSelection: ([UIImage]) -> Void

        init(onSelection: @escaping ([UIImage]) -> Void) {
            self.onSelection = onSelection
        }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)

            var images: [UIImage] = []
            let group = DispatchGroup()

            for result in results {
                group.enter()
                result.itemProvider.loadObject(ofClass: UIImage.self) { object, error in
                    if let image = object as? UIImage {
                        images.append(image)
                    }
                    group.leave()
                }
            }

            group.notify(queue: .main) {
                self.onSelection(images)
            }
        }
    }
}
#endif

// MARK: - Preview

#if canImport(UIKit)
struct AttachmentPicker_Previews: PreviewProvider {
    static var previews: some View {
        AttachmentPicker(attachments: .constant([]))
            .padding()
    }
}
#endif
