import SwiftUI

/// An interactive chip representing an example prompt or quick command.
public struct SuggestionChipView: View {
    public let iconName: String
    public let title: String
    public let action: () -> Void

    public init(iconName: String, title: String, action: @escaping () -> Void) {
        self.iconName = iconName
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 11))
                    .foregroundStyle(.blue)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .strokeBorder(Color.primary.opacity(0.1), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
