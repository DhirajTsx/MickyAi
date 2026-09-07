import SwiftUI

/// Input bar providing text entry, send, cancel, and voice interaction controls.
public struct InputBarView: View {
    @ObservedObject var state: AssistantState
    @FocusState private var isFocused: Bool

    public init(state: AssistantState) {
        self.state = state
    }

    public var body: some View {
        HStack(spacing: 8) {
            // Voice Input Toggle Button
            Button(action: {
                state.toggleListening()
            }) {
                ZStack {
                    Circle()
                        .fill(state.isListening ? Color.red.opacity(0.2) : Color.clear)
                        .frame(width: 32, height: 32)
                        .scaleEffect(state.isListening ? 1.0 + CGFloat(state.speechRecognizer.audioLevel * 0.4) : 1.0)
                        .animation(.easeOut(duration: 0.1), value: state.speechRecognizer.audioLevel)

                    Image(systemName: state.isListening ? "mic.fill" : "mic")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(state.isListening ? .red : .secondary)
                }
            }
            .buttonStyle(.plain)
            .help(state.isListening ? "Listening... Click to stop" : "Start voice input (or press Option+Space)")

            // Text Input Field (reflects spoken words live)
            TextField(state.isListening ? "Listening... (speak now)" : "Ask Mackey to do something...", text: $state.inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($isFocused)
                .onSubmit {
                    if !state.inputText.isEmpty && !state.status.isBusy {
                        state.sendCurrentMessage()
                    }
                }
                .disabled(state.status.isBusy)

            // Dynamic Action Button (Stop when busy/listening, Send when text entered)
            if state.status.isBusy || state.isListening {
                Button(action: {
                    state.cancelCurrentTask()
                }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Cancel")
            } else {
                Button(action: {
                    state.sendCurrentMessage()
                }) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                ? Color.secondary.opacity(0.4)
                                : Color.blue
                        )
                }
                .buttonStyle(.plain)
                .disabled(state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .help("Send command")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            state.isListening
                                ? Color.red.opacity(0.5)
                                : (isFocused ? Color.blue.opacity(0.6) : Color.primary.opacity(0.1)),
                            lineWidth: 1
                        )
                )
        )
    }
}
