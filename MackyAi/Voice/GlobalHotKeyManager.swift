import AppKit

/// Registers global macOS keyboard shortcuts (Option+Space) to activate Mackey AI from any application.
@MainActor
public final class GlobalHotKeyManager {
    public static let shared = GlobalHotKeyManager()

    private var globalMonitor: Any?
    private var localMonitor: Any?

    public var onHotKeyPressed: (() -> Void)?

    public init() {
        startMonitoring()
    }

    public func startMonitoring() {
        // Option + Space hotkey (Space keycode is 49)
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 49 && event.modifierFlags.contains(.option) {
                Task { @MainActor in
                    self?.triggerHotKey()
                }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 49 && event.modifierFlags.contains(.option) {
                self?.triggerHotKey()
                return nil // consume event
            }
            return event
        }
    }

    public func stopMonitoring() {
        if let gm = globalMonitor {
            NSEvent.removeMonitor(gm)
            globalMonitor = nil
        }
        if let lm = localMonitor {
            NSEvent.removeMonitor(lm)
            localMonitor = nil
        }
    }

    private func triggerHotKey() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        onHotKeyPressed?()
    }
}
