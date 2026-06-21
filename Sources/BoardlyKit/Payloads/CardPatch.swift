import Foundation

public struct CardPatch: Encodable, Sendable {
    public var name: String?
    public var description: String?
    public var listId: String?
    public var position: Double?

    public init(
        name: String? = nil,
        description: String? = nil,
        listId: String? = nil,
        position: Double? = nil
    ) {
        self.name = name
        self.description = description
        self.listId = listId
        self.position = position
    }

    private enum CodingKeys: String, CodingKey {
        case name, description, listId, position
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let name { try c.encode(name, forKey: .name) }
        if let description { try c.encode(description, forKey: .description) }
        if let listId { try c.encode(listId, forKey: .listId) }
        if let position { try c.encode(position, forKey: .position) }
    }
}

public struct TaskPatch: Encodable, Sendable {
    public var name: String?
    public var isCompleted: Bool?

    public init(name: String? = nil, isCompleted: Bool? = nil) {
        self.name = name
        self.isCompleted = isCompleted
    }

    private enum CodingKeys: String, CodingKey {
        case name, isCompleted
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let name { try c.encode(name, forKey: .name) }
        if let isCompleted { try c.encode(isCompleted, forKey: .isCompleted) }
    }
}
