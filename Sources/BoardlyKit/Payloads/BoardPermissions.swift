import Foundation

/// What the current user is allowed to do on a board.
///
/// PLANKA refuses forbidden mutations with `E_FORBIDDEN`, so without this the app
/// offers a viewer buttons that fail on tap. Resolving it up front lets the UI stop
/// offering them.
public struct BoardPermissions: Sendable, Equatable {
    public let canEdit: Bool
    public let canComment: Bool

    /// Everything allowed — the default whenever we have no positive evidence of a
    /// restriction. See `BoardPayload.permissions(for:)` for why that direction.
    public static let unrestricted = BoardPermissions(canEdit: true, canComment: true)

    public init(canEdit: Bool, canComment: Bool) {
        self.canEdit = canEdit
        self.canComment = canComment
    }
}

public extension BoardPayload {
    /// Resolve what `userId` may do on this board.
    ///
    /// **Restricts only on positive evidence.** A user with no membership row is
    /// treated as unrestricted, because the board payload doesn't carry the project's
    /// managers: a project manager administers every board in the project without
    /// necessarily being a member of any of them, and an instance admin likewise.
    /// Locking those people out of their own board would be a worse bug than the one
    /// this fixes — so absence of proof is never proof of restriction.
    func permissions(for userId: String?) -> BoardPermissions {
        guard
            let userId,
            let membership = boardMemberships.first(where: { $0.userId == userId })
        else {
            return .unrestricted
        }
        switch membership.parsedRole {
        case .editor, .unknown:
            return .unrestricted
        case .viewer:
            return BoardPermissions(canEdit: false, canComment: membership.allowsComments)
        }
    }
}
