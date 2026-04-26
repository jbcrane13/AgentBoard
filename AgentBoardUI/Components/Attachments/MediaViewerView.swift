import AgentBoardCore
import NukeUI
import SwiftUI

// MARK: - MediaViewerView

/// Fullscreen media viewer with gallery navigation for images and videos.
struct MediaViewerView: View {
    let attachments: [ChatAttachment]
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss

    init(attachments: [ChatAttachment], startIndex: Int = 0) {
        self.attachments = attachments
        _currentIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $currentIndex) {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                    mediaPage(for: attachment)
                        .tag(index)
                }
            }
            #if os(iOS)
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            #endif

            // Top bar with dismiss and counter
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .accessibilityIdentifier("media_viewer_button_dismiss")

                    Spacer()

                    if attachments.count > 1 {
                        Text("\(currentIndex + 1) / \(attachments.count)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    // Placeholder for share button
                    Image(systemName: "square.and.arrow.up")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.0))
                }
                .padding()

                Spacer()
            }
        }
        #if os(iOS)
        .statusBarHidden(true)
        #endif
    }

    @ViewBuilder
    private func mediaPage(for attachment: ChatAttachment) -> some View {
        switch attachment.type {
        case .image:
            imagePage(for: attachment)
        case .video:
            videoPage(for: attachment)
        default:
            unsupportedPage(for: attachment)
        }
    }

    private func imagePage(for attachment: ChatAttachment) -> some View {
        ZoomableScrollView {
            if let remoteURL = remoteURL(for: attachment) {
                LazyImage(url: remoteURL) { state in
                    if let image = state.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else if state.error != nil {
                        errorPlaceholder
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                }
            } else if let localURL = localURL(for: attachment),
                      let data = try? Data(contentsOf: localURL),
                      let platformImage = PlatformImage(data: data) {
                Image(platformImage: platformImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                errorPlaceholder
            }
        }
    }

    private func videoPage(for _: ChatAttachment) -> some View {
        VStack {
            Spacer()
            Image(systemName: "play.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white)
            Text("Video playback coming soon")
                .foregroundStyle(.white.opacity(0.6))
                .padding()
            Spacer()
        }
    }

    private func unsupportedPage(for _: ChatAttachment) -> some View {
        VStack {
            Spacer()
            Image(systemName: "doc.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))
            Text("Preview not available")
                .foregroundStyle(.white.opacity(0.6))
                .padding()
            Spacer()
        }
    }

    private var errorPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.exclamationmark")
                .font(.system(size: 48))
            Text("Failed to load image")
                .font(.subheadline)
        }
        .foregroundStyle(.white.opacity(0.6))
    }

    private func remoteURL(for attachment: ChatAttachment) -> URL? {
        switch attachment.payload {
        case let .image(payload): return payload.remoteURL
        case let .video(payload): return payload.thumbnailURL
        default: return nil
        }
    }

    private func localURL(for attachment: ChatAttachment) -> URL? {
        switch attachment.payload {
        case let .image(payload): return payload.localURL
        case let .video(payload): return payload.localURL
        default: return nil
        }
    }
}

// MARK: - ZoomableScrollView

struct ZoomableScrollView<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        #if os(iOS)
            ZoomableUIScrollViewWrapper(content: content)
        #else
            ScrollView([.horizontal, .vertical]) {
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        #endif
    }
}

#if os(iOS)
    import UIKit

    struct ZoomableUIScrollViewWrapper<Content: View>: UIViewRepresentable {
        let content: Content

        func makeUIView(context: Context) -> UIScrollView {
            let scrollView = UIScrollView()
            scrollView.minimumZoomScale = 1.0
            scrollView.maximumZoomScale = 4.0
            scrollView.delegate = context.coordinator
            scrollView.showsHorizontalScrollIndicator = false
            scrollView.showsVerticalScrollIndicator = false
            scrollView.backgroundColor = .clear

            let hostingController = UIHostingController(rootView: content)
            hostingController.view.translatesAutoresizingMaskIntoConstraints = false
            hostingController.view.backgroundColor = .clear
            scrollView.addSubview(hostingController.view)

            NSLayoutConstraint.activate([
                hostingController.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
                hostingController.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
                hostingController.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
                hostingController.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
                hostingController.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
            ])

            return scrollView
        }

        func updateUIView(_: UIScrollView, context _: Context) {}

        func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        class Coordinator: NSObject, UIScrollViewDelegate {
            func viewForZooming(in scrollView: UIScrollView) -> UIView? {
                scrollView.subviews.first
            }
        }
    }
#endif
