import SwiftUI

/// App-local appearance preference (not a PLANKA setting). Persisted in
/// UserDefaults under `boardly.appearance` and applied at the app root.
enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    static let storageKey = "boardly.appearance"
}
