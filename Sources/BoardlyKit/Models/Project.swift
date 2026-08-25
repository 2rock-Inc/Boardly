import Foundation

public struct Project: Codable, Identifiable, Sendable {
    public let id: String
    public let ownerProjectManagerId: String?
    public let backgroundImageId: String?
    /// Null on PLANKA Pro's unnamed personal project, whose every field comes back null
    /// but the id, the timestamps and the owner. Both the spec (2.0.1) and PLANKA's own
    /// model declare `name` required, so this is the server outrunning the schema, not a
    /// bad payload: Pro ships a project kind the open-source edition doesn't have.
    /// `ProjectsPayload.listable` filters those out, as PLANKA's own web client does.
    public let name: String?
    public let description: String?
    public let backgroundType: String?
    public let backgroundGradient: String?
    /// Null on that same personal project, despite the spec declaring it required with a
    /// `false` default — read it through `isEffectivelyHidden`.
    public let isHidden: Bool?
    /// Personal flag returned by `GET /projects` — whether the current user
    /// favorited this project. Absent from the base schema, hence optional.
    public let isFavorite: Bool?
    public let createdAt: Date?
    public let updatedAt: Date?

    /// Whether the project is hidden, treating an absent flag as "not hidden" — the
    /// default the spec itself declares.
    public var isEffectivelyHidden: Bool { isHidden ?? false }
}
