import Foundation

/// Security classification for actions executed by Mackey AI.
public enum ActionRiskLevel: String, Codable, Sendable {
    /// Safe operations that can execute automatically without confirmation.
    case safe

    /// Operations that require explicit user confirmation before execution.
    case confirmationRequired

    /// High-risk or potentially destructive operations requiring prominent warnings.
    case highRisk
}

/// Evaluator that determines whether an intended action requires confirmation.
public struct ActionPolicy: Sendable {
    public init() {}

    /// Classifies an action name / category into a risk level.
    public func classify(actionName: String) -> ActionRiskLevel {
        let normalized = actionName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch normalized {
        case "open_application", "activate_application", "list_applications",
             "open_website", "search_web", "play_media", "get_volume",
             "get_system_info", "take_screenshot", "find_file", "list_files":
            return .safe

        case "change_volume", "mute_system", "create_folder", "move_file", "rename_file":
            return .safe

        case "quit_application", "send_message", "send_email", "change_setting":
            return .confirmationRequired

        case "delete_file", "delete_folder", "execute_shell", "modify_system", "wipe_directory":
            return .highRisk

        default:
            // Fail-safe: Any unknown action defaults to requiring confirmation
            return .confirmationRequired
        }
    }

    /// Returns true if the action requires confirmation before proceeding.
    public func requiresConfirmation(actionName: String) -> Bool {
        let level = classify(actionName: actionName)
        return level != .safe
    }
}
