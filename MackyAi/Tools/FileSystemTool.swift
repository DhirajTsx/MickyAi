import AppKit

/// Tool for navigating folders, creating directories, and finding files on macOS.
public final class FileSystemTool: MackeyTool {
    public let name = "filesystem_control"
    public let description = "Controls files and folders. Actions: open_folder, create_folder, find_files."
    public let riskLevel: ActionRiskLevel = .safe

    public init() {}

    public func execute(arguments: [String: Any]) async throws -> ToolResult {
        guard let action = arguments["action"] as? String else {
            return ToolResult(success: false, output: "Missing required argument 'action'.")
        }

        switch action.lowercased() {
        case "open_folder", "open":
            guard let folderName = arguments["folder_name"] as? String ?? arguments["name"] as? String, !folderName.isEmpty else {
                return ToolResult(success: false, output: "Please specify which folder to open (e.g. Downloads, Documents, Desktop).")
            }
            return openFolder(named: folderName)

        case "create_folder":
            guard let folderName = arguments["folder_name"] as? String ?? arguments["name"] as? String, !folderName.isEmpty else {
                return ToolResult(success: false, output: "Please specify the name of the folder to create.")
            }
            let basePath = arguments["path"] as? String
            return createFolder(named: folderName, in: basePath)

        case "find_files", "search":
            guard let query = arguments["query"] as? String, !query.isEmpty else {
                return ToolResult(success: false, output: "Please specify what filename or file type to search for.")
            }
            return findFiles(matching: query)

        default:
            return ToolResult(success: false, output: "Unknown filesystem action: \(action).")
        }
    }

    private func openFolder(named name: String) -> ToolResult {
        let lower = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let fileManager = FileManager.default

        var targetURL: URL?

        switch lower {
        case "downloads", "download":
            targetURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
        case "documents", "document", "docs":
            targetURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        case "desktop":
            targetURL = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
        case "pictures", "photos":
            targetURL = fileManager.urls(for: .picturesDirectory, in: .userDomainMask).first
        case "music":
            targetURL = fileManager.urls(for: .musicDirectory, in: .userDomainMask).first
        case "movies", "videos":
            targetURL = fileManager.urls(for: .moviesDirectory, in: .userDomainMask).first
        case "home":
            targetURL = fileManager.homeDirectoryForCurrentUser
        default:
            // Check if folder exists on Desktop or Documents
            let desktopCandidate = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first?.appendingPathComponent(name)
            let documentsCandidate = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(name)

            if let d = desktopCandidate, fileManager.fileExists(atPath: d.path) {
                targetURL = d
            } else if let docs = documentsCandidate, fileManager.fileExists(atPath: docs.path) {
                targetURL = docs
            }
        }

        guard let url = targetURL else {
            return ToolResult(success: false, output: "Could not locate a folder named '\(name)'.")
        }

        NSWorkspace.shared.open(url)
        return ToolResult(
            success: true,
            output: "Opened \(url.lastPathComponent) in Finder.",
            actionTag: "Opened \(url.lastPathComponent)"
        )
    }

    private func createFolder(named name: String, in basePath: String?) -> ToolResult {
        let fileManager = FileManager.default
        let baseDir: URL

        if let basePath = basePath, !basePath.isEmpty {
            baseDir = URL(fileURLWithPath: basePath)
        } else {
            baseDir = fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first ?? fileManager.homeDirectoryForCurrentUser
        }

        let newFolderURL = baseDir.appendingPathComponent(name)

        if fileManager.fileExists(atPath: newFolderURL.path) {
            return ToolResult(success: true, output: "A folder named '\(name)' already exists at \(newFolderURL.path).")
        }

        do {
            try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: true)
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: newFolderURL.path)
            return ToolResult(
                success: true,
                output: "Created folder '\(name)' on your Desktop.",
                actionTag: "Created '\(name)'"
            )
        } catch {
            return ToolResult(success: false, output: "Failed to create folder: \(error.localizedDescription)")
        }
    }

    private func findFiles(matching query: String) -> ToolResult {
        let fileManager = FileManager.default
        let lowerQuery = query.lowercased()

        let searchDirs = [
            fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first
        ].compactMap { $0 }

        var matches: [String] = []

        for dir in searchDirs {
            guard let enumerator = fileManager.enumerator(
                at: dir,
                includingPropertiesForKeys: nil,
                options: [.skipsSubdirectoryDescendants, .skipsHiddenFiles]
            ) else { continue }

            for case let fileURL as URL in enumerator {
                if fileURL.lastPathComponent.lowercased().contains(lowerQuery) {
                    matches.append(fileURL.lastPathComponent)
                    if matches.count >= 5 { break }
                }
            }
            if matches.count >= 5 { break }
        }

        if matches.isEmpty {
            return ToolResult(success: true, output: "No files found matching \"\(query)\" in Downloads, Documents, or Desktop.")
        } else {
            let list = matches.joined(separator: ", ")
            return ToolResult(
                success: true,
                output: "Found \(matches.count) match(es): \(list).",
                actionTag: "Found \(matches.count) files"
            )
        }
    }
}
