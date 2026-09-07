import SwiftUI

/// Renders a single conversation bubble for the user or Mackey assistant.
public struct MessageBubbleView: View {
    public let message: ChatMessage

    public init(message: ChatMessage) {
        self.message = message
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .assistant {
                // Assistant Avatar
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 28, height: 28)

                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
            } else {
                Spacer(minLength: 40)
            }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Message Content Card
                Text(message.content)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundStyle(message.role == .user ? .white : .primary)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                message.role == .user
                                    ? AnyShapeStyle(LinearGradient(
                                        colors: [Color.blue, Color.blue.opacity(0.85)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    : AnyShapeStyle(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .strokeBorder(
                                        message.role == .user
                                            ? Color.white.opacity(0.15)
                                            : Color.primary.opacity(0.08),
                                        lineWidth: 1
                                    )
                            )
                    )

                // Optional Action Tag
                if let actionTag = message.actionTag {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                        Text(actionTag)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 4)
                }

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 4)
            }

            if message.role == .user {
                // User Avatar Icon
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 28, height: 28)

                    Image(systemName: "person.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            } else {
                Spacer(minLength: 40)
            }
        }
    }
}
