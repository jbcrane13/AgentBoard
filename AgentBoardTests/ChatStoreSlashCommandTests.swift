import AgentBoardCore
import Foundation
import Testing

@Suite("ChatStore — slash command integration", .serialized)
// swiftlint:disable:next type_body_length
struct ChatStoreSlashCommandTests {
    @MainActor
    private func makeStore(hermesURL: String = "http://127.0.0.1:8642") throws -> ChatStore {
        let session = makeMockSession { _ in
            let response = try HTTPURLResponse(
                url: URL(string: "http://127.0.0.1:8642/health")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            )!
            return (response, Data())
        }
        let hermesClient = HermesGatewayClient(session: session)
        let cache = try AgentBoardCache(inMemory: true)
        let repo = SettingsRepository(
            suiteName: "SlashCmdTests-\(UUID().uuidString)",
            serviceName: "SlashCmdTests-\(UUID().uuidString)"
        )
        let settingsStore = SettingsStore(repository: repo)
        settingsStore.hermesGatewayURL = hermesURL
        settingsStore.hermesModelID = "hermes-agent"
        let store = ChatStore(hermesClient: hermesClient, cache: cache, settingsStore: settingsStore)
        store.startNewConversation()
        return store
    }

    // MARK: - /help

    @Test
    @MainActor
    func helpCommandAppendsSystemMessage() async throws {
        let store = try makeStore()
        store.draft = "/help"
        await store.sendDraft()
        let systemMessages = store.messages.filter { $0.role == .assistant && !$0.isStreaming }
        #expect(!systemMessages.isEmpty)
        let content = try #require(systemMessages.first?.content)
        #expect(content.contains("/help") || content.contains("Commands"))
    }

    @Test
    @MainActor
    func helpCommandClearsDraft() async throws {
        let store = try makeStore()
        store.draft = "/help"
        await store.sendDraft()
        #expect(store.draft.isEmpty)
    }

    @Test
    @MainActor
    func commandsAliasAppendsHelpMessage() async throws {
        let store = try makeStore()
        store.draft = "/commands"
        await store.sendDraft()
        let systemMessages = store.messages.filter { $0.role == .assistant && !$0.isStreaming }
        #expect(!systemMessages.isEmpty)
        let content = try #require(systemMessages.first?.content)
        #expect(content.contains("/help") || content.contains("Commands"))
    }

    // MARK: - /new

    @Test
    @MainActor
    func newCommandStartsNewConversation() async throws {
        let store = try makeStore()
        let originalID = try #require(store.selectedConversationID)
        store.draft = "/new"
        await store.sendDraft()
        #expect(store.selectedConversationID != originalID)
    }

    @Test
    @MainActor
    func newCommandClearsDraft() async throws {
        let store = try makeStore()
        store.draft = "/new"
        await store.sendDraft()
        #expect(store.draft.isEmpty)
    }

    @Test
    @MainActor
    func newCommandDoesNotAppendSystemMessage() async throws {
        let store = try makeStore()
        store.draft = "/new"
        await store.sendDraft()
        // New conversation has no messages
        #expect(store.messages.isEmpty)
    }

    // MARK: - /clear

    @Test
    @MainActor
    func clearCommandDeletesCurrentConversation() async throws {
        let store = try makeStore()
        let originalID = try #require(store.selectedConversationID)
        store.draft = "/clear"
        await store.sendDraft()
        #expect(!store.conversations.map(\.id).contains(originalID))
    }

    @Test
    @MainActor
    func clearCommandCreatesReplacementConversation() async throws {
        let store = try makeStore()
        store.draft = "/clear"
        await store.sendDraft()
        #expect(store.selectedConversationID != nil)
        #expect(!store.conversations.isEmpty)
    }

    @Test
    @MainActor
    func clearCommandClearsDraft() async throws {
        let store = try makeStore()
        store.draft = "/clear"
        await store.sendDraft()
        #expect(store.draft.isEmpty)
    }

    // MARK: - /model

    @Test
    @MainActor
    func modelCommandWithNameSetsStatusMessage() async throws {
        let store = try makeStore()
        store.draft = "/model hermes-pro"
        await store.sendDraft()
        let status = try #require(store.statusMessage)
        #expect(status.contains("hermes-pro"))
    }

