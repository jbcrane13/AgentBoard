import SwiftUI

struct ViewsNavView: View {
    @Environment(AppState.self) private var appState
    let showHeader: Bool

    init(showHeader: Bool = true) {
        self.showHeader = showHeader
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showHeader {
                sectionHeader("Views")
            }

            ForEach(navItems, id: \.label) { item in
                navRow(item)
            }
        }
        .padding(.horizontal, showHeader ? 12 : 2)
        .padding(.top, showHeader ? 8 : 2)
        .padding(.bottom, 8)
    }

    private struct NavItem {
        let icon: String
        let label: String
        let nav: SidebarNavItem
    }

    private var navItems: [NavItem] {
        [
            NavItem(icon: "square.grid.2x2", label: "Board", nav: .board),
            NavItem(icon: "target", label: "Epics", nav: .epics),
            NavItem(icon: "clock", label: "History", nav: .history),
            NavItem(icon: "gear", label: "Settings", nav: .settings),
        ]
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .textCase(.uppercase)
            .tracking(0.8)
            .foregroundStyle(Color(red: 0.557, green: 0.557, blue: 0.576))
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
    }

    private func navRow(_ item: NavItem) -> some View {
        Button(action: {
            appState.navigate(to: item.nav)
        }) {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .font(.system(size: 13))
                    .frame(width: 18, height: 18)
                    .opacity(0.7)

                Text(item.label)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(red: 0.878, green: 0.878, blue: 0.878))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(appState.sidebarNavSelection == item.nav
                          ? Color.white.opacity(0.12)
                          : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}
