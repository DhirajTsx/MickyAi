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

        // Try primary model recommended by Google, falling back if 404 is encountered
        let candidateModels = [
            "gemini-3.6-flash",
            "gemini-2.5-flash",
            "gemini-1.5-flash",
            "gemini-2.0-flash"
        ]

        var lastError: Error = AIClientError.invalidResponse

        for model in candidateModels {
            let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
            guard let url = URL(string: endpoint) else { continue }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = httpBody

            do {
                let (data, response) = try await URLSession.shared.data(for: request)

                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AIClientError.networkUnavailable
                }

                if httpResponse.statusCode == 404 {
                    // Model not available on this tier/account, try next candidate
                    let errorText = String(data: data, encoding: .utf8) ?? "HTTP 404"
                    lastError = AIClientError.serverError(statusCode: 404, message: errorText)
                    continue
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
            } catch let err as AIClientError {
                if case .serverError(let code, _) = err, code == 404 {
                    lastError = err
                    continue
                }
                throw err
            } catch {
                lastError = error
                throw error
            }
        }

        throw lastError
    }
}
