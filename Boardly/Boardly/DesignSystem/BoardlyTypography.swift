import SwiftUI
import CoreText
import UIKit
import BoardlyKit

enum BoardlyFonts {
    static let sans = "Manrope"
    static let mono = "JetBrains Mono"

    /// Register the bundled variable fonts at runtime. The Xcode project uses a
    /// generated Info.plist (no `UIAppFonts`), so registration happens here
    /// instead of via the plist. Call once at app launch.
    static func register() {
        for file in ["Manrope", "JetBrainsMono"] {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf") else {
                BoardlyLog.tag(.ui).icon("⚠️").warning("Bundled font missing", metadata: ["file": file])
                continue
            }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                BoardlyLog.tag(.ui).icon("⚠️").warning("Font registration failed", metadata: ["file": file])
            }
        }
        #if DEBUG
        for family in UIFont.familyNames where family.contains("Manrope") || family.contains("JetBrains") {
            BoardlyLog.tag(.ui).icon("🔤").info("Registered font", metadata: [
                "family": family,
                "names": "\(UIFont.fontNames(forFamilyName: family))",
            ])
        }
        #endif
    }
}

extension Font {
    /// Manrope at an explicit weight, scaling with Dynamic Type relative to `textStyle`.
    static func sans(_ size: CGFloat, _ weight: Font.Weight = .regular,
                     relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom(BoardlyFonts.sans, size: size, relativeTo: textStyle).weight(weight)
    }

    /// JetBrains Mono — used for meta labels, counts and tags.
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular,
                     relativeTo textStyle: Font.TextStyle = .caption) -> Font {
        .custom(BoardlyFonts.mono, size: size, relativeTo: textStyle).weight(weight)
    }
}

// Semantic text styles. Views use these names rather than ad-hoc sizes.
extension Font {
    static let boardlyLargeTitle = sans(34, .heavy, relativeTo: .largeTitle)
    static let boardlyTitle = sans(26, .bold, relativeTo: .title)
    static let boardlyHeadline = sans(18, .semibold, relativeTo: .headline)
    static let boardlyBody = sans(16, .regular, relativeTo: .body)
    static let boardlyCallout = sans(15, .medium, relativeTo: .callout)
    static let boardlySubheadline = sans(14, .medium, relativeTo: .subheadline)
    static let boardlyCaption = sans(12, .semibold, relativeTo: .caption)
    /// Uppercase mono labels / counts / meta.
    static let boardlyMonoLabel = mono(11, .medium, relativeTo: .caption2)
    static let boardlyMonoCaption = mono(12, .regular, relativeTo: .caption)
}
