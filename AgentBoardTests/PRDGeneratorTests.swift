@testable import AgentBoard
import Foundation
import Testing

struct PRDGeneratorTests {
    @Test("generatePRD uses GitHub-backed child issues for task decomposition")
    func generatePRDUsesChildIssues() {
        let generator = PRDGenerator()
        let epic = Bead(
            id: "GH-37",
            title: "GitHub-only migration",
            body: "Epic description",
            status: .open,
            kind: .epic,
            priority: 1,
            epicId: nil,
            labels: ["epic", "priority:critical"],
            assignee: "jbcrane13",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_100),
            dependencies: [],
            gitBranch: nil,
            lastCommit: nil,
            parentIssueNumber: nil
        )
        let childOpen = Bead(
            id: "GH-38",
            title: "Fix build blockers",
            body: nil,
            status: .open,
            kind: .task,
            priority: 1,
            epicId: "GH-37",
            labels: ["type:task"],
            assignee: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_090),
            dependencies: [],
            gitBranch: nil,
            lastCommit: nil,
            parentIssueNumber: 37
        )
        let childDone = Bead(
            id: "GH-39",
            title: "Normalize flows",
            body: nil,
            status: .done,
            kind: .task,
            priority: 1,
            epicId: "GH-37",
            labels: ["type:task"],
            assignee: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_080),
            dependencies: [],
            gitBranch: nil,
            lastCommit: nil,
            parentIssueNumber: 37
        )

        let prd = generator.generatePRD(from: epic, childIssues: [childOpen, childDone])

        #expect(prd.contains("## Child issues"))
        #expect(prd.contains("- [ ] GH-38: Fix build blockers"))
        #expect(prd.contains("- [x] GH-39: Normalize flows"))
        #expect(!prd.contains("## Tasks"))
    }
}
