import SwiftUI

/// Compact assistant interface displayed when clicking the menu bar icon.
public struct MenuBarView: View {
    @ObservedObject var state: AssistantState
    @Environment(\.openSettings) private var openSettings
    @State private var showingSettingsSheet: Bool = false

    public init(state: AssistantState) {
        self.state = state
    }

    public var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerBar

            Divider()
                .opacity(0.4)

            // MARK: - Conversation or Welcome Area
            if state.messages.isEmpty {
                welcomeView
            } else {
                conversationView
            }

            Divider()
                .opacity(0.4)

            // MARK: - Input Bar & Footer
            VStack(spacing: 6) {
                InputBarView(state: state)

                footerBar
            }
            .padding(12)
        }
        .frame(width: 420, height: 560)
        .background(.ultraThinMaterial)
        .sheet(isPresented: $showingSettingsSheet) {
            VStack {
                HStack {
                    Spacer()
                    Button("Done") {
                        showingSettingsSheet = false
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                .padding([.top, .trailing], 12)

                SettingsView(state: state)
            }
            .frame(width: 540, height: 460)
        }
    }

    // MARK: - Header Component
    private var headerBar: some View {
        HStack(spacing: 10) {
            // Logo & Title
            HStack(spacing: 6) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)

                Text("Mackey AI")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }

            Spacer()

            // Status Indicator
            StatusBadgeView(status: state.status)

            // Clear conversation button
            if !state.messages.isEmpty {
                Button(action: {
                    state.clearHistory()
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Clear conversation")
            }

            // Permissions button
            Button(action: {
                showingSettingsSheet = true
            }) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 13))
                    .foregroundStyle(PermissionManager.shared.hasEssentialPermissions ? Color.secondary : Color.orange)
            }
            .buttonStyle(.plain)
            .help(PermissionManager.shared.hasEssentialPermissions ? "System Permissions: Configured" : "System Permissions: Setup Required")

            // Settings button
            Button(action: {
                showingSettingsSheet = true
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Open Settings")

            // Quit application button
            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Image(systemName: "power")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Quit Mackey AI")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Welcome View with Suggestions
    private var welcomeView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)

                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 4) {
                Text("How can I help you today?")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))

                Text("Ask anything, or control your Mac with voice & text")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            // Suggestion chips
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    SuggestionChipView(iconName: "play.circle.fill", title: "Play Thenkizhakku") {
                        state.send(prompt: "Mackey, play the song Thenkizhakku")
                    }
                    SuggestionChipView(iconName: "safari.fill", title: "Open Safari") {
                        state.send(prompt: "Open Safari")
                    }
                }

                HStack(spacing: 8) {
                    SuggestionChipView(iconName: "speaker.wave.1.fill", title: "Turn volume down") {
                        state.send(prompt: "Turn the volume down")
                    }
                    SuggestionChipView(iconName: "magnifyingglass", title: "Search YouTube") {
                        state.send(prompt: "Search YouTube for Thenkizhakku")
                    }
                }

                HStack(spacing: 8) {
                    SuggestionChipView(iconName: "camera.fill", title: "Take screenshot") {
                        state.send(prompt: "Take a screenshot")
                    }
                    SuggestionChipView(iconName: "app.badge.fill", title: "What's running?") {
                        state.send(prompt: "What applications are running?")
                    }
                }
            }
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    // MARK: - Active Conversation View
    private var conversationView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(state.messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding(14)
            }
            .onChange(of: state.messages.count) {
                if let lastId = state.messages.last?.id {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Footer Component
    private var footerBar: some View {
        HStack {
            Text("Mackey AI • Background Assistant")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)

            Spacer()

            Text("Return to send")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 4)
    }
}
