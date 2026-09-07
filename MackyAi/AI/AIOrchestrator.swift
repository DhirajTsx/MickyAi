import Foundation

/// Coordinates between user natural language intent parsing, tool routing, and LLM providers.
public final class AIOrchestrator: Sendable {
    public static let shared = AIOrchestrator()

    private let intentParser: IntentParser
    private let toolRouter: ToolRouter
    private let geminiClient: GeminiClient
    private let mockClient: MockAIClient

    public init(
        intentParser: IntentParser = IntentParser(),
        toolRouter: ToolRouter = .shared,
        geminiClient: GeminiClient = GeminiClient(),
        mockClient: MockAIClient = MockAIClient()
    ) {
        self.intentParser = intentParser
        self.toolRouter = toolRouter
        self.geminiClient = geminiClient
        self.mockClient = mockClient
    }

    /// Orchestrates processing of user prompt: executes tool if recognized, or queries AI model.
    public func process(messages: [ChatMessage]) async throws -> (response: String, actionTag: String?) {
        guard let lastMessage = messages.last?.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !lastMessage.isEmpty else {
            return ("How can I help you today?", nil)
        }

        // 1. Fast-path intent matching (sub-50ms execution on local Mac)
        if let intent = intentParser.parseIntent(from: lastMessage) {
            do {
                let toolResult = try await toolRouter.executeTool(
                    name: intent.toolName,
                    arguments: intent.arguments
                )
                return (toolResult.output, toolResult.actionTag)
            } catch {
                return ("Failed to execute action: \(error.localizedDescription)", "Action failed")
            }
        }

        // 2. If Gemini API key is configured, use real Gemini LLM
        if SecretStore.shared.hasKey(for: .gemini) {
            do {
                let geminiResponse = try await geminiClient.sendMessage(messages: messages)
                return (geminiResponse, nil)
            } catch {
                // If network/rate-limit error occurs, fall back to helpful response
                return ("I couldn't reach the AI service (\(error.localizedDescription)). Try asking me to open apps, play songs, or adjust volume directly.", nil)
            }
        }

        // 3. Fallback to local mock client
        let fallbackResponse = try await mockClient.sendMessage(messages: messages)
        return (fallbackResponse, nil)
    }
}
