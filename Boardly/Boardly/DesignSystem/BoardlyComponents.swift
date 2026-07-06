import SwiftUI

/// Filled Pine Teal button — the design's primary call to action.
struct BoardlyPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sans(17, .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
    }
}

/// Outlined neutral button — secondary actions (transparent on the paper background).
struct BoardlySecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.sans(17, .semibold))
            .foregroundStyle(Color.boardlyInk)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(.clear, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .stroke(Color.boardlySeparator, lineWidth: 1))
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
            .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
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
                    .stroke(Color.boardlySeparator, lineWidth: 1))
    }
}

extension View {
    func boardlyField() -> some View { modifier(BoardlyFieldStyle()) }
}

extension View {
    /// Guarantees a ≥44pt hit target and a VoiceOver label on an icon-only control
    /// (back chevrons, +, ellipsis, trash, send…). Apply to the `Button`.
    func boardlyTapTarget(_ label: LocalizedStringKey, minSize: CGFloat = 44) -> some View {
        frame(minWidth: minSize, minHeight: minSize)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(label))
    }
}

/// Stable (launch-independent) hash for deterministic color assignment.
/// `String.hashValue` is seeded randomly per process, so it can't be used here.
func boardlyStableHash(_ string: String) -> Int {
    var hash = 5381
    for byte in string.utf8 { hash = (hash &* 33) &+ Int(byte) }
    return abs(hash)
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
        Self.palette[boardlyStableHash(name) % Self.palette.count]
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

/// Bottom-sheet header: Cancel / title / OK, with a grabber.
struct SheetHeader: View {
    let title: LocalizedStringKey
    var cancelLabel: LocalizedStringKey = "Cancel"
    var doneLabel: LocalizedStringKey = "OK"
    let onCancel: () -> Void
    let onDone: () -> Void

    var body: some View {
        HStack {
            Button(cancelLabel, action: onCancel)
                .foregroundStyle(Color.boardlyTextSecondary)
            Spacer()
            Text(title)
                .font(.boardlySheetTitle)
                .foregroundStyle(Color.boardlyInk)
            Spacer()
            Button(doneLabel, action: onDone)
                .font(.sans(16, .bold))
                .foregroundStyle(Color.accentColor)
        }
        .font(.sans(16, .semibold))
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 14)
        .overlay(alignment: .top) {
            Capsule().fill(Color.boardlyGrabber).frame(width: 36, height: 4).padding(.top, 8)
        }
    }
}

/// Selection check used in selection sheets — accent 24 filled + white check,
/// or an empty-ring when off (spec: unchecked ring #D4D0C8).
struct SelectionToggle: View {
    let isOn: Bool
    var body: some View {
        ZStack {
            if isOn {
                Circle().fill(Color.accentColor)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                Circle().strokeBorder(Color.boardlyEmptyRing, lineWidth: 2)
            }
        }
        .frame(width: 24, height: 24)
    }
}

/// Uppercase mono field label, per the design.
struct BoardlyFieldLabel: View {
    private let content: Text
    /// Localized copy (the default). A string literal at the call site is a
    /// `LocalizedStringKey` and is looked up in the catalog.
    init(_ text: LocalizedStringKey) { content = Text(text) }
    /// Non-localized data (e.g. a custom-field group name).
    init(verbatim: String) { content = Text(verbatim: verbatim) }
    var body: some View {
        content
            .font(.boardlyMonoLabel)
            .tracking(1.1) // ≈ .1em at 11pt (spec .1–.14em; was an ad-hoc 1.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.boardlyTextTertiary)
    }
}

/// Neutral chip (count badge, tags) — radius 11.
struct BoardlyChip<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        content
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(Color.boardlyNeutralFill, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

/// Tinted icon tile for settings rows — 30pt, radius 9, teal-fill background.
struct BoardlyIconTile: View {
    let systemName: String
    var tint: Color = .accentColor
    var fill: Color = .boardlyTealFill
    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 30, height: 30)
            .background(fill, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}
