import AppKit

/// Tool for browser navigation, web searches, and YouTube queries.
public final class BrowserTool: MackeyTool {
    public let name = "browser_control"
    public let description = "Controls the web browser. Actions: open_url, search_web, search_youtube, open_youtube."
    public let riskLevel: ActionRiskLevel = .safe

    public init() {}

    public func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let action = arguments["action"] as? String else {
            return ToolResult(success: false, output: "Missing required argument 'action'.")
        }

        switch action.lowercased() {
        case "open_url", "open":
            guard let urlString = arguments["url"] as? String, !urlString.isEmpty else {
                return ToolResult(success: false, output: "Please provide a valid website URL.")
            }
            return openURL(urlString)

        case "search_web", "search":
            guard let query = arguments["query"] as? String, !query.isEmpty else {
                return ToolResult(success: false, output: "Please specify what you would like to search the web for.")
            }
            return searchWeb(query: query)

        case "search_youtube":
            guard let query = arguments["query"] as? String, !query.isEmpty else {
                return ToolResult(success: false, output: "Please specify what you want to search on YouTube.")
            }
            return searchYouTube(query: query)

        case "open_youtube":
            return openURL("https://www.youtube.com")

        default:
            return ToolResult(success: false, output: "Unknown browser action: \(action).")
        }
    }

    private func openURL(_ urlString: String) -> ToolResult {
        var cleanURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanURL.lowercased().hasPrefix("http://") && !cleanURL.lowercased().hasPrefix("https://") {
            cleanURL = "https://" + cleanURL
        }

        guard let url = URL(string: cleanURL) else {
            return ToolResult(success: false, output: "Invalid URL provided: '\(urlString)'.")
        }

        let opened = NSWorkspace.shared.open(url)
        if opened {
            return ToolResult(
                success: true,
                output: "Opened \(cleanURL).",
                actionTag: "Opened website"
            )
        } else {
            return ToolResult(success: false, output: "Failed to open \(cleanURL).")
        }
    }

    private func searchWeb(query: String) -> ToolResult {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.google.com/search?q=\(encoded)") else {
            return ToolResult(success: false, output: "Failed to construct search query.")
        }

        NSWorkspace.shared.open(url)
        return ToolResult(
            success: true,
            output: "Searching the web for: \"\(query)\".",
            actionTag: "Web Search: \(query)"
        )
    }

    private func searchYouTube(query: String) -> ToolResult {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.youtube.com/results?search_query=\(encoded)") else {
            return ToolResult(success: false, output: "Failed to construct YouTube query.")
        }

        NSWorkspace.shared.open(url)
        return ToolResult(
            success: true,
            output: "Searching YouTube for: \"\(query)\".",
            actionTag: "YouTube: \(query)"
        )
    }
}
