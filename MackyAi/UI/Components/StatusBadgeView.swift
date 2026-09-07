import SwiftUI

/// A sleek, glowing badge component displaying the assistant's current operational state.
public struct StatusBadgeView: View {
    public let status: AssistantStatus
    @State private var isPulsing = false

    public init(status: AssistantStatus) {
        self.status = status
    }

    public var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing && status.isBusy ? 1.3 : 1.0)
                .opacity(isPulsing && status.isBusy ? 0.6 : 1.0)
                .animation(
                    status.isBusy
                        ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: isPulsing
                )

            Text(status.displayText)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .strokeBorder(status.color.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            isPulsing = true
        }
    }
}
