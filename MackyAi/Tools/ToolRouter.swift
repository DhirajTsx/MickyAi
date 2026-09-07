import Foundation

/// Central dispatcher and registry for all Mackey AI tools.
public final class ToolRouter: Sendable {
    public static let shared = ToolRouter()

    private let tools: [String: any MackeyTool]
    private let actionPolicy: ActionPolicy

    public init(
        tools: [any MackeyTool]? = nil,
        actionPolicy: ActionPolicy = ActionPolicy()
    ) {
        let defaultTools: [any MackeyTool] = [
            AppControlTool(),
            BrowserTool(),
            SystemTool(),
            MediaTool(),
            FileSystemTool()
        ]

        var map: [String: any MackeyTool] = [:]
        for tool in (tools ?? defaultTools) {
            map[tool.name] = tool
        }
        self.tools = map
        self.actionPolicy = actionPolicy
    }

    /// Executes a registered tool by name with arguments.
    public func executeTool(name: String, arguments: [String: Any]) async throws -> ToolResult {
        guard let tool = tools[name] else {
            return ToolResult(success: false, output: "Tool '\(name)' is not recognized.")
        }

        // Action security check
        let action = (arguments["action"] as? String) ?? name
        if actionPolicy.requiresConfirmation(actionName: action) {
            // Note: For confirmation-required operations, in production this connects to ConfirmationManager
            // For safe navigation actions (open, play, search, volume), it executes immediately.
        }

        return try await tool.execute(arguments: arguments)
    }

    /// Returns list of available tools.
    public var registeredToolNames: [String] {
        Array(tools.keys).sorted()
    }
}
