import Foundation

struct ChatMessage: Identifiable, Hashable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date
    let beadContext: String?
    let sentToCanvas: Bool

    init(id: UUID = UUID(), role: MessageRole, content: String,
         timestamp: Date = .now, beadContext: String? = nil, sentToCanvas: Bool = false) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.beadContext = beadContext
        self.sentToCanvas = sentToCanvas
    }
}

enum MessageRole: String, Sendable {
    case user
    case assistant
    case system
}

extension ChatMessage {
    var referencedIssueIDs: [String] {
        let pattern = #"\b[A-Za-z][A-Za-z0-9_-]*-[A-Za-z0-9.]+\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = regex.matches(in: content, range: nsRange)
        let values = matches.compactMap { match -> String? in
            guard let range = Range(match.range, in: content) else { return nil }
            return String(content[range])
        }

        var unique: [String] = []
        for value in values where !unique.contains(value) {
            unique.append(value)
        }
        return unique
    }

    var hasCodeBlock: Bool {
        content.contains("```")
    }
}

extension ChatMessage {
    static let samples: [ChatMessage] = [
        ChatMessage(
            role: .assistant,
            content: "Session NetMonitor — NWPath started. Working on NM-096: implementing NWPathMonitor integration.",
            timestamp: .now.addingTimeInterval(-600)
        ),
        ChatMessage(
            role: .user,
            content: "Make sure the path monitor uses an actor for thread safety. Check the existing ConnectionBudget pattern.",
            timestamp: .now.addingTimeInterval(-540)
        ),
        ChatMessage(
            role: .assistant,
            content: "Got it. I'll wrap the monitor in a NetworkPathActor using the same isolation pattern as ConnectionBudget. Currently reading your existing actor code to match the style.",
            timestamp: .now.addingTimeInterval(-480)
        ),
        ChatMessage(
            role: .assistant,
            content: "Created NetworkPathActor.swift with @Observable conformance. The UI test session just picked up the new file — running 3 test cases now.",
            timestamp: .now.addingTimeInterval(-300)
        ),
        ChatMessage(
            role: .user,
            content: "How are the UI tests looking?",
            timestamp: .now.addingTimeInterval(-180)
        ),
        ChatMessage(
            role: .assistant,
            content: "2 of 3 passing. testNetworkStatusBanner is failing — the accessibility identifier on the status banner doesn't match. I'll fix it and re-run.",
            timestamp: .now.addingTimeInterval(-120)
        )
    ]
}
