import SwiftUI

/// The Boardly app icon (Icon Composer export) reused as an in-app logo, with
/// the standard iOS icon corner rounding. Adapts to light/dark via the asset.
struct BoardlyLogo: View {
    var size: CGFloat = 88

    var body: some View {
        Image("BoardlyLogo")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.2237, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: size * 0.16, y: size * 0.08)
    }
}
