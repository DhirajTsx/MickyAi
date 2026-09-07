import Foundation
import AppKit

/// Tool for controlling system audio, screenshots, and reading system info.
public final class SystemTool: MackeyTool {
    public let name = "system_control"
    public let description = "Controls system volume, mute, screen captures, and system information."
    public let riskLevel: ActionRiskLevel = .safe

    public init() {}

    public func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let action = arguments["action"] as? String else {
            return ToolResult(success: false, output: "Missing required argument 'action'.")
        }

        switch action.lowercased() {
        case "set_volume":
            let level = arguments["level"] as? Int ?? 50
            return setVolume(to: max(0, min(100, level)))

        case "volume_up":
            return adjustVolume(by: 10)

        case "volume_down":
            return adjustVolume(by: -10)

        case "mute":
            return setMute(true)

        case "unmute":
            return setMute(false)

        case "get_volume":
            return getVolume()

        case "take_screenshot", "screenshot":
            return takeScreenshot()

        case "get_system_info", "system_info":
            return getSystemInfo()

        default:
            return ToolResult(success: false, output: "Unknown system action: \(action).")
        }
    }

    // MARK: - Volume Controls

    private func setVolume(to level: Int) -> ToolResult {
        let scriptSource = "set volume output volume \(level)"
        if executeAppleScript(scriptSource) != nil {
            return ToolResult(
                success: true,
                output: "Set system volume to \(level)%.",
                actionTag: "Volume: \(level)%"
            )
        } else {
            return ToolResult(success: false, output: "Failed to set volume.")
        }
    }

    private func adjustVolume(by delta: Int) -> ToolResult {
        let scriptSource = """
        set currentVol to output volume of (get volume settings)
        set newVol to currentVol + (\(delta))
        if newVol > 100 then set newVol to 100
        if newVol < 0 then set newVol to 0
        set volume output volume newVol
        return newVol
        """

        if let result = executeAppleScript(scriptSource) {
            let newVol = result.stringValue ?? "\(delta > 0 ? "increased" : "decreased")"
            return ToolResult(
                success: true,
                output: "Volume adjusted to \(newVol)%.",
                actionTag: "Volume: \(newVol)%"
            )
        } else {
            return ToolResult(success: false, output: "Failed to adjust volume.")
        }
    }

    private func setMute(_ mute: Bool) -> ToolResult {
        let scriptSource = "set volume output muted \(mute)"
        if executeAppleScript(scriptSource) != nil {
            let statusText = mute ? "Muted" : "Unmuted"
            return ToolResult(
                success: true,
                output: "\(statusText) system audio.",
                actionTag: statusText
            )
        } else {
            return ToolResult(success: false, output: "Failed to change mute state.")
        }
    }

    private func getVolume() -> ToolResult {
        let scriptSource = "output volume of (get volume settings)"
        if let result = executeAppleScript(scriptSource), let vol = result.stringValue {
            return ToolResult(success: true, output: "Current volume is \(vol)%.")
        } else {
            return ToolResult(success: false, output: "Could not read system volume.")
        }
    }

    // MARK: - Screenshot Capture

    private func takeScreenshot() -> ToolResult {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())

        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "/tmp")
        let filename = "Screenshot_\(timestamp).png"
        let fileURL = desktopURL.appendingPathComponent(filename)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", fileURL.path] // -x: do not play sound

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus == 0 {
                return ToolResult(
                    success: true,
                    output: "Screenshot saved to your Desktop as \(filename).",
                    actionTag: "Captured screenshot"
                )
            } else {
                return ToolResult(success: false, output: "Screenshot capture failed with code \(process.terminationStatus).")
            }
        } catch {
            return ToolResult(success: false, output: "Error taking screenshot: \(error.localizedDescription)")
        }
    }

    // MARK: - System Info

    private func getSystemInfo() -> ToolResult {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let hostName = Host.current().localizedName ?? "Mac"
        let memoryGB = ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024)

        let summary = "Machine: \(hostName) | macOS: \(osVersion) | RAM: \(memoryGB) GB"
        return ToolResult(success: true, output: summary, actionTag: "System Info")
    }

    // MARK: - Helper

    @discardableResult
    private func executeAppleScript(_ source: String) -> NSAppleEventDescriptor? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var errorDict: NSDictionary?
        let result = script.executeAndReturnError(&errorDict)
        if errorDict != nil {
            return nil
        }
        return result
    }
}
