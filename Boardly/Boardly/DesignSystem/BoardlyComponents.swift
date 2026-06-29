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

/// Rounded input surface for text fields.
struct BoardlyFieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.boardlyBody)
            .foregroundStyle(Color.boardlyInk)
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.boardlySeparator, lineWidth: 1)
            )
    }
}

extension View {
    func boardlyField() -> some View { modifier(BoardlyFieldStyle()) }
}

/// Circular initials avatar, colored deterministically from the name.
struct AvatarView: View {
    let name: String
    var size: CGFloat = 28
    var bordered: Bool = true

    private static let palette: [Color] = [.labelRose, .labelBlue, .labelGreen, .labelPurple, .labelTeal]

    private var initials: String {
        let chars = name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init)
        return chars.joined().uppercased()
    }
    private var color: Color {
        Self.palette[abs(name.hashValue) % Self.palette.count]
    }

    var body: some View {
        Text(initials.isEmpty ? "?" : initials)
            .font(.mono(size * 0.34, .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
            .overlay(bordered ? Circle().stroke(Color.boardlySurface, lineWidth: 2) : nil)
    }
}

/// Uppercase mono field label, per the design.
struct BoardlyFieldLabel: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .font(.boardlyMonoLabel)
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.boardlyTextTertiary)
    }
}
