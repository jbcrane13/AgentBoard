import SwiftUI

#if os(iOS)
import UIKit
#endif

enum AgentBoardKeyboard {
    @MainActor
    static func dismiss() {
        #if os(iOS)
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
        #endif
    }
}

extension View {
    @ViewBuilder
    func agentBoardKeyboardDismissToolbar() -> some View {
        #if os(iOS)
        toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    AgentBoardKeyboard.dismiss()
                }
            }
        }
        #else
        self
        #endif
    }

    @ViewBuilder
    func agentBoardScrollDismissesKeyboard() -> some View {
        #if os(iOS)
        scrollDismissesKeyboard(.interactively)
        #else
        self
        #endif
    }
}
