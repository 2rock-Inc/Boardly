import Foundation

/// The instance's terms and conditions, as served by `GET /terms`.
///
/// `content` is Markdown authored by whoever runs the server, so it is user data: render
/// it, never localize it. `signature` is what proves *which* text was agreed to — it goes
/// back verbatim in `POST /access-tokens/accept-terms`.
public struct Terms: Codable, Sendable, Equatable {
    /// Optional despite `planka-openapi.json` marking it required: live instances omit it,
    /// and decoding it as non-optional failed the whole request.
    public let type: String?
    public let language: String
    public let content: String
    public let signature: String

    public init(type: String? = nil, language: String, content: String, signature: String) {
        self.type = type
        self.language = language
        self.content = content
        self.signature = signature
    }

    /// Picks which language to ask `GET /terms` for, out of the ones the instance
    /// advertises in `Bootstrap.termsLanguages`.
    ///
    /// Asking for a language the instance does not have does *not* fall back to English:
    /// an instance offering `de-DE` and `en-US` answers a request for `fr-FR` with German.
    /// Nobody should be asked to accept legal terms in a language picked by list order, so
    /// the choice is made here instead: the user's own language, then any regional variant
    /// of it, then English, and only then whatever the instance leads with.
    public static func preferredLanguage(
        available: [String],
        preferred: [String] = Locale.preferredLanguages) -> String?
    {
        guard !available.isEmpty else { return nil }

        if let exact = preferred.lazy
            .compactMap({ p in available.first { $0.caseInsensitiveCompare(p) == .orderedSame } })
            .first
        {
            return exact
        }

        // "fr" should still match "fr-FR", and "fr-CA" should match "fr-FR" over German.
        if let sameLanguage = preferred.lazy
            .compactMap({ p in available.first { matchesLanguage($0, p) } })
            .first
        {
            return sameLanguage
        }

        return available.first { matchesLanguage($0, "en") } ?? available.first
    }

    private static func matchesLanguage(_ tag: String, _ other: String) -> Bool {
        func code(_ value: String) -> String {
            (value.split(separator: "-").first.map(String.init) ?? value).lowercased()
        }
        return code(tag) == code(other)
    }

    /// Marker PLANKA puts between the terms themselves and the confirmation checkboxes
    /// the user is meant to tick.
    private static let confirmationsMarker = "[confirmations]::"

    /// The terms text, without the confirmation block appended to it.
    public var body: String {
        guard let range = content.range(of: Self.confirmationsMarker) else { return content }
        return String(content[content.startIndex ..< range.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The statements the user is agreeing to, one per line — shown next to the accept
    /// control rather than buried at the end of the scroll, and never rendered as the raw
    /// `[confirmations]::` marker.
    public var confirmations: [String] {
        guard let range = content.range(of: Self.confirmationsMarker) else { return [] }
        return content[range.upperBound...]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0 != "---" }
    }
}
