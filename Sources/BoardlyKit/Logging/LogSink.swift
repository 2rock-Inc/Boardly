import os

// MARK: - SinkEntry

/// The fully-formatted, sanitised record delivered to a log sink.
/// All `Redacted` metadata values have already been replaced with `"<redacted>"`
/// before this type is constructed — the sink never sees raw secrets.
public struct SinkEntry: Sendable {
    public let tag: LogTag
    public let level: LogLevel
    /// User-supplied message, with optional icon prefix already applied.
    public let message: String
    /// Metadata with sensitive values already replaced by `"<redacted>"`.
    public let metadata: [String: String]
    public let errorDescription: String?
    /// Populated only in DEBUG builds; `nil` in release.
    public let file: String?
    public let function: String?
    public let line: Int?
}

// MARK: - Protocol

public protocol LogSink: Sendable {
    func log(_ entry: SinkEntry)
}

// MARK: - OSLogSink (default)

/// Writes to `os.Logger`, one logger per tag/category.
/// Messages are already sanitised (secrets replaced), so we use `.public`
/// interpolation — `privacy: .private` would hide them even from developers
/// reading Console.app, which is the opposite of useful.
public struct OSLogSink: LogSink {
    private let subsystem: String

    public init(subsystem: String = "com.rocquigny.Boardly") {
        self.subsystem = subsystem
    }

    public func log(_ entry: SinkEntry) {
        let logger = Logger(subsystem: subsystem, category: entry.tag.rawValue)
        let text = format(entry)
        switch entry.level {
        case .info: logger.info("\(text, privacy: .public)")
        case .warning: logger.warning("\(text, privacy: .public)")
        case .error: logger.error("\(text, privacy: .public)")
        }
    }

    private func format(_ entry: SinkEntry) -> String {
        var parts: [String] = [entry.message]
        if !entry.metadata.isEmpty {
            let pairs = entry.metadata
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            parts.append("[\(pairs)]")
        }
        if let desc = entry.errorDescription {
            parts.append("error=\"\(desc)\"")
        }
        #if DEBUG
            if let file = entry.file, let fn = entry.function, let line = entry.line {
                parts.append("(\(file):\(line) \(fn))")
            }
        #endif
        return parts.joined(separator: " ")
    }
}
