import Foundation

extension BoardPayload {
    private struct Included: Decodable {
        let lists: [PlankaList]?
        let cards: [Card]?
        let taskLists: [TaskList]?
        let tasks: [PlankaTask]?
        let labels: [Label]?
        let cardMemberships: [CardMembership]?
        let cardLabels: [CardLabel]?
        let users: [User]?
        let attachments: [Attachment]?
        let boardMemberships: [BoardMembership]?
    }

    private struct Response: Decodable {
        let item: Board
        let included: Included
    }

    /// Decode a `{ item: Board, included: { … } }` body — the shape returned by
    /// both REST `GET /boards/{id}` and the socket subscribe request.
    static func decode(from data: Data, decoder: JSONDecoder = .planka) throws -> BoardPayload {
        let response = try decoder.decode(Response.self, from: data)
        let inc = response.included
        return BoardPayload(
            board: response.item,
            lists: inc.lists ?? [],
            cards: inc.cards ?? [],
            taskLists: inc.taskLists ?? [],
            tasks: inc.tasks ?? [],
            labels: inc.labels ?? [],
            cardMemberships: inc.cardMemberships ?? [],
            cardLabels: inc.cardLabels ?? [],
            users: inc.users ?? [],
            attachments: inc.attachments ?? [],
            boardMemberships: inc.boardMemberships ?? []
        )
    }
}
