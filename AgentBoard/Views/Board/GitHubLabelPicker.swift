import SwiftUI

/// Visual toggle picker for standard GitHub issue labels.
/// Updates a comma-separated `labelsText` binding.
struct GitHubLabelPicker: View {
    @Binding var labelsText: String

    private let categories: [(name: String, prefix: String, labels: [String])] = [
        ("Type", "type:", ["type:bug", "type:feature", "type:task", "type:epic", "type:chore"]),
        (
            "Priority",
            "priority:",
            ["priority:critical", "priority:high", "priority:medium", "priority:low", "priority:backlog"]
        ),
        ("Status", "status:", ["status:ready", "status:in-progress", "status:blocked", "status:review"]),
        ("Agent", "agent:", ["agent:daneel", "agent:quentin"])
    ]

    private var selectedLabels: Set<String> {
        Set(
            labelsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(categories, id: \.name) { category in
                HStack(spacing: 6) {
                    Text(category.name + ":")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 58, alignment: .leading)

                    ForEach(category.labels, id: \.self) { label in
                        let shortName = label.components(separatedBy: ":").last ?? label
                        let isSelected = selectedLabels.contains(label)

                        Button(shortName) {
                            toggleLabel(label, inCategory: category.prefix)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                        .tint(isSelected ? labelColor(label) : nil)
                        .opacity(isSelected ? 1.0 : 0.6)
                        .accessibilityIdentifier("label_picker_\(label)")
                    }

                    Spacer()
                }
            }
        }
    }

    /// Toggle a label. Within a category (same prefix), selecting one deselects the others (radio-style).
    private func toggleLabel(_ label: String, inCategory prefix: String) {
        var current = Set(
            labelsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )

        if current.contains(label) {
            current.remove(label)
        } else {
            // Remove other labels from the same category before adding this one
            current = current.filter { !$0.hasPrefix(prefix) }
            current.insert(label)
        }

        labelsText = current.sorted().joined(separator: ", ")
    }

    private func labelColor(_ label: String) -> Color {
        switch true {
        case label == "priority:critical", label == "type:bug", label == "status:blocked":
            return .red
        case label == "priority:high":
            return .orange
        case label == "priority:medium", label == "type:task":
            return .blue
        case label == "priority:low", label == "priority:backlog":
            return .secondary
        case label == "type:feature":
            return .purple
        case label == "type:epic":
            return .indigo
        case label == "status:ready", label == "status:review":
            return .green
        case label == "status:in-progress":
            return .orange
        default:
            return .accentColor
        }
    }
}
