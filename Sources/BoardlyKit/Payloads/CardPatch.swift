import Foundation

public struct CardPatch: Encodable, Sendable {
    public var name: String?
    public var description: String?
    public var listId: String?
    public var position: Double?
    /// Due date to set. Ignored when `clearDueDate` is `true`.
    public var dueDate: Date?
    /// When `true`, the patch sends `dueDate: null` to remove the existing due date.
    public var clearDueDate: Bool

    public init(
        name: String? = nil,
        description: String? = nil,
        listId: String? = nil,
        position: Double? = nil,
        dueDate: Date? = nil,
        clearDueDate: Bool = false
    ) {
        self.name = name
        self.description = description
        self.listId = listId
        self.position = position
        self.dueDate = dueDate
        self.clearDueDate = clearDueDate
    }

    private enum CodingKeys: String, CodingKey {
        case name, description, listId, position, dueDate
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let name { try c.encode(name, forKey: .name) }
        if let description { try c.encode(description, forKey: .description) }
        if let listId { try c.encode(listId, forKey: .listId) }
        if let position { try c.encode(position, forKey: .position) }
        // PLANKA expects an ISO-8601 string, or explicit null to clear.
        // Serialize manually — the plain JSONEncoder used by PlankaClient would
        // otherwise encode Date as a numeric reference-date interval. Reuse the
        // same formatter the decoder uses so encode/decode never desync.
        if clearDueDate {
            try c.encodeNil(forKey: .dueDate)
        } else if let dueDate {
            try c.encode(ISO8601Formatters.fractional.string(from: dueDate), forKey: .dueDate)
        }
    }
}

public struct TaskPatch: Encodable, Sendable {
    public var name: String?
    public var isCompleted: Bool?

    public init(name: String? = nil, isCompleted: Bool? = nil) {
        self.name = name
        self.isCompleted = isCompleted
    }

    // Encodable is synthesized: optional fields encode via encodeIfPresent,
    // so nil properties are omitted from the PATCH body — same result the
    // hand-written encode(to:) produced, without the maintenance burden.
}
