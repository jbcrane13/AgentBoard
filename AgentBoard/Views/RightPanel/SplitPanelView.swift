import SwiftUI

struct SplitPanelView: View {
    @State private var splitRatio: CGFloat = 0.6
    @State private var dragStartRatio: CGFloat?

    private let defaultSplitRatio: CGFloat = 0.6
    private let dividerHeight: CGFloat = 8
    private let minimumPanelHeight: CGFloat = 120
    private let collapseThreshold: CGFloat = 0.05

    var body: some View {
        GeometryReader { geometry in
            let availableHeight = max(geometry.size.height - dividerHeight, 1)
            let resolvedRatio = currentRatio(for: availableHeight)
            let topHeight = max(0, availableHeight * resolvedRatio)
            let bottomHeight = max(0, availableHeight - topHeight)

            VStack(spacing: 0) {
                if topHeight > 0 {
                    CanvasPanelView()
                        .frame(height: topHeight)
                }

                divider(availableHeight: availableHeight)
                    .frame(height: dividerHeight)

                if bottomHeight > 0 {
                    ChatPanelView()
                        .frame(height: bottomHeight)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func divider(availableHeight: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.primary.opacity(0.08))

            Capsule()
                .fill(Color.secondary.opacity(0.65))
                .frame(width: 40, height: 3)
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            withAnimation(.easeOut(duration: 0.15)) {
                splitRatio = defaultSplitRatio
            }
        }
        .gesture(
            DragGesture(minimumDistance: 1)
                .onChanged { value in
                    if dragStartRatio == nil {
                        dragStartRatio = splitRatio
                    }
                    let startingRatio = dragStartRatio ?? splitRatio
                    let candidate = startingRatio + (value.translation.height / availableHeight)
                    splitRatio = clampedRatio(
                        candidate,
                        availableHeight: availableHeight,
                        allowCollapse: false
                    )
                }
                .onEnded { value in
                    let startingRatio = dragStartRatio ?? splitRatio
                    let candidate = startingRatio + (value.translation.height / availableHeight)
                    splitRatio = clampedRatio(
                        candidate,
                        availableHeight: availableHeight,
                        allowCollapse: true
                    )
                    dragStartRatio = nil
                }
        )
    }

    private func currentRatio(for availableHeight: CGFloat) -> CGFloat {
        if splitRatio == 0 || splitRatio == 1 {
            return splitRatio
        }
        return clampedRatio(splitRatio, availableHeight: availableHeight, allowCollapse: false)
    }

    private func clampedRatio(
        _ ratio: CGFloat,
        availableHeight: CGFloat,
        allowCollapse: Bool
    ) -> CGFloat {
        let boundedRatio = min(max(ratio, 0), 1)

        if allowCollapse {
            if boundedRatio <= collapseThreshold {
                return 0
            }
            if boundedRatio >= (1 - collapseThreshold) {
                return 1
            }
        }

        let minimumRatio = min(max(minimumPanelHeight / max(availableHeight, 1), 0), 0.45)
        return min(max(boundedRatio, minimumRatio), 1 - minimumRatio)
    }
}
