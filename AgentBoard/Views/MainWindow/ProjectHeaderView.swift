import SwiftUI

struct ProjectHeaderView: View {
    let project: Project

    var body: some View {
        HStack(spacing: 12) {
            Text(project.name)
                .font(.system(size: 20, weight: .bold, design: .default))
                .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))

            statusBadge

            Spacer()

            headerButtons

            statsRow
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color(red: 0.961, green: 0.961, blue: 0.941))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Color(red: 0.204, green: 0.78, blue: 0.349))
                .frame(width: 6, height: 6)
            Text("Live")
                .font(.system(size: 11, weight: .semibold))
        }
        .foregroundStyle(Color(red: 0.102, green: 0.541, blue: 0.243))
        .padding(.horizontal, 10)
        .padding(.vertical, 3)
        .background(Color(red: 0.91, green: 0.973, blue: 0.925), in: Capsule())
    }

    private var headerButtons: some View {
        HStack(spacing: 8) {
            Button(action: {}) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 10))
                    Text("Live Edit")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 7))
            }
            .buttonStyle(.plain)

            Button(action: {}) {
                Text("Plan")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(.background, in: RoundedRectangle(cornerRadius: 7))
                    .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color(red: 0.886, green: 0.878, blue: 0.847), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statItem(value: project.openCount, label: "Open")
            statItem(value: project.inProgressCount, label: "In Progress")
            statItem(value: project.totalCount, label: "Total")
        }
        .padding(.leading, 12)
    }

    private func statItem(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(Color(red: 0.1, green: 0.1, blue: 0.1))
            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(.secondary)
        }
    }
}
