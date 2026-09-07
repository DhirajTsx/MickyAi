import SwiftUI

/// Represents the current operational state of Mackey AI.
public enum AssistantStatus: Equatable, Hashable, Sendable {
    case idle
    case listening
    case thinking
    case executing(action: String)
    case error(message: String)

    public var displayText: String {
        switch self {
        case .idle:
            return "Ready"
        case .listening:
            return "Listening..."
        case .thinking:
            return "Thinking..."
        case .executing(let action):
            return "Executing: \(action)"
        case .error(let message):
            return "Error: \(message)"
        }
    }

    public var shortDescription: String {
        switch self {
        case .idle:
            return "Idle"
        case .listening:
            return "Listening"
        case .thinking:
            return "Thinking"
        case .executing:
            return "Working"
        case .error:
            return "Error"
        }
    }

    public var iconName: String {
        switch self {
        case .idle:
            return "waveform.circle.fill"
        case .listening:
            return "mic.circle.fill"
        case .thinking:
            return "brain.head.profile"
        case .executing:
            return "gearshape.arrow.triangle.2.circlepath"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    public var color: Color {
        switch self {
        case .idle:
            return .blue
        case .listening:
            return .red
        case .thinking:
            return .purple
        case .executing:
            return .orange
        case .error:
            return .red
        }
    }

    public var isBusy: Bool {
        switch self {
        case .thinking, .executing:
            return true
        case .idle, .listening, .error:
            return false
        }
    }
}
