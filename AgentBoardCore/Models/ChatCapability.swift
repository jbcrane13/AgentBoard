import Foundation

/// A per-conversation capability toggle. Hermes' `/v1/chat/completions` endpoint accepts
/// only `messages`, `stream`, and `model` — there is no server-side capability parameter —
/// so these toggles are honestly implemented as client-side system-prompt injection.
public enum ChatCapability: String, Codable, CaseIterable, Sendable {
    case thinking
    case web
    case code
    case image
    case speak

    public var displayName: String {
        switch self {
        case .thinking: "Thinking"
        case .web: "Web Access"
        case .code: "Code Execution"
        case .image: "Image Generation"
        case .speak: "Voice Output"
        }
    }

    public var promptInstruction: String {
        switch self {
        case .thinking: "Think step-by-step and show deeper reasoning before answering."
        case .web: "Use web search/browsing tools when they would improve the answer."
        case .code: "Use code execution tools when they would improve the answer."
        case .image: "Generate images when the user asks for visuals."
        case .speak: "Keep replies concise and speakable; they may be read aloud."
        }
    }
}
