import os

/// Severity level, mapped to a sensible `OSLogType`.
public enum LogLevel: Sendable, Equatable {
    /// Informational — useful but not always shown in Console.app by default.
    case info
    /// Notable condition the developer should investigate; shown by default.
    case warning
    /// Failure that affects the user; always captured by the OS.
    case error

    var osLogType: OSLogType {
        switch self {
        case .info: .info
        case .warning: .default  // OSLog has no "warning"; .default is the right tier
        case .error: .error
        }
    }
}
