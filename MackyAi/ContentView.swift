import SwiftUI

/// Main window interface for Mackey AI.
public struct ContentView: View {
    @ObservedObject var state: AssistantState

    public init(state: AssistantState) {
        self.state = state
    }

    public var body: some View {
        MenuBarView(state: state)
            .frame(width: 440, height: 600)
            .onAppear {
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
    }
}

#Preview {
    ContentView(state: AssistantState())
}
