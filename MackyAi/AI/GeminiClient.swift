import Foundation

/// Real API client for communicating with Google Gemini.
public final class GeminiClient: AIClientProtocol {
    private let apiKeyProvider: @Sendable () -> String?

    public init(apiKeyProvider: (@Sendable () -> String?)? = nil) {
        self.apiKeyProvider = apiKeyProvider ?? { SecretStore.shared.getKey(for: .gemini) }
    }

    public func sendMessage(messages: [ChatMessage]) async throws -> String {
        guard let apiKey = apiKeyProvider(), !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIClientError.missingAPIKey(provider: "Google Gemini")
        }

        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            throw AIClientError.invalidResponse
        }

        // Format Gemini contents payload
        var contentsPayload: [[String: Any]] = []
        for msg in messages {
            let roleStr = (msg.role == .user) ? "user" : "model"
            contentsPayload.append([
                "role": roleStr,
                "parts": [
                    ["text": msg.content]
                ]
            ])
        }

        let systemInstruction: [String: Any] = [
            "parts": [
                ["text": "You are Mackey AI, a personal native macOS desktop assistant. Keep your responses concise, helpful, and natural. You help the user control their Mac, play music, open apps, search the web, and answer questions."]
            ]
        ]

        let requestBody: [String: Any] = [
            "contents": contentsPayload,
            "system_instruction": systemInstruction,
            "generationConfig": [
                "temperature": 0.7,
                "maxOutputTokens": 600
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: requestBody) else {
            throw AIClientError.invalidResponse
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = httpBody

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.networkUnavailable
        }

        if httpResponse.statusCode != 200 {
            let errorText = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw AIClientError.serverError(statusCode: httpResponse.statusCode, message: errorText)
        }

        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIClientError.invalidResponse
        }

        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
