import Foundation

/// Result of a tool execution.
public struct ToolResult: Sendable {
    public let success: Bool
    public let output: String
    public let actionTag: String?

    public init(success: Bool, output: String, actionTag: String? = nil) {
        self.success = success
        self.output = output
        self.actionTag = actionTag
    }
}

/// Protocol that all Mackey AI tools must conform to.
public protocol MackeyTool: Sendable {
    var name: String { get }
    var description: String { get }
    var riskLevel: ActionRiskLevel { get }

    func execute(arguments: [String: Any]) async throws -> ToolResult
}
