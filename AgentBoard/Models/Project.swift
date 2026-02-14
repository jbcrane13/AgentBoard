import Foundation

struct Project: Identifiable, Hashable {
    let id: UUID
    let name: String
    let path: URL
    let beadsPath: URL
    let icon: String
    var isActive: Bool

    var openCount: Int
    var inProgressCount: Int
    var totalCount: Int

    static let samples: [Project] = [
        Project(
            id: UUID(),
            name: "NetMonitor-iOS",
            path: URL(fileURLWithPath: "/Users/blake/Projects/NetMonitor-iOS"),
            beadsPath: URL(fileURLWithPath: "/Users/blake/Projects/NetMonitor-iOS/.beads"),
            icon: "\u{1F4E1}",
            isActive: true,
            openCount: 3,
            inProgressCount: 2,
            totalCount: 97
        ),
        Project(
            id: UUID(),
            name: "JubileeTracker",
            path: URL(fileURLWithPath: "/Users/blake/Projects/JubileeTracker"),
            beadsPath: URL(fileURLWithPath: "/Users/blake/Projects/JubileeTracker/.beads"),
            icon: "\u{1F389}",
            isActive: false,
            openCount: 5,
            inProgressCount: 3,
            totalCount: 34
        ),
        Project(
            id: UUID(),
            name: "CabinetVision",
            path: URL(fileURLWithPath: "/Users/blake/Projects/CabinetVision"),
            beadsPath: URL(fileURLWithPath: "/Users/blake/Projects/CabinetVision/.beads"),
            icon: "\u{1F5C4}",
            isActive: false,
            openCount: 2,
            inProgressCount: 1,
            totalCount: 12
        ),
        Project(
            id: UUID(),
            name: "AppJubilee",
            path: URL(fileURLWithPath: "/Users/blake/Projects/AppJubilee"),
            beadsPath: URL(fileURLWithPath: "/Users/blake/Projects/AppJubilee/.beads"),
            icon: "\u{1F4CB}",
            isActive: false,
            openCount: 1,
            inProgressCount: 0,
            totalCount: 8
        ),
    ]
}
