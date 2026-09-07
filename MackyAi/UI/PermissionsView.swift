import SwiftUI

/// View displaying all macOS system permissions required by Mackey AI, their current statuses,
/// reasons why they are needed, and direct actions to grant or configure them in System Settings.
public struct PermissionsView: View {
    @ObservedObject var permissions: PermissionManager = .shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header Banner
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("macOS System Permissions")
                            .font(.system(size: 15, weight: .bold))

                        Text("Mackey AI operates entirely locally and safely. Grant permissions below to enable voice and Mac automation.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: {
                        permissions.checkAllPermissions()
                    }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 4)

                Divider()

                // Permission Cards
                VStack(spacing: 12) {
                    ForEach(PermissionType.allCases) { type in
                        permissionCard(for: type)
                    }
                }
            }
            .padding(16)
        }
        .onAppear {
            permissions.checkAllPermissions()
        }
    }

    @ViewBuilder
    private func permissionCard(for type: PermissionType) -> some View {
        let status = permissions.status(for: type)

        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                // Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(status.statusColor.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: type.systemIcon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(status.statusColor)
                }

                // Name
                VStack(alignment: .leading, spacing: 1) {
                    Text(type.title)
                        .font(.system(size: 13, weight: .semibold))

                    Text(type.whyNeeded)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Status Badge & Action
                HStack(spacing: 8) {
                    HStack(spacing: 4) {
                        Image(systemName: status.statusIcon)
                            .font(.system(size: 11))
                            .foregroundStyle(status.statusColor)

                        Text(status.rawValue)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(status.statusColor)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(status.statusColor.opacity(0.1))
                    )

                    actionButton(for: type, status: status)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
                )
        )
    }

    @ViewBuilder
    private func actionButton(for type: PermissionType, status: PermissionStatus) -> some View {
        switch status {
        case .granted:
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.green)
                .frame(width: 28, height: 28)

        case .notDetermined:
            Button("Grant") {
                requestPermission(for: type)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)

        case .denied:
            Button(action: {
                permissions.openSystemSettings(for: type)
            }) {
                HStack(spacing: 3) {
                    Text("Settings")
                    Image(systemName: "arrow.up.forward.app")
                        .font(.system(size: 9))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .help("Open macOS System Settings to enable this permission")
        }
    }

    private func requestPermission(for type: PermissionType) {
        switch type {
        case .microphone:
            permissions.requestMicrophonePermission()
        case .speechRecognition:
            permissions.requestSpeechRecognitionPermission()
        case .accessibility:
            permissions.requestAccessibilityPermission()
        case .screenRecording:
            permissions.requestScreenRecordingPermission()
        }
    }
}
