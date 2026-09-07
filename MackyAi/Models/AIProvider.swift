import Foundation

/// Supported AI providers for Mackey AI.
public enum AIProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case gemini = "Google Gemini"
    case openAI = "OpenAI"
    case claude = "Anthropic Claude"
    case localOllama = "Local (Ollama)"

    public var id: String { rawValue }

    public var defaultModel: String {
        switch self {
        case .gemini:
            return "gemini-2.5-flash"
        case .openAI:
            return "gpt-4o"
        case .claude:
            return "claude-3-5-sonnet-latest"
        case .localOllama:
            return "llama3.2"
        }
    }

    public var requiresAPIKey: Bool {
        switch self {
        case .gemini, .openAI, .claude:
            return true
        case .localOllama:
            return false
        }
    }

    public var keyPlaceholder: String {
        switch self {
        case .gemini:
            return "AIzaSy..."
        case .openAI:
            return "sk-..."
        case .claude:
            return "sk-ant-..."
        case .localOllama:
            return "http://localhost:11434"
        }
    }
}
