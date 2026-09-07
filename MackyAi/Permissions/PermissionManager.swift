import SwiftUI
import Combine
import AVFoundation
import Speech
import ApplicationServices
import CoreGraphics

/// Represents the status of a specific system permission.
public enum PermissionStatus: String, Sendable {
    case granted = "Granted"
    case denied = "Denied"
    case notDetermined = "Not Requested"

    public var isGranted: Bool {
        self == .granted
    }

    public var statusColor: Color {
        switch self {
        case .granted:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        }
    }

    public var statusIcon: String {
        switch self {
        case .granted:
            return "checkmark.circle.fill"
        case .denied:
            return "xmark.circle.fill"
        case .notDetermined:
            return "exclamationmark.circle.fill"
        }
    }
}

/// Types of system permissions required by Mackey AI.
public enum PermissionType: String, CaseIterable, Identifiable, Sendable {
    case microphone = "Microphone"
    case speechRecognition = "Speech Recognition"
    case accessibility = "Accessibility"
    case automation = "Automation"
    case screenRecording = "Screen Recording"

    public var id: String { rawValue }

    public var title: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .microphone:
            return "mic.fill"
        case .speechRecognition:
            return "waveform.badge.mic"
        case .accessibility:
            return "hand.raised.fill"
        case .automation:
            return "command.square.fill"
        case .screenRecording:
            return "camera.viewfinder"
        }
    }

    public var whyNeeded: String {
        switch self {
        case .microphone:
            return "Required to listen to your spoken commands in real-time."
        case .speechRecognition:
            return "Required to convert your voice into structured text commands on your Mac."
        case .accessibility:
            return "Required for global Option+Space hotkey and interacting with Mac controls."
        case .automation:
            return "Required to control Mac applications like Safari, Music, and Finder via AppleEvents."
        case .screenRecording:
            return "Required when you ask Mackey AI to capture screenshots or inspect visible windows."
        }
    }

    public var settingsURLString: String {
        switch self {
        case .microphone:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .speechRecognition:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition"
        case .accessibility:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .automation:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation"
        case .screenRecording:
            return "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
        }
    }
}

/// Central manager that checks, monitors, and requests macOS system permissions.
@MainActor
public final class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()

    @Published public var microphoneStatus: PermissionStatus = .notDetermined
    @Published public var speechRecognitionStatus: PermissionStatus = .notDetermined
    @Published public var accessibilityStatus: PermissionStatus = .notDetermined
    @Published public var automationStatus: PermissionStatus = .notDetermined
    @Published public var screenRecordingStatus: PermissionStatus = .notDetermined

    private var appActiveObserver: NSObjectProtocol?

    public init() {
        checkAllPermissions()

        // Automatically re-check permissions when the app gains focus (e.g. user returns from System Settings)
        appActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.checkAllPermissions()
        }
    }

    deinit {
        if let observer = appActiveObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Checks the status of all permissions without prompting the user.
    public func checkAllPermissions() {
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
        checkAccessibilityPermission()
        checkAutomationPermission()
        checkScreenRecordingPermission()
    }

    public func status(for type: PermissionType) -> PermissionStatus {
        switch type {
        case .microphone:
            return microphoneStatus
        case .speechRecognition:
            return speechRecognitionStatus
        case .accessibility:
            return accessibilityStatus
        case .automation:
            return automationStatus
        case .screenRecording:
            return screenRecordingStatus
        }
    }

    // MARK: - Microphone Permission

    public func checkMicrophonePermission() {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            microphoneStatus = .granted
        case .denied, .restricted:
            microphoneStatus = .denied
        case .notDetermined:
            microphoneStatus = .notDetermined
        @unknown default:
            microphoneStatus = .notDetermined
        }
    }

    @discardableResult
    public func requestMicrophonePermission() async -> Bool {
        checkMicrophonePermission()
        if microphoneStatus == .granted { return true }
        if microphoneStatus == .denied {
            openSystemSettings(for: .microphone)
            return false
        }

        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        microphoneStatus = granted ? .granted : .denied
        return granted
    }

    public func requestMicrophonePermission() {
        Task { @MainActor in
            _ = await self.requestMicrophonePermission()
        }
    }

    // MARK: - Speech Recognition Permission

    public func checkSpeechRecognitionPermission() {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized:
            speechRecognitionStatus = .granted
        case .denied, .restricted:
            speechRecognitionStatus = .denied
        case .notDetermined:
            speechRecognitionStatus = .notDetermined
        @unknown default:
            speechRecognitionStatus = .notDetermined
        }
    }

    @discardableResult
    public func requestSpeechRecognitionPermission() async -> Bool {
        checkSpeechRecognitionPermission()
        if speechRecognitionStatus == .granted { return true }
        if speechRecognitionStatus == .denied {
            openSystemSettings(for: .speechRecognition)
            return false
        }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { [weak self] status in
                Task { @MainActor in
                    let granted = (status == .authorized)
                    self?.speechRecognitionStatus = granted ? .granted : .denied
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    public func requestSpeechRecognitionPermission() {
        Task { @MainActor in
            _ = await self.requestSpeechRecognitionPermission()
        }
    }

    // MARK: - Accessibility Permission

    public func checkAccessibilityPermission() {
        let isTrusted = AXIsProcessTrusted()
        accessibilityStatus = isTrusted ? .granted : .denied
    }

    public func requestAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        accessibilityStatus = isTrusted ? .granted : .denied
        if !isTrusted {
            openSystemSettings(for: .accessibility)
        }
    }

    // MARK: - Automation Permission (AppleEvents)

    public func checkAutomationPermission() {
        let script = "tell application \"System Events\" to return name of current user"
        if let appleScript = NSAppleScript(source: script) {
            var errorDict: NSDictionary?
            _ = appleScript.executeAndReturnError(&errorDict)
            if errorDict == nil {
                automationStatus = .granted
            } else if let errorNumber = errorDict?[NSAppleScript.errorNumber] as? Int, errorNumber == -1743 {
                automationStatus = .denied
            } else {
                automationStatus = .notDetermined
            }
        } else {
            automationStatus = .notDetermined
        }
    }

    public func requestAutomationPermission() {
        let script = "tell application \"System Events\" to return name of current user"
        if let appleScript = NSAppleScript(source: script) {
            var errorDict: NSDictionary?
            _ = appleScript.executeAndReturnError(&errorDict)
            if let errorNumber = errorDict?[NSAppleScript.errorNumber] as? Int, errorNumber == -1743 {
                openSystemSettings(for: .automation)
            }
            checkAutomationPermission()
        }
    }

    // MARK: - Screen Recording Permission

    public func checkScreenRecordingPermission() {
        let hasAccess = CGPreflightScreenCaptureAccess()
        screenRecordingStatus = hasAccess ? .granted : .denied
    }

    public func requestScreenRecordingPermission() {
        let hasAccess = CGRequestScreenCaptureAccess()
        screenRecordingStatus = hasAccess ? .granted : .denied
        if !hasAccess {
            openSystemSettings(for: .screenRecording)
        }
    }

    // MARK: - System Settings Navigation

    /// Opens System Settings directly to the corresponding privacy pane.
    public func openSystemSettings(for type: PermissionType) {
        if let url = URL(string: type.settingsURLString) {
            NSWorkspace.shared.open(url)
        } else if let fallback = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            NSWorkspace.shared.open(fallback)
        }
    }

    /// Returns true if all essential permissions (microphone & speech) are granted.
    public var hasEssentialPermissions: Bool {
        microphoneStatus.isGranted && speechRecognitionStatus.isGranted
    }
}
