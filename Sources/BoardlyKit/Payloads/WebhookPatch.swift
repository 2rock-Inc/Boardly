import Foundation

/// Body for creating/updating a webhook. Note the asymmetry with the `Webhook`
/// response model: PLANKA *accepts* `events` / `excludedEvents` as
/// comma-separated strings but *returns* them as arrays. We take arrays here and
/// serialize the comma-joined form the API expects.
public struct WebhookPatch: Encodable, Sendable {
    public var name: String?
    public var url: String?
    public var accessToken: String?
    public var events: [String]?
    public var excludedEvents: [String]?

    public init(
        name: String? = nil,
        url: String? = nil,
        accessToken: String? = nil,
        events: [String]? = nil,
        excludedEvents: [String]? = nil)
    {
        self.name = name
        self.url = url
        self.accessToken = accessToken
        self.events = events
        self.excludedEvents = excludedEvents
    }

    private enum CodingKeys: String, CodingKey {
        case name, url, accessToken, events, excludedEvents
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(url, forKey: .url)
        try c.encodeIfPresent(accessToken, forKey: .accessToken)
        try c.encodeIfPresent(events?.joined(separator: ","), forKey: .events)
        try c.encodeIfPresent(excludedEvents?.joined(separator: ","), forKey: .excludedEvents)
    }
}
