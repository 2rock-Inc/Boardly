/// Wraps a sensitive value so it can never appear in plaintext logs.
///
/// The original value is intentionally discarded at init time — only the
/// string `"<redacted>"` is ever stored or emitted. This makes it
/// structurally impossible for a secret to leak through a log call.
///
/// Usage in log metadata:
/// ```swift
/// BoardlyLog.tag(.auth).info("Logged in", metadata: ["token": Redacted(jwt)])
/// // sink receives: metadata["token"] = "<redacted>"
/// ```
public struct Redacted: CustomStringConvertible, Sendable {
    public init(_ value: Any) {}
    public var description: String { "<redacted>" }
}
