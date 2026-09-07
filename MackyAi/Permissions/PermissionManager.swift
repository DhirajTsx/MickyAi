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
            return "Required to interact with open applications, read UI elements, and automate Mac controls."
        case .screenRecording:
            return "Required when you ask Mackey AI to capture screenshots or analyze visible content on screen."
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
    @Published public var screenRecordingStatus: PermissionStatus = .notDetermined

    public init() {
        checkAllPermissions()
    }

    /// Checks the status of all permissions without prompting the user.
    public func checkAllPermissions() {
        checkMicrophonePermission()
        checkSpeechRecognitionPermission()
        checkAccessibilityPermission()
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

    public func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            Task { @MainActor in
                self?.microphoneStatus = granted ? .granted : .denied
            }
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

    public func requestSpeechRecognitionPermission() {
        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            Task { @MainActor in
                switch status {
                case .authorized:
                    self?.speechRecognitionStatus = .granted
                case .denied, .restricted:
                    self?.speechRecognitionStatus = .denied
                case .notDetermined:
                    self?.speechRecognitionStatus = .notDetermined
                @unknown default:
                    self?.speechRecognitionStatus = .notDetermined
                }
            }
        }
    }

    // MARK: - Accessibility Permission

    public func checkAccessibilityPermission() {
        let isTrusted = AXIsProcessTrusted()
        accessibilityStatus = isTrusted ? .granted : .denied
    }

    public func requestAccessibilityPermission() {
        // Prompts system dialog and directs user to System Settings
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let isTrusted = AXIsProcessTrustedWithOptions(options)
        accessibilityStatus = isTrusted ? .granted : .denied
    }

    // MARK: - Screen Recording Permission

    public func checkScreenRecordingPermission() {
        let hasAccess = CGPreflightScreenCaptureAccess()
        screenRecordingStatus = hasAccess ? .granted : .denied
    }

    public func requestScreenRecordingPermission() {
        let hasAccess = CGRequestScreenCaptureAccess()
        screenRecordingStatus = hasAccess ? .granted : .denied
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
