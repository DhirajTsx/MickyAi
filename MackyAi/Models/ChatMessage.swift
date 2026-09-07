import Foundation

/// Role of the entity that sent the message.
public enum MessageRole: String, Codable, Sendable {
    case user
    case assistant
    case system
}

/// Delivery status of a message.
public enum MessageStatus: String, Codable, Sendable {
    case sending
    case completed
    case failed
}

/// Represents a single conversation message in Mackey AI.
public struct ChatMessage: Identifiable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let role: MessageRole
    public var content: String
    public let timestamp: Date
    public var status: MessageStatus
    public var actionTag: String?

    public init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        status: MessageStatus = .completed,
        actionTag: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.status = status
        self.actionTag = actionTag
    }
}
