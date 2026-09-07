import AppKit

/// Tool for controlling macOS applications (open, list, activate, quit).
public final class AppControlTool: MackeyTool {
    public let name = "app_control"
    public let description = "Controls macOS applications. Actions: open_app, list_apps, activate_app, quit_app."
    public let riskLevel: ActionRiskLevel = .safe

    public init() {}

    public func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let action = arguments["action"] as? String else {
            return ToolResult(success: false, output: "Missing required argument 'action'.")
        }

        switch action.lowercased() {
        case "open_app", "open":
            guard let appName = arguments["app_name"] as? String, !appName.isEmpty else {
                return ToolResult(success: false, output: "Please specify the name of the application to open.")
            }
            return await openApplication(named: appName)

        case "list_apps", "list_running":
            return listRunningApplications()

        case "activate_app", "activate":
            guard let appName = arguments["app_name"] as? String, !appName.isEmpty else {
                return ToolResult(success: false, output: "Please specify the application name to activate.")
            }
            return activateApplication(named: appName)

        case "quit_app", "quit", "close":
            guard let appName = arguments["app_name"] as? String, !appName.isEmpty else {
                return ToolResult(success: false, output: "Please specify the application name to close.")
            }
            return quitApplication(named: appName)

        default:
            return ToolResult(success: false, output: "Unknown application action: \(action).")
        }
    }

    // MARK: - Open Application

    @MainActor
    private func openApplication(named name: String) async -> ToolResult {
        guard let appURL = findApplicationURL(named: name) else {
            return ToolResult(success: false, output: "Could not find an application named '\(name)' on your Mac.")
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        do {
            try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
            let displayName = appURL.deletingPathExtension().lastPathComponent
            return ToolResult(
                success: true,
                output: "Opened \(displayName).",
                actionTag: "Opened \(displayName)"
            )
        } catch {
            return ToolResult(success: false, output: "Failed to open \(name): \(error.localizedDescription)")
        }
    }

    // MARK: - List Running Applications

    private func listRunningApplications() -> ToolResult {
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { $0.localizedName }
            .sorted()

        if apps.isEmpty {
            return ToolResult(success: true, output: "No visible applications currently running.")
        }

        let appListString = apps.joined(separator: ", ")
        return ToolResult(
            success: true,
            output: "Currently running applications (\(apps.count)): \(appListString).",
            actionTag: "\(apps.count) apps running"
        )
    }

    // MARK: - Activate Application

    private func activateApplication(named name: String) -> ToolResult {
        let lower = name.lowercased()
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.lowercased().contains(lower) == true
        }) else {
            return ToolResult(success: false, output: "'\(name)' is not currently running.")
        }

        if #available(macOS 14.0, *) {
            app.activate()
        } else {
            app.activate(options: .activateIgnoringOtherApps)
        }
        return ToolResult(
            success: true,
            output: "Focused \(app.localizedName ?? name).",
            actionTag: "Focused \(app.localizedName ?? name)"
        )
    }

    // MARK: - Quit Application

    private func quitApplication(named name: String) -> ToolResult {
        let lower = name.lowercased()
        guard let app = NSWorkspace.shared.runningApplications.first(where: {
            $0.localizedName?.lowercased().contains(lower) == true
        }) else {
            return ToolResult(success: false, output: "'\(name)' is not currently running.")
        }

        let appName = app.localizedName ?? name
        let success = app.terminate()
        if success {
            return ToolResult(
                success: true,
                output: "Closed \(appName).",
                actionTag: "Closed \(appName)"
            )
        } else {
            return ToolResult(success: false, output: "Could not close \(appName).")
        }
    }

    // MARK: - Application URL Resolver

    private func findApplicationURL(named name: String) -> URL? {
        let lower = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Common aliases
        let aliases: [String: String] = [
            "vs code": "Visual Studio Code",
            "vscode": "Visual Studio Code",
            "terminal": "Terminal",
            "iterm": "iTerm",
            "chrome": "Google Chrome",
            "safari": "Safari",
            "settings": "System Settings",
            "system preferences": "System Settings",
            "music": "Music",
            "finder": "Finder",
            "notes": "Notes",
            "calendar": "Calendar",
            "calculator": "Calculator",
            "messages": "Messages",
            "mail": "Mail",
            "slack": "Slack",
            "spotify": "Spotify"
        ]

        let searchName = aliases[lower] ?? name

        // 1. Search in standard directories
        let searchDirectories: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
        ]

        let fileManager = FileManager.default

        for dir in searchDirectories {
            guard let enumerator = fileManager.enumerator(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app" {
                    let appBase = fileURL.deletingPathExtension().lastPathComponent
                    if appBase.lowercased() == searchName.lowercased() ||
                       appBase.lowercased().contains(searchName.lowercased()) {
                        return fileURL
                    }
                }
            }
        }

        // 2. Fallback to NSWorkspace resolution
        if let defaultURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.\(searchName.lowercased())") {
            return defaultURL
        }

        return nil
    }
}
