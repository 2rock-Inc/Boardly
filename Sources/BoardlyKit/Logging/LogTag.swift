/// Routing tag mapped to an OSLog `category`.
/// Each tag produces a distinct `Logger` instance in Console.app.
public enum LogTag: String, Sendable, Equatable {
    case auth
    case network
    case profile
    case sync
    case board
    case ui
}
