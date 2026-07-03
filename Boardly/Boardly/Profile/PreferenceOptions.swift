import Foundation

/// PLANKA `defaultHomeView` values with their display names (the raw value is the
/// API identifier; `localizedName` is the shown copy).
enum HomeViewOption: String, CaseIterable, Identifiable {
    case grouped = "groupedProjects"
    case grid = "gridProjects"

    var id: String { rawValue }
    var localizedName: LocalizedStringResource {
        switch self {
        case .grouped: "Grouped"
        case .grid: "Grid"
        }
    }

    static func from(_ raw: String?) -> HomeViewOption { HomeViewOption(rawValue: raw ?? "") ?? .grouped }
}

/// PLANKA `defaultEditorMode` values with their display names.
enum EditorModeOption: String, CaseIterable, Identifiable {
    case wysiwyg
    case markup

    var id: String { rawValue }
    /// WYSIWYG / Markdown are proper nouns — rendered verbatim in every locale.
    var localizedName: LocalizedStringResource {
        switch self {
        case .wysiwyg: "WYSIWYG"
        case .markup: "Markdown"
        }
    }

    static func from(_ raw: String?) -> EditorModeOption { EditorModeOption(rawValue: raw ?? "") ?? .wysiwyg }
}
