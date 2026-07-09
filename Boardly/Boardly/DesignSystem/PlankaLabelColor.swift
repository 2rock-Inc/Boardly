import SwiftUI

/// PLANKA labels carry a named color (e.g. "berry-red", "lagoon-blue"). The full
/// palette is mapped to our label colors by keyword, with a stable hash fallback
/// so every label renders a consistent, readable chip color.
extension Color {
    init(plankaLabel name: String) {
        let n = name.lowercased()
        let palette: [Color] = [
            .labelRose, .labelBlue, .labelGreen, .labelPurple, .labelTeal, .labelPriority, .boardlyDestructive,
        ]

        func has(_ keys: [String]) -> Bool { keys.contains { n.contains($0) } }

        if has(["orange", "pumpkin", "apricot", "amber", "mustard", "gold", "tangerine", "carrot"]) {
            self = .labelPriority
        } else if has(["red", "berry", "cherry", "crimson", "scarlet"]) {
            self = .boardlyDestructive
        } else if has(["rose", "pink", "salmon", "coral", "tulip", "flamingo"]) {
            self = .labelRose
        } else if has(["blue", "sky", "navy", "ocean", "lagoon", "lagune", "azure"]) {
            self = .labelBlue
        } else if has(["green", "grass", "salad", "pine", "tree", "mint", "lime", "emerald"]) {
            self = .labelGreen
        } else if has(["purple", "violet", "grape", "plum", "lavender", "mauve"]) {
            self = .labelPurple
        } else if has(["teal", "turquoise", "aqua", "cyan"]) {
            self = .labelTeal
        } else {
            // Stable fallback (launch-independent hash, unlike String.hashValue).
            self = palette[boardlyStableHash(name) % palette.count]
        }
    }
}
