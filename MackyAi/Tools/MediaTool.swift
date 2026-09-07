import AppKit

/// Tool for media playback and song searches (YouTube & Apple Music).
public final class MediaTool: MackeyTool {
    public let name = "media_control"
    public let description = "Controls media playback and song searches. Actions: play_song, play_pause, next_track, previous_track."
    public let riskLevel: ActionRiskLevel = .safe

    public init() {}

    public func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let action = arguments["action"] as? String else {
            return ToolResult(success: false, output: "Missing required argument 'action'.")
        }

        switch action.lowercased() {
        case "play_song", "play":
            guard let song = arguments["song_name"] as? String ?? arguments["query"] as? String, !song.isEmpty else {
                return ToolResult(success: false, output: "Please specify which song you want to play.")
            }
            return playSong(named: song)

        case "play_pause", "toggle_playback":
            return toggleMusicPlayback()

        case "next_track", "next":
            return nextTrack()

        case "previous_track", "previous":
            return previousTrack()

        default:
            return ToolResult(success: false, output: "Unknown media action: \(action).")
        }
    }

    private func playSong(named song: String) -> ToolResult {
        let query = "\(song) song"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.youtube.com/results?search_query=\(encoded)") else {
            return ToolResult(success: false, output: "Could not format song search URL.")
        }

        NSWorkspace.shared.open(url)
        return ToolResult(
            success: true,
            output: "Playing \"\(song)\" on YouTube.",
            actionTag: "Playing \(song)"
        )
    }

    private func toggleMusicPlayback() -> ToolResult {
        let script = """
        tell application "Music"
            playpause
        end tell
        """
        if executeAppleScript(script) {
            return ToolResult(success: true, output: "Toggled music playback.", actionTag: "Play/Pause")
        } else {
            return ToolResult(success: false, output: "Apple Music is not running.")
        }
    }

    private func nextTrack() -> ToolResult {
        let script = """
        tell application "Music"
            next track
        end tell
        """
        if executeAppleScript(script) {
            return ToolResult(success: true, output: "Skipped to next track.", actionTag: "Next Track")
        } else {
            return ToolResult(success: false, output: "Could not skip track.")
        }
    }

    private func previousTrack() -> ToolResult {
        let script = """
        tell application "Music"
            previous track
        end tell
        """
        if executeAppleScript(script) {
            return ToolResult(success: true, output: "Returned to previous track.", actionTag: "Previous Track")
        } else {
            return ToolResult(success: false, output: "Could not return to previous track.")
        }
    }

    private func executeAppleScript(_ source: String) -> Bool {
        guard let script = NSAppleScript(source: source) else { return false }
        var errorDict: NSDictionary?
        script.executeAndReturnError(&errorDict)
        return errorDict == nil
    }
}
