import SwiftUI

struct LifeOpsQuickCaptureView: View {
    @State private var text = ""
    let onSubmit: (String) -> Void

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "square.and.pencil")
                .foregroundStyle(NeuPalette.textSecondary)

            TextField("Quick capture", text: $text)
                .textFieldStyle(.plain)
                .submitLabel(.done)
                .onSubmit(submit)
                .accessibilityIdentifier("lifeops.quickCapture.field")

            Button(action: submit) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(canSubmit ? NeuPalette.accentForeground : NeuPalette.textDisabled)
            .background(canSubmit ? NeuPalette.accentCyan : NeuPalette.inset)
            .clipShape(Circle())
            .disabled(!canSubmit)
            .accessibilityLabel("Add LifeOps task")
            .accessibilityIdentifier("lifeops.quickCapture.submit")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(NeuPalette.inset)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func submit() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmit(trimmed)
        text = ""
    }
}
