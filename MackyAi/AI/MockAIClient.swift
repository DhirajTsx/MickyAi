import Foundation

/// A mock AI client for Phase 1 development and offline UI testing.
public final class MockAIClient: AIClientProtocol {
    public init() {}

    public func sendMessage(messages: [ChatMessage]) async throws -> String {
        // Simulate thinking latency while supporting cancellation
        try await Task.sleep(nanoseconds: 700_000_000)

        guard let lastMessage = messages.last?.content.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return "How can I assist you with your Mac today?"
        }

        let lower = lastMessage.lowercased()

        if lower.contains("thenkizhakku") || lower.contains("play") {
            return "I've detected your request to play music. Media control tools will be connected in Phase 4 to play this on YouTube or your preferred music app."
        } else if lower.contains("safari") || lower.contains("open ") || lower.contains("launch") {
            return "I recognized an application launch command. Application control tools are scheduled for Phase 4."
        } else if lower.contains("volume") || lower.contains("mute") {
            return "System control command detected. Volume and audio management tools will be active in Phase 4."
        } else if lower.contains("screenshot") {
            return "Screenshot capture command recognized. Screen capture capabilities will be integrated in Phase 4."
        } else if lower.contains("hello") || lower.contains("hi") || lower.contains("hey") {
            return "Hello! I'm Mackey, your personal macOS assistant. You can give me voice or text commands to control your Mac."
        } else {
            return "I received your request: \"\(lastMessage)\". My modular architecture is ready to orchestrate tools as we advance through the phases."
        }
    }
}
