import SwiftUI

/// The 25 named project-background gradients PLANKA supports, approximated as
/// SwiftUI `LinearGradient`s for the background picker and the project hero.
enum PlankaGradient {
    /// PLANKA's gradient names in their canonical order.
    static let names: [String] = [
        "old-lime", "ocean-dive", "tzepesch-style", "jungle-mesh", "strawberry-dust",
        "purple-rose", "sun-scream", "warm-rust", "sky-change", "green-eyes",
        "blue-xchange", "blood-orange", "sour-peel", "green-ninja", "algae-green",
        "coral-reef", "steel-grey", "heat-waves", "velvet-lounge", "purple-rain",
        "blue-steel", "blueish-curve", "prism-light", "green-mist", "red-curtain",
    ]

    /// Approximate two-stop colors for each gradient, keyed by name.
    private static let stops: [String: (String, String)] = [
        "old-lime": ("7B920A", "ADD100"),
        "ocean-dive": ("2E3192", "1BFFFF"),
        "tzepesch-style": ("190A05", "870000"),
        "jungle-mesh": ("334D50", "CBCAA5"),
        "strawberry-dust": ("C04848", "480048"),
        "purple-rose": ("EE9CA7", "FFDDE1"),
        "sun-scream": ("F5AF19", "F12711"),
        "warm-rust": ("E35D5B", "E53935"),
        "sky-change": ("1488CC", "2B32B2"),
        "green-eyes": ("56AB2F", "A8E063"),
        "blue-xchange": ("1A2980", "26D0CE"),
        "blood-orange": ("D38312", "A83279"),
        "sour-peel": ("FD8112", "F9D423"),
        "green-ninja": ("134E5E", "71B280"),
        "algae-green": ("02AAB0", "00CDAC"),
        "coral-reef": ("FF7E5F", "FEB47B"),
        "steel-grey": ("1F1C2C", "928DAB"),
        "heat-waves": ("FF5F6D", "FFC371"),
        "velvet-lounge": ("5F2C82", "49A09D"),
        "purple-rain": ("41295A", "2F0743"),
        "blue-steel": ("4B6CB7", "182848"),
        "blueish-curve": ("2980B9", "6DD5FA"),
        "prism-light": ("DD3E54", "6BE585"),
        "green-mist": ("70E1F5", "FFD194"),
        "red-curtain": ("ED213A", "93291E"),
    ]

    /// The gradient for `name`, or a neutral fallback for an unknown name.
    static func linear(_ name: String) -> LinearGradient {
        let pair = stops[name] ?? ("64748B", "94A3B8")
        return LinearGradient(
            colors: [Color(hex: pair.0), Color(hex: pair.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

extension Color {
    /// Build a color from a 6-digit RGB hex string (no leading `#`).
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
