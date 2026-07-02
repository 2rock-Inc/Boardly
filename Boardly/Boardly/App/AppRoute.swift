import Foundation

enum AppRoute: Hashable {
    case project(id: String, name: String)
    case board(id: String, name: String, projectName: String? = nil, focusCardId: String? = nil)
}
