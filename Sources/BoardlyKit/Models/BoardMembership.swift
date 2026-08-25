import Foundation

public struct BoardMembership: Codable, Identifiable, Sendable {
    public let id: String
    public let projectId: String
    public let boardId: String
    public let userId: String
    /// `"editor"` or `"viewer"` per the spec. Kept as a `String` rather than an enum
    /// so an unknown value from a newer server decodes instead of throwing — see
    /// `Role`, which maps it and treats anything unrecognised as unrestricted.
    public let role: String
    /// Whether a viewer may comment. Null means "the role's default applies", **not**
    /// "denied" — the spec notes it "applies only to viewers", so editors carry null
    /// while being free to comment.
    public let canComment: Bool?
    /// PLANKA Pro's spelling of the same permission: it drops `canComment` and sends
    /// this instead. Both are null on every membership of both demo instances, so the
    /// role is what actually carries the signal today.
    public let canUseComments: Bool?
    public let createdAt: Date?
    public let updatedAt: Date?

    public enum Role: Sendable {
        case editor
        case viewer
        /// A role this client doesn't know. Treated as unrestricted on purpose: a
        /// newer server inventing a role must not silently lock people out of a
        /// board they can in fact edit.
        case unknown(String)
    }

    public var parsedRole: Role {
        switch role {
        case "editor": .editor
        case "viewer": .viewer
        default: .unknown(role)
        }
    }

    /// Whether this member may comment, resolving the two spellings and the null
    /// default. Only meaningful for viewers; editors always may.
    public var allowsComments: Bool {
        switch parsedRole {
        case .editor, .unknown: true
        case .viewer: canComment ?? canUseComments ?? false
        }
    }
}
