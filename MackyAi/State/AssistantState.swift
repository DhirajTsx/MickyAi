import SwiftUI
import Combine

/// Central state manager for the Mackey AI assistant.
@MainActor
public final class AssistantState: ObservableObject {
    @Published public var status: AssistantStatus = .idle
    @Published public var messages: [ChatMessage] = []
    @Published public var inputText: String = ""
    @Published public var selectedProvider: AIProvider = .gemini
    @Published public var isListening: Bool = false

    public let speechRecognizer: SpeechRecognizer
    private let aiOrchestrator: AIOrchestrator
    private let hotKeyManager: GlobalHotKeyManager
    private var currentTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    public init(
        aiOrchestrator: AIOrchestrator? = nil,
        speechRecognizer: SpeechRecognizer? = nil,
        hotKeyManager: GlobalHotKeyManager? = nil
    ) {
        self.aiOrchestrator = aiOrchestrator ?? .shared
        self.speechRecognizer = speechRecognizer ?? .shared
        self.hotKeyManager = hotKeyManager ?? .shared

        // Load persisted provider choice if available
        if let savedProviderRaw = UserDefaults.standard.string(forKey: "selected_ai_provider"),
           let provider = AIProvider(rawValue: savedProviderRaw) {
            self.selectedProvider = provider
        }

        setupVoiceHandlers()
    }

    private func setupVoiceHandlers() {
        // Handle completed speech from microphone
        speechRecognizer.onSpeechCompleted = { [weak self] recognizedText in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isListening = false
                self.send(prompt: recognizedText)
            }
        }

        // Handle global Option+Space hotkey activation
        hotKeyManager.onHotKeyPressed = { [weak self] in
            Task { @MainActor [weak self] in
                self?.toggleListening()
            }
        }

        // Mirror speechRecognizer's transcript to inputText while listening
        speechRecognizer.$transcript
            .receive(on: RunLoop.main)
            .sink { [weak self] text in
                guard let self = self, self.isListening else { return }
                if !text.isEmpty {
                    self.inputText = text
                }
            }
            .store(in: &cancellables)

        // Handle speech recognition / audio permission errors gracefully
        speechRecognizer.$errorMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] errorMsg in
                guard let self = self, let errorMsg = errorMsg, !errorMsg.isEmpty else { return }
                self.isListening = false
                self.status = .error(message: errorMsg)
                let errorBubble = ChatMessage(
                    role: .assistant,
                    content: "⚠️ \(errorMsg)",
                    status: .failed
                )
                self.messages.append(errorBubble)
            }
            .store(in: &cancellables)
    }

    /// Sends a user message and triggers the AI thinking, tool routing, and response pipeline.
    public func sendCurrentMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        send(prompt: text)
    }

    /// Sends an explicit prompt string to the assistant.
    public func send(prompt: String) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Cancel any pending task before starting a new one
        cancelCurrentTask()

        // 1. Append user message
        let userMessage = ChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)

        // 2. Transition state to thinking
        status = .thinking

        // 3. Launch background execution task
        currentTask = Task {
            do {
                let (responseText, actionTag) = try await aiOrchestrator.process(messages: messages)

                if Task.isCancelled {
                    status = .idle
                    return
                }

                if let actionTag = actionTag {
                    status = .executing(action: actionTag)
                    try? await Task.sleep(nanoseconds: 300_000_000)
                }

                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: responseText,
                    actionTag: actionTag
                )
                messages.append(assistantMessage)
                status = .idle
            } catch is CancellationError {
                status = .idle
            } catch {
                let errorMessage = ChatMessage(
                    role: .assistant,
                    content: "An error occurred: \(error.localizedDescription)",
                    status: .failed
                )
                messages.append(errorMessage)
                status = .error(message: error.localizedDescription)
            }
        }
    }

    /// Cancels the currently executing AI or tool task.
    public func cancelCurrentTask() {
        currentTask?.cancel()
        currentTask = nil
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            isListening = false
        }
        if status.isBusy {
            status = .idle
        }
    }

    /// Toggles voice listening on or off using native speech recognition.
    public func toggleListening() {
        if isListening || speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            isListening = false
            status = .idle
        } else {
            cancelCurrentTask()
            isListening = true
            status = .listening
            speechRecognizer.startRecording()
        }
    }

    /// Clears conversation history.
    public func clearHistory() {
        cancelCurrentTask()
        messages.removeAll()
        status = .idle
    }

    /// Updates the selected AI provider and persists the choice.
    public func selectProvider(_ provider: AIProvider) {
        self.selectedProvider = provider
        UserDefaults.standard.set(provider.rawValue, forKey: "selected_ai_provider")
    }

    // MARK: - Status Visual Helpers

    public var statusIconName: String {
        status.iconName
    }

    public var statusColor: Color {
        status.color
    }
}
