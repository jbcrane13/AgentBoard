@testable import AgentBoard
import Foundation
import Testing

struct BacklogFilterTests {
    // MARK: - Filter predicate (mirrors BoardView.filteredBeads backlog logic)

    private static let activeStatusLabels: Set<String> = [
        "status:ready", "status:in-progress", "status:blocked", "status:review"
    ]

    private func passesBacklogFilter(_ bead: Bead, hideBacklog: Bool) -> Bool {
        if hideBacklog, bead.status != .done {
            let lowered = Set(bead.labels.map { $0.lowercased() })
            return !lowered.isDisjoint(with: Self.activeStatusLabels)
                || bead.labels.isEmpty
        }
        return true
    }

    // MARK: - Helpers

    private func makeBead(
        status: BeadStatus = .open,
        labels: [String] = []
    ) -> Bead {
        Bead(
            id: "TEST-\(UUID().uuidString.prefix(4))",
            title: "Test bead",
            body: nil,
            status: status,
            kind: .task,
            priority: 2,
            epicId: nil,
            labels: labels,
            assignee: nil,
            createdAt: .now,
            updatedAt: .now,
            dependencies: [],
            gitBranch: nil,
            lastCommit: nil,
            parentIssueNumber: nil
        )
    }

    // MARK: - Tests

    @Test("hides open issue with only priority:backlog label")
    func hidesBacklogOnlyLabel() {
        let bead = makeBead(status: .open, labels: ["priority:backlog"])
        #expect(passesBacklogFilter(bead, hideBacklog: true) == false)
    }

    @Test("shows open issue with status:ready label")
    func showsStatusReady() {
        let bead = makeBead(status: .open, labels: ["status:ready"])
        #expect(passesBacklogFilter(bead, hideBacklog: true) == true)
    }

    @Test("shows open issue with status:in-progress label")
    func showsStatusInProgress() {
        let bead = makeBead(status: .open, labels: ["status:in-progress"])
        #expect(passesBacklogFilter(bead, hideBacklog: true) == true)
    }

    @Test("shows open issue with status:blocked label")
    func showsStatusBlocked() {
        let bead = makeBead(status: .open, labels: ["status:blocked"])
        #expect(passesBacklogFilter(bead, hideBacklog: true) == true)
    }

    @Test("shows open issue with status:review label")
    func showsStatusReview() {
        let bead = makeBead(status: .open, labels: ["status:review"])
        #expect(passesBacklogFilter(bead, hideBacklog: true) == true)
    }

    @Test("shows Done issues regardless of labels")
    func showsDoneRegardlessOfLabels() {
        let bead = makeBead(status: .done, labels: ["priority:backlog"])
        #expect(passesBacklogFilter(bead, hideBacklog: true) == true)
    }

    @Test("shows untriaged issues with empty labels")
    func showsUntriagedEmptyLabels() {
        let bead = makeBead(status: .open, labels: [])
        #expect(passesBacklogFilter(bead, hideBacklog: true) == true)
    }

    @Test("shows all issues when filter disabled")
    func showsAllWhenFilterDisabled() {
        let backlogBead = makeBead(status: .open, labels: ["priority:backlog"])
        let readyBead = makeBead(status: .open, labels: ["status:ready"])
        let emptyBead = makeBead(status: .open, labels: [])
        let doneBead = makeBead(status: .done, labels: ["priority:backlog"])

        #expect(passesBacklogFilter(backlogBead, hideBacklog: false) == true)
        #expect(passesBacklogFilter(readyBead, hideBacklog: false) == true)
        #expect(passesBacklogFilter(emptyBead, hideBacklog: false) == true)
        #expect(passesBacklogFilter(doneBead, hideBacklog: false) == true)
    }
}
