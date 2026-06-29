// MARK: - LogEntry (fluent builder)

/// Intermediate builder returned by `BoardlyLog.tag(_:)`.
/// Call `.icon(_:)` optionally, then terminate with `.info`, `.warning`, or `.error`.
public struct LogEntry: Sendable {
    let tag: LogTag
    private var iconPrefix: String?

    init(tag: LogTag) { self.tag = tag }

    /// Adds a cosmetic emoji/icon prefix to the console message.
    /// Has no effect on the underlying OSLog entry structure.
    public func icon(_ emoji: String) -> LogEntry {
        var copy = self
        copy.iconPrefix = emoji
        return copy
    }

    public func info(
        _ message: String,
        error: (any Error)? = nil,
        metadata: [String: Any]? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        emit(.info, message: message, error: error, metadata: metadata,
             file: file, function: function, line: line)
    }

    public func warning(
        _ message: String,
        error: (any Error)? = nil,
        metadata: [String: Any]? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        emit(.warning, message: message, error: error, metadata: metadata,
             file: file, function: function, line: line)
    }

    public func error(
        _ message: String,
        error: (any Error)? = nil,
        metadata: [String: Any]? = nil,
        file: String = #fileID,
        function: String = #function,
        line: Int = #line
    ) {
        emit(.error, message: message, error: error, metadata: metadata,
             file: file, function: function, line: line)
    }

    // MARK: Private

    private func emit(
        _ level: LogLevel,
        message: String,
        error: (any Error)?,
        metadata: [String: Any]?,
        file: String,
        function: String,
        line: Int
    ) {
        let prefixed = iconPrefix.map { "\($0) \(message)" } ?? message

        // Convert metadata: Redacted → "<redacted>", everything else → String.
        // This conversion happens here, before SinkEntry is constructed, so
        // no raw secret can ever reach a sink implementation.
        let sanitized: [String: String] = (metadata ?? [:]).mapValues { value in
            if let redacted = value as? Redacted {
                return redacted.description
            }
            return "\(value)"
        }

        #if DEBUG
        let fileOpt: String? = file
        let funcOpt: String? = function
        let lineOpt: Int? = line
        #else
        let fileOpt: String? = nil
        let funcOpt: String? = nil
        let lineOpt: Int? = nil
        #endif

        let entry = SinkEntry(
            tag: tag,
            level: level,
            message: prefixed,
            metadata: sanitized,
            errorDescription: error.map { "\($0)" },
            file: fileOpt,
            function: funcOpt,
            line: lineOpt
        )
        BoardlyLog.sink.log(entry)
    }
}

// MARK: - BoardlyLog (namespace)

public enum BoardlyLog {
    // Written only at app startup or test setUp — never from concurrent contexts.
    nonisolated(unsafe) public static var sink: any LogSink = OSLogSink()

    public static func tag(_ tag: LogTag) -> LogEntry {
        LogEntry(tag: tag)
    }
}