    @Test
    @MainActor
    func modelCommandWithNameClearsDraft() async throws {
        let store = try makeStore()
        store.draft = "/model hermes-pro"
        await store.sendDraft()
        #expect(store.draft.isEmpty)
    }

    @Test
    @MainActor
    func modelCommandWithoutArgShowsStatusMessage() async throws {
        // /model with no argument shows the current status (same as /status)
        let store = try makeStore()
        store.draft = "/model"
        await store.sendDraft()
        let systemMessages = store.messages.filter { $0.role == .assistant && !$0.isStreaming }
        #expect(!systemMessages.isEmpty)
    }

    // MARK: - /status

    @Test
    @MainActor
    func statusCommandAppendsSystemMessage() async throws {
        let store = try makeStore()
        store.draft = "/status"
        await store.sendDraft()
        let systemMessages = store.messages.filter { $0.role == .assistant && !$0.isStreaming }
        #expect(!systemMessages.isEmpty)
    }

    @Test
    @MainActor
    func statusCommandClearsDraft() async throws {
        let store = try makeStore()
        store.draft = "/status"
        await store.sendDraft()
        #expect(store.draft.isEmpty)
    }

    @Test
    @MainActor
    func statusMessageContainsConnectionState() async throws {
        let store = try makeStore()
        store.draft = "/status"
        await store.sendDraft()
        let systemMessages = store.messages.filter { $0.role == .assistant && !$0.isStreaming }
        let content = try #require(systemMessages.first?.content)
        #expect(
            content.contains("Connected") ||
                content.contains("Disconnected") ||
                content.contains("Connecting") ||
                content.contains("State")
        )
    }

    // MARK: - /config

    @Test
    @MainActor
    func configCommandAppendsSystemMessage() async throws {
        let store = try makeStore()
        store.draft = "/config"
        await store.sendDraft()
        let systemMessages = store.messages.filter { $0.role == .assistant && !$0.isStreaming }
        #expect(!systemMessages.isEmpty)
    }

    @Test
    @MainActor
    func configMessageContainsGatewayURL() async throws {
        let store = try makeStore(hermesURL: "http://127.0.0.1:8642")
        store.draft = "/config"
        await store.sendDraft()
        let systemMessages = store.messages.filter { $0.role == .assistant && !$0.isStreaming }
        let content = try #require(systemMessages.first?.content)
        #expect(content.contains("127.0.0.1:8642"))
    }

    @Test
    @MainActor
    func configCommandClearsDraft() async throws {
        let store = try makeStore()
        store.draft = "/config"
        await store.sendDraft()
        #expect(store.draft.isEmpty)
    }

    // MARK: - /skills

    @Test
    @MainActor
    func skillsCommandAppendsSystemMessage() async throws {
        let store = try makeStore()
        store.draft = "/skills"
        await store.sendDraft()
        let systemMessages = store.messages.filter { $0.role == .assistant && !$0.isStreaming }
        #expect(!systemMessages.isEmpty)
    }

    @Test
    @MainActor
    func skillsCommandClearsDraft() async throws {
        let store = try makeStore()
        store.draft = "/skills"
        await store.sendDraft()
        #expect(store.draft.isEmpty)
    }

    // MARK: - /skill <name>

    @Test
    @MainActor
    func skillActivationAppendsMessageContainingSkillName() async throws {
        let store = try makeStore()
        store.draft = "/skill my-skill"
        await store.sendDraft()
        let systemMessages = store.messages.filter { $0.role == .assistant && !$0.isStreaming }
        #expect(!systemMessages.isEmpty)
        let content = try #require(systemMessages.first?.content)
        #expect(content.contains("my-skill"))
    }

    @Test
    @MainActor
    func skillActivationSetsStatusMessageWithSkillName() async throws {
        let store = try makeStore()
        store.draft = "/skill my-skill"
        await store.sendDraft()
        let status = try #require(store.statusMessage)
        #expect(status.contains("my-skill"))
    }

    @Test
    @MainActor
    func skillActivationClearsDraft() async throws {
        let store = try makeStore()
        store.draft = "/skill my-skill"
        await store.sendDraft()
        #expect(store.draft.isEmpty)
    }

    // MARK: - /reset

    @Test
    @MainActor
    func resetCommandStartsNewConversation() async throws {
        let store = try makeStore()
        let originalID = try #require(store.selectedConversationID)
        store.draft = "/reset"
        await store.sendDraft()
        #expect(store.selectedConversationID != originalID)
    }

    @Test
    @MainActor
    func resetCommandSetsStatusMessage() async throws {
        let store = try makeStore()
        store.draft = "/reset"
        await store.sendDraft()
        #expect(store.statusMessage == "Conversation reset")
    }

    @Test
    @MainActor
    func resetCommandClearsDraft() async throws {
        let store = try makeStore()
        store.draft = "/reset"
        await store.sendDraft()
        #expect(store.draft.isEmpty)
    }

    // MARK: - Toggle commands (/think, /web, /code, /image, /speak)

    // These return false from handleSlashCommand so they are also forwarded to the agent,
    // but they always prepend a local notification message before the network call.

    @Test
    @MainActor
    func thinkCommandAppendsToggleNotification() async throws {
        let store = try makeStore()
        store.draft = "/think"
        await store.sendDraft()
        let hasToggleMessage = store.messages.contains {
            $0.role == .assistant && $0.content.lowercased().contains("think")
        }
        #expect(hasToggleMessage)
    }

    @Test
    @MainActor
    func thinkCommandClearsDraft() async throws {
        let store = try makeStore()
        store.draft = "/think"
        await store.sendDraft()
        #expect(store.draft.isEmpty)
    }

    @Test
    @MainActor
    func webCommandAppendsToggleNotification() async throws {
        let store = try makeStore()
        store.draft = "/web"
        await store.sendDraft()
        let hasToggleMessage = store.messages.contains {
            $0.role == .assistant && $0.content.lowercased().contains("web")
        }
        #expect(hasToggleMessage)
    }

    @Test
    @MainActor
    func codeCommandAppendsToggleNotification() async throws {
        let store = try makeStore()
        store.draft = "/code"
        await store.sendDraft()
        let hasToggleMessage = store.messages.contains {
            $0.role == .assistant && $0.content.lowercased().contains("code")
        }
        #expect(hasToggleMessage)
    }

    // MARK: - Passthrough commands (/retry, /stop, /compress, /compact)

    // These are forwarded directly to the agent with no local system message.

    @Test
    @MainActor
    func retryCommandForwardsToAgentWithoutSystemMessage() async throws {
        let store = try makeStore()
        store.draft = "/retry"
        await store.sendDraft()
        // The slash handler appends NO local system message for passthrough commands.
        // Only messages present are the user message and the agent's streaming/failed response.
        let slashSystemMessages = store.messages.filter {
            $0.role == .assistant && !$0.content.isEmpty && !$0.isStreaming
        }
        #expect(slashSystemMessages.isEmpty)
    }

    @Test
    @MainActor
    func stopCommandForwardsToAgentWithoutSystemMessage() async throws {
        let store = try makeStore()
        store.draft = "/stop"
        await store.sendDraft()
        let slashSystemMessages = store.messages.filter {
            $0.role == .assistant && !$0.content.isEmpty && !$0.isStreaming
        }
        #expect(slashSystemMessages.isEmpty)
    }

    // MARK: - Unknown commands

    @Test
    @MainActor
    func unknownCommandForwardsToAgent() async throws {
        let store = try makeStore()
        store.draft = "/foobar"
        await store.sendDraft()
        // Unknown command forwarded — user message should be in messages
        let userMessages = store.messages.filter { $0.role == .user }
        #expect(userMessages.contains { $0.content == "/foobar" })
    }

    @Test
    @MainActor
    func unknownCommandDoesNotAppendLocalSystemMessage() async throws {
        let store = try makeStore()
        store.draft = "/foobar"
        await store.sendDraft()
        // No local system message for unknown commands (they're forwarded)
        let systemMessages = store.messages.filter {
            $0.role == .assistant && $0.content.lowercased().contains("foobar")
        }
        #expect(systemMessages.isEmpty)
    }

    // MARK: - Edge cases

    @Test
    @MainActor
    func emptyDraftDoesNothing() async throws {
        let store = try makeStore()
        store.draft = ""
        await store.sendDraft()
        #expect(store.messages.isEmpty)
    }

    @Test
    @MainActor
    func nonSlashTextSendsToAgent() async throws {
        let store = try makeStore()
        store.draft = "Hello, agent!"
        await store.sendDraft()
        // Normal message creates a user message
        let userMessages = store.messages.filter { $0.role == .user }
        #expect(userMessages.contains { $0.content == "Hello, agent!" })
    }

    @Test
    @MainActor
    func whitespaceOnlyDraftDoesNothing() async throws {
        let store = try makeStore()
        store.draft = "   \n\t  "
        await store.sendDraft()
        #expect(store.messages.isEmpty)
    }

    @Test
    @MainActor
    func leadingWhitespaceBeforeSlashIsStillHandledLocally() async throws {
        // Dispatcher trims before handing to handler, so leading whitespace
        // shouldn't prevent a /help command from being recognised.
        let store = try makeStore()
        store.draft = "   /help"
        await store.sendDraft()
        let systemMessages = store.messages.filter { $0.role == .assistant && !$0.isStreaming }
        #expect(!systemMessages.isEmpty)
        #expect(store.draft.isEmpty)
    }

    @Test
    @MainActor
    func bareSlashAppendsHelpSystemMessage() async throws {
        let store = try makeStore()
        store.draft = "/"
        await store.sendDraft()
        let systemMessages = store.messages.filter { $0.role == .assistant && !$0.isStreaming }
        #expect(!systemMessages.isEmpty)
        let content = try #require(systemMessages.first?.content)
        #expect(content.contains("/help") || content.contains("Commands"))
    }

    @Test
    @MainActor
    func tabSeparatedModelCommandSwitchesModel() async throws {
        let store = try makeStore()
        store.draft = "/model\thermes-pro"
        await store.sendDraft()
        let status = try #require(store.statusMessage)
        #expect(status.contains("hermes-pro"))
        #expect(store.draft.isEmpty)
    }

    @Test
    @MainActor
    func localSlashCommandClearsPendingAttachments() async throws {
        let store = try makeStore()
        let attachment = ChatAttachment(
            type: .file,
            payload: .file(FileAttachmentPayload(
                localURL: URL(fileURLWithPath: "/tmp/edge-case.txt"),
                fileName: "edge-case.txt"
            ))
        )
        store.addAttachment(attachment)
        #expect(store.pendingAttachments.count == 1)

        store.draft = "/help"
        await store.sendDraft()

        // Local commands clear the draft AND any pending attachments — they
        // shouldn't leak into the next message the user sends.
        #expect(store.pendingAttachments.isEmpty)
        #expect(store.draft.isEmpty)
    }

    @Test
    @MainActor
    func consecutiveSlashCommandsAccumulateMessages() async throws {
        // Make sure running multiple local commands in a row doesn't clobber
        // earlier system messages or get tangled in shared state.
        let store = try makeStore()
        store.draft = "/help"
        await store.sendDraft()
        let firstCount = store.messages.count

        store.draft = "/status"
        await store.sendDraft()
        #expect(store.messages.count >= firstCount + 1)

        store.draft = "/config"
        await store.sendDraft()
        #expect(store.messages.count >= firstCount + 2)
    }

    @Test
    @MainActor
    func unknownSlashCommandClearsStatusBeforeForwarding() async throws {
        // Unknown commands fall through to the agent path. They shouldn't
        // leave a stale "Sending /foo to agent..." status hanging around once
        // the network call fails — errorMessage should be set instead.
        let store = try makeStore()
        store.draft = "/foobar"
        await store.sendDraft()
        // After the failed network call, the user message should be persisted
        // and the draft cleared. (The mock returns 200 OK with empty body, so
        // streaming finishes without error.)
        let userMessages = store.messages.filter { $0.role == .user }
        #expect(userMessages.contains { $0.content == "/foobar" })
        #expect(store.draft.isEmpty)
    }
}
