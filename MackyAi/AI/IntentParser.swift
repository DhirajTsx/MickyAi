import Foundation

/// Parsed tool invocation intent from natural language user input.
public struct ToolInvocationIntent: Equatable, Sendable {
    public let toolName: String
    public let arguments: [String: String]

    public init(toolName: String, arguments: [String: String]) {
        self.toolName = toolName
        self.arguments = arguments
    }
}

/// Fast-path deterministic natural language intent parser for instantaneous Mac navigation commands.
public struct IntentParser: Sendable {
    public init() {}

    /// Extracts the original substring after a given case-insensitive prefix.
    private func extractOriginalSuffix(from fullString: String, prefix: String) -> String {
        guard fullString.count >= prefix.count else { return "" }
        let index = fullString.index(fullString.startIndex, offsetBy: prefix.count)
        return String(fullString[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Attempts to parse a direct command intent from the user's spoken or typed prompt.
    public func parseIntent(from prompt: String) -> ToolInvocationIntent? {
        let raw = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        var cleaned = raw.lowercased()
        var workingRaw = raw

        // Strip wake phrases or polite prefixes if present
        let prefixesToStrip = ["mackey,", "mackey", "hey mackey,", "hey mackey", "please", "can you", "could you"]
        for prefix in prefixesToStrip {
            if cleaned.hasPrefix(prefix) {
                workingRaw = extractOriginalSuffix(from: workingRaw, prefix: prefix)
                cleaned = workingRaw.lowercased()
            }
        }

        // 1. YouTube Song & Media Playback
        if cleaned.hasPrefix("play the song ") {
            let song = extractOriginalSuffix(from: workingRaw, prefix: "play the song ")
            return ToolInvocationIntent(toolName: "media_control", arguments: ["action": "play_song", "song_name": song])
        } else if cleaned.hasPrefix("play ") {
            let song = extractOriginalSuffix(from: workingRaw, prefix: "play ")
            return ToolInvocationIntent(toolName: "media_control", arguments: ["action": "play_song", "song_name": song])
        }

        // 2. YouTube Search
        if cleaned.hasPrefix("search youtube for ") {
            let query = extractOriginalSuffix(from: workingRaw, prefix: "search youtube for ")
            return ToolInvocationIntent(toolName: "browser_control", arguments: ["action": "search_youtube", "query": query])
        } else if cleaned == "open youtube" {
            return ToolInvocationIntent(toolName: "browser_control", arguments: ["action": "open_youtube"])
        }

        // 3. Web Search & URLs
        if cleaned.hasPrefix("search the web for ") {
            let query = extractOriginalSuffix(from: workingRaw, prefix: "search the web for ")
            return ToolInvocationIntent(toolName: "browser_control", arguments: ["action": "search_web", "query": query])
        } else if cleaned.hasPrefix("search for ") {
            let query = extractOriginalSuffix(from: workingRaw, prefix: "search for ")
            return ToolInvocationIntent(toolName: "browser_control", arguments: ["action": "search_web", "query": query])
        } else if cleaned.hasPrefix("open website ") || cleaned.hasPrefix("open this website") {
            let site = extractOriginalSuffix(from: workingRaw, prefix: "open website ")
            return ToolInvocationIntent(toolName: "browser_control", arguments: ["action": "open_url", "url": site])
        }

        // 4. System Volume & Audio
        if cleaned.contains("mute my mac") || cleaned == "mute" || cleaned.contains("mute audio") {
            return ToolInvocationIntent(toolName: "system_control", arguments: ["action": "mute"])
        } else if cleaned.contains("unmute my mac") || cleaned == "unmute" {
            return ToolInvocationIntent(toolName: "system_control", arguments: ["action": "unmute"])
        } else if cleaned.contains("turn the volume down") || cleaned.contains("turn volume down") || cleaned.contains("volume down") {
            return ToolInvocationIntent(toolName: "system_control", arguments: ["action": "volume_down"])
        } else if cleaned.contains("turn the volume up") || cleaned.contains("turn volume up") || cleaned.contains("volume up") {
            return ToolInvocationIntent(toolName: "system_control", arguments: ["action": "volume_up"])
        }

        // 5. Screenshot Capture
        if cleaned.contains("take a screenshot") || cleaned == "screenshot" || cleaned.contains("capture screen") {
            return ToolInvocationIntent(toolName: "system_control", arguments: ["action": "take_screenshot"])
        }

        // 6. Running Applications & Status
        if cleaned.contains("what's currently open") || cleaned.contains("what applications are running") || cleaned.contains("what is open") || cleaned.contains("running apps") {
            return ToolInvocationIntent(toolName: "app_control", arguments: ["action": "list_apps"])
        }

        // 7. Folders & File System
        if cleaned == "open downloads" || cleaned == "open my downloads" {
            return ToolInvocationIntent(toolName: "filesystem_control", arguments: ["action": "open_folder", "folder_name": "Downloads"])
        } else if cleaned == "open documents" || cleaned == "open my documents" {
            return ToolInvocationIntent(toolName: "filesystem_control", arguments: ["action": "open_folder", "folder_name": "Documents"])
        } else if cleaned == "open desktop" {
            return ToolInvocationIntent(toolName: "filesystem_control", arguments: ["action": "open_folder", "folder_name": "Desktop"])
        } else if cleaned.hasPrefix("create a folder called ") {
            let name = extractOriginalSuffix(from: workingRaw, prefix: "create a folder called ")
            return ToolInvocationIntent(toolName: "filesystem_control", arguments: ["action": "create_folder", "name": name])
        }

        // 8. Open Application (General)
        if cleaned.hasPrefix("open ") {
            let app = extractOriginalSuffix(from: workingRaw, prefix: "open ")
            return ToolInvocationIntent(toolName: "app_control", arguments: ["action": "open_app", "app_name": app])
        } else if cleaned.hasPrefix("launch ") {
            let app = extractOriginalSuffix(from: workingRaw, prefix: "launch ")
            return ToolInvocationIntent(toolName: "app_control", arguments: ["action": "open_app", "app_name": app])
        } else if cleaned.hasPrefix("close ") || cleaned.hasPrefix("quit ") {
            let app = extractOriginalSuffix(from: workingRaw, prefix: cleaned.hasPrefix("close ") ? "close " : "quit ")
            return ToolInvocationIntent(toolName: "app_control", arguments: ["action": "quit_app", "app_name": app])
        }

        // 9. System Info
        if cleaned.contains("system info") || cleaned.contains("mac info") {
            return ToolInvocationIntent(toolName: "system_control", arguments: ["action": "get_system_info"])
        }

        return nil
    }
}
