import Foundation
import Testing
@testable import BoardlyKit

@Suite("Board permissions")
struct BoardPermissionsTests {
    private func membership(
        user: String,
        role: String,
        canComment: String = "null",
        canUseComments: String? = nil) throws -> BoardMembership
    {
        let pro = canUseComments.map { ",\"canUseComments\":\($0)" } ?? ""
        let json = """
        {"id":"m-\(user)","projectId":"p1","boardId":"b1","userId":"\(user)",
         "role":"\(role)","canComment":\(canComment)\(pro)}
        """
        return try JSONDecoder.planka.decode(BoardMembership.self, from: Data(json.utf8))
    }

    private func payload(_ memberships: [BoardMembership]) throws -> BoardPayload {
        let board = try JSONDecoder.planka.decode(
            Board.self, from: Data(#"{"id":"b1","projectId":"p1","name":"B","position":1}"#.utf8))
        return BoardPayload(
            board: board, lists: [], cards: [], taskLists: [], tasks: [], labels: [],
            cardMemberships: [], cardLabels: [], users: [], boardMemberships: memberships)
    }

    @Test("an editor may do everything")
    func editorUnrestricted() throws {
        let p = try payload([membership(user: "u1", role: "editor")])
        #expect(p.permissions(for: "u1") == .unrestricted)
    }

    @Test("a viewer may not edit, and may not comment by default")
    func viewerRestricted() throws {
        let p = try payload([membership(user: "u1", role: "viewer")])
        #expect(p.permissions(for: "u1") == BoardPermissions(canEdit: false, canComment: false))
    }

    @Test("a viewer with canComment may comment but still may not edit")
    func viewerWithComments() throws {
        let p = try payload([membership(user: "u1", role: "viewer", canComment: "true")])
        #expect(p.permissions(for: "u1") == BoardPermissions(canEdit: false, canComment: true))
    }

    @Test("Pro's canUseComments spelling is honoured too")
    func proSpelling() throws {
        // Pro drops `canComment` entirely and sends `canUseComments` instead.
        let p = try payload([membership(user: "u1", role: "viewer", canUseComments: "true")])
        #expect(p.permissions(for: "u1").canComment)
    }

    @Test("a null permission means the role's default, never denial")
    func nullIsNotDenial() throws {
        // The whole trap: every permission is null on both live instances. If null read
        // as false, an editor would lose the right to comment on their own board.
        let p = try payload([membership(user: "u1", role: "editor", canComment: "null")])
        #expect(p.permissions(for: "u1").canComment)
    }

    @Test("a user with no membership is unrestricted (project managers, admins)")
    func nonMemberUnrestricted() throws {
        // The board payload carries no project managers, so a manager administering
        // this board appears here as a stranger. Restricting them would lock them out.
        let p = try payload([membership(user: "someone-else", role: "editor")])
        #expect(p.permissions(for: "u1") == .unrestricted)
        #expect(p.permissions(for: nil) == .unrestricted)
    }

    @Test("an unknown role from a newer server is unrestricted, not denied")
    func unknownRoleFailsOpen() throws {
        let p = try payload([membership(user: "u1", role: "supervisor")])
        #expect(p.permissions(for: "u1") == .unrestricted)
    }

    @Test("only the current user's own membership decides")
    func picksOwnMembership() throws {
        let p = try payload([
            membership(user: "u1", role: "viewer"),
            membership(user: "u2", role: "editor"),
        ])
        #expect(p.permissions(for: "u1").canEdit == false)
        #expect(p.permissions(for: "u2").canEdit)
    }
}
