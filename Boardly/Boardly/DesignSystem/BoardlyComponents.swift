import SwiftUI

/// Filled Pine Teal pill — the design's primary call to action.
struct BoardlyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sans(16, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.accentColor, in: Capsule())
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Outlined neutral pill — secondary actions.
struct BoardlySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sans(16, .semibold))
            .foregroundStyle(Color.boardlyInk)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.boardlySurface, in: Capsule())
            .overlay(Capsule().stroke(Color.boardlySeparator, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

extension ButtonStyle where Self == BoardlyPrimaryButtonStyle {
    static var boardlyPrimary: BoardlyPrimaryButtonStyle { .init() }
}
extension ButtonStyle where Self == BoardlySecondaryButtonStyle {
    static var boardlySecondary: BoardlySecondaryButtonStyle { .init() }
}

/// Card surface used across the app — rounded, raised off the paper background.
struct BoardlyCard: ViewModifier {
    var padding: CGFloat = 16
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(Color.boardlySeparator, lineWidth: 0.5)
            )
    }
}

extension View {
    func boardlyCard(padding: CGFloat = 16) -> some View { modifier(BoardlyCard(padding: padding)) }
}
