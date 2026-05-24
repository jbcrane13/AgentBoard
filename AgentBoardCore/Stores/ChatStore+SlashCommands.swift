import Foundation

extension ChatStore {
    func handleSlashCommand(_ text: String, conversationID: UUID) async -> Bool {
        let result = SlashCommandHandler.handle(text)
        switch result {
        case .newConversation:
            clearDraft()
            startNewConversation()
            return true
        case .clearConversation:
            clearDraft()
            deleteConversation(id: conversationID)
            startNewConversation()
            return true
        case let .switchModel(modelID):
            clearDraft()
            selectModel(modelID)
            statusMessage = "Switched to model: \(modelID)"
            return true
        case .showHelp:
            clearDraft()
            await appendSystemMessage(SlashCommandHandler.formatHelp(), to: conversationID)
            return true
        case .showStatus:
            clearDraft()
            await appendSystemMessage(statusMessageForSlashCommand(), to: conversationID)
            return true
        case .showConfig:
            clearDraft()
            await appendSystemMessage(configMessageForSlashCommand(), to: conversationID)
            return true
        case .showSkills:
            clearDraft()
            await appendSystemMessage(SlashCommandHandler.formatSkills([]), to: conversationID)
            return true
        case let .activateSkill(name):
            clearDraft()
            await appendSystemMessage("Activating skill: \(name)…", to: conversationID)
            statusMessage = "Skill '\(name)' activated"
            return true
        case .showMemory, .showTools, .toggleThinking, .toggleWeb,
             .toggleCode, .toggleImage, .toggleSpeak:
            return await handleToggleCommand(result, conversationID: conversationID)
        case .resetConversation:
            clearDraft()
            startNewConversation()
            statusMessage = "Conversation reset"
            return true
        case let .handled(response):
            clearDraft()
            await appendSystemMessage(response, to: conversationID)
            return true
        case let .unknown(command):
            statusMessage = "Sending /\(command) to agent..."
            return false
        case .passthrough:
            return false
        }
    }

    func handleToggleCommand(
        _ result: SlashCommandResult,
        conversationID: UUID
    ) async -> Bool {
        clearDraft()
        let message = switch result {
        case .showMemory: "Memory lookup sent to Hermes. Response will appear below."
        case .showTools: "Tool listing sent to Hermes. Response will appear below."
        case .toggleThinking: "Toggled thinking mode. Sent to agent."
        case .toggleWeb: "Toggled web access. Sent to agent."
        case .toggleCode: "Toggled code execution. Sent to agent."
        case .toggleImage: "Toggled image generation. Sent to agent."
        case .toggleSpeak: "Toggled voice output. Sent to agent."
        default: "Command sent to agent."
        }
        await appendSystemMessage(message, to: conversationID)
        return false
    }

    private func statusMessageForSlashCommand() -> String {
        let state = switch connectionState {
        case .connected: "Connected"
        case .connecting: "Connecting"
        case .disconnected: "Disconnected"
        case .reconnecting: "Reconnecting"
        case .failed: "Failed"
        }
        return SlashCommandHandler.formatStatus(
            connectionState: state,
            model: settingsStore.hermesModelID,
            conversationTitle: selectedConversation?.title ?? "None",
            messageCount: messages.count
        )
    }

    private func configMessageForSlashCommand() -> String {
        SlashCommandHandler.formatConfig(
            gatewayURL: settingsStore.hermesGatewayURL,
            model: settingsStore.hermesModelID,
            hasAPIKey: settingsStore.hermesAPIKey.trimmedOrNil != nil,
            repos: settingsStore.repositories.map(\.fullName)
        )
    }
}
