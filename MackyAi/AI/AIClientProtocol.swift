import Foundation

/// Protocol defining the interface for AI brain providers.
public protocol AIClientProtocol: Sendable {
    /// Sends a list of conversation messages and returns the assistant's response.
    func sendMessage(messages: [ChatMessage]) async throws -> String
}

/// Errors that can occur during AI communication.
public enum AIClientError: LocalizedError, Sendable {
    case missingAPIKey(provider: String)
    case networkUnavailable
    case rateLimited
    case serverError(statusCode: Int, message: String)
    case cancelled
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey(let provider):
            return "Missing API key for \(provider). Please configure it in Settings."
        case .networkUnavailable:
            return "Network connection unavailable. Please check your internet connection."
        case .rateLimited:
            return "API rate limit reached. Please wait a moment and try again."
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message)"
        case .cancelled:
            return "Request was cancelled."
        case .invalidResponse:
            return "Received an unexpected response from the AI service."
        }
    }
}
