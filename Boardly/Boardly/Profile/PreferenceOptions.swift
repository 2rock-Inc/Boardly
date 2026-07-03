import Foundation

/// PLANKA `defaultHomeView` values with their display labels (mirrors the
/// AppTheme pattern so the raw value + label live in one compiler-checked place).
enum HomeViewOption: String, CaseIterable, Identifiable {
    case grouped = "groupedProjects"
    case grid = "gridProjects"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .grouped: "Grouped"
        case .grid: "Grid"
        }
    }

    static func from(_ raw: String?) -> HomeViewOption { HomeViewOption(rawValue: raw ?? "") ?? .grouped }
}

/// PLANKA `defaultEditorMode` values with their display labels.
enum EditorModeOption: String, CaseIterable, Identifiable {
    case wysiwyg
    case markup

    var id: String { rawValue }
    var label: String {
        switch self {
        case .wysiwyg: "WYSIWYG"
        case .markup: "Markdown"
        }
    }

    static func from(_ raw: String?) -> EditorModeOption { EditorModeOption(rawValue: raw ?? "") ?? .wysiwyg }
}
