//
//  MackyAiApp.swift
//  MackyAi
//
//  Created by Dhiraj Bhawsar on 07/09/26.
//

import SwiftUI

@main
struct MackyAiApp: App {
    @StateObject private var assistantState = AssistantState()

    var body: some Scene {
        // MARK: - Main Assistant Window (Appears on screen on launch)
        WindowGroup("Mackey AI") {
            ContentView(state: assistantState)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 440, height: 620)

        // MARK: - Menu Bar Assistant Popover
        MenuBarExtra("Mackey AI", systemImage: "waveform.circle.fill") {
            MenuBarView(state: assistantState)
        }
        .menuBarExtraStyle(.window)

        // MARK: - Dedicated Settings Window
        Settings {
            SettingsView(state: assistantState)
        }
    }
}
