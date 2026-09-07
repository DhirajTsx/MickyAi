import Foundation
import Security
import os.log

/// Source from which an API key was loaded.
public enum KeySource: String, Sendable {
    case envFile = ".env File"
    case environmentVariable = "Environment Variable"
    case keychain = "macOS Keychain"
    case none = "None"
}

/// A secure interface for managing AI credentials via .env files, ProcessInfo environment variables,
/// and macOS Keychain storage.
nonisolated public final class SecretStore: Sendable {
    nonisolated public static let shared = SecretStore()

    private let service = "com.dhirajbhawsar.MackyAi"
    private let logger = Logger(subsystem: "com.dhirajbhawsar.MackyAi", category: "SecretStore")

    nonisolated public init() {}

    // MARK: - Provider Environment Variable Mappings

    private func environmentVariableNames(for provider: AIProvider) -> [String] {
        switch provider {
        case .gemini:
            return ["GEMINI_API_KEY", "GOOGLE_API_KEY"]
        case .openAI:
            return ["OPENAI_API_KEY"]
        case .claude:
            return ["ANTHROPIC_API_KEY", "CLAUDE_API_KEY"]
        case .localOllama:
            return ["OLLAMA_HOST", "OLLAMA_ENDPOINT"]
        }
    }

    private func accountKey(for provider: AIProvider) -> String {
        return "api_key_\(provider.rawValue.replacingOccurrences(of: " ", with: "_").lowercased())"
    }

    // MARK: - .env File Parser

    /// Searches known locations for a `.env` file and parses key-value pairs.
    private func parseEnvFile() -> [String: String] {
        var envDict: [String: String] = [:]

        let searchPaths: [String] = [
            // Current working directory
            FileManager.default.currentDirectoryPath + "/.env",
            // Known project root
            "/Users/dhirajbhawsar/Desktop/MackyAI/MackyAi/.env",
            // App bundle resource if any
            Bundle.main.bundlePath + "/Contents/Resources/.env"
        ]

        for path in searchPaths {
            guard FileManager.default.fileExists(atPath: path),
                  let content = try? String(contentsOfFile: path, encoding: .utf8) else {
                continue
            }

            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                // Skip empty lines or comments
                if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }

                let parts = trimmed.split(separator: "=", maxSplits: 1).map(String.init)
                if parts.count == 2 {
                    let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    var val = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    // Remove enclosing quotes if present
                    if (val.hasPrefix("\"") && val.hasSuffix("\"")) || (val.hasPrefix("'") && val.hasSuffix("'")) {
                        val = String(val.dropFirst().dropLast())
                    }
                    if !key.isEmpty && !val.isEmpty {
                        envDict[key] = val
                    }
                }
            }

            // Once found and parsed, return results
            if !envDict.isEmpty {
                return envDict
            }
        }

        return envDict
    }

    // MARK: - Key Retrieval with Fallbacks

    /// Returns the source of the API key if present.
    public func getKeySource(for provider: AIProvider) -> KeySource {
        // 1. Check .env file
        let envFileVars = parseEnvFile()
        for envName in environmentVariableNames(for: provider) {
            if let val = envFileVars[envName], !val.isEmpty {
                return .envFile
            }
        }

        // 2. Check ProcessInfo environment variables
        for envName in environmentVariableNames(for: provider) {
            if let val = ProcessInfo.processInfo.environment[envName],
               !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .environmentVariable
            }
        }

        // 3. Check macOS Keychain
        if getKeyFromKeychain(for: provider) != nil {
            return .keychain
        }

        return .none
    }

    /// Retrieves an API key, prioritizing .env file, then process environment, then Keychain.
    public func getKey(for provider: AIProvider) -> String? {
        // 1. Check .env file
        let envFileVars = parseEnvFile()
        for envName in environmentVariableNames(for: provider) {
            if let val = envFileVars[envName], !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return val.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 2. Check ProcessInfo environment variables
        for envName in environmentVariableNames(for: provider) {
            if let val = ProcessInfo.processInfo.environment[envName],
               !val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return val.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 3. Fall back to macOS Keychain
        return getKeyFromKeychain(for: provider)
    }

    public func hasKey(for provider: AIProvider) -> Bool {
        return getKey(for: provider) != nil
    }

    // MARK: - macOS Keychain Operations

    private func getKeyFromKeychain(for provider: AIProvider) -> String? {
        let account = accountKey(for: provider)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
            return nil
        }

        return key
    }

    @discardableResult
    public func saveKey(_ key: String, for provider: AIProvider) -> Bool {
        guard let data = key.data(using: .utf8) else {
            logger.error("Failed to encode secret key to UTF-8 data")
            return false
        }

        let account = accountKey(for: provider)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let checkStatus = SecItemCopyMatching(query as CFDictionary, nil)

        if checkStatus == errSecSuccess {
            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: data
            ]
            let updateStatus = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
            return updateStatus == errSecSuccess
        } else if checkStatus == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock

            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            return addStatus == errSecSuccess
        } else {
            return false
        }
    }

    @discardableResult
    public func deleteKey(for provider: AIProvider) -> Bool {
        let account = accountKey(for: provider)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
