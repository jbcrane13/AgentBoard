import SwiftUI

struct SplitPanelView: View {
    var body: some View {
        VSplitView {
            CanvasPanelView()
                .frame(minHeight: 120)

            ChatPanelView()
                .frame(minHeight: 200)
        }
    }
}
