import Foundation

// MARK: - Partial records

// Real-time updates may carry only the changed fields (e.g. a reposition emits
// `{ item: { id, position } }`), so every field but `id` is optional. These are
// merged onto the existing record during reconciliation.

public struct PartialCard: Decodable, Sendable {
    public let id: String
    public let boardId: String?
    public let listId: String?
    public let creatorUserId: String?
    public let prevListId: String?
    public let coverAttachmentId: String?
    public let type: String?
    public let position: Double?
    public let name: String?
    public let description: String?
    public let dueDate: Date?
    public let isDueCompleted: Bool?
    public let stopwatch: AnyCodable?
    public let commentsTotal: Int?
    public let isClosed: Bool?
    public let listChangedAt: Date?
    public let createdAt: Date?
    public let updatedAt: Date?
}

public struct PartialList: Decodable, Sendable {
    public let id: String
    public let boardId: String?
    public let type: String?
    public let position: Double?
    public let name: String?
    public let color: String?
    public let createdAt: Date?
    public let updatedAt: Date?
}

public struct PartialTask: Decodable, Sendable {
    public let id: String
    public let taskListId: String?
    public let linkedCardId: String?
    public let assigneeUserId: String?
    public let position: Double?
    public let name: String?
    public let isCompleted: Bool?
    public let createdAt: Date?
    public let updatedAt: Date?
}

public struct PartialTaskList: Decodable, Sendable {
    public let id: String
    public let cardId: String?
    public let position: Double?
    public let name: String?
    public let showOnFrontOfCard: Bool?
    public let hideCompletedTasks: Bool?
    public let createdAt: Date?
    public let updatedAt: Date?
}

// MARK: - Realtime events

/// A typed PLANKA board event, parsed from the socket. `resynced` carries a full
/// fresh payload (emitted after a (re)subscribe) and replaces local state.
public enum BoardRealtimeEvent: Sendable {
    case resynced(BoardPayload)
    case cardCreated(Card)
    case cardUpdated(PartialCard)
    case cardDeleted(id: String)
    case listCreated(PlankaList)
    case listUpdated(PartialList)
    case listDeleted(id: String)
    case taskListCreated(TaskList)
    case taskListUpdated(PartialTaskList)
    case taskListDeleted(id: String)
    case taskCreated(PlankaTask)
    case taskUpdated(PartialTask)
    case taskDeleted(id: String)
    case labelCreated(Label)
    case labelUpdated(Label)
    case labelDeleted(id: String)
    case cardLabelCreated(CardLabel)
    case cardLabelDeleted(id: String)
    case cardMembershipCreated(CardMembership)
    case cardMembershipDeleted(id: String)
    case attachmentCreated(Attachment)
    case attachmentUpdated(Attachment)
    case attachmentDeleted(id: String)
    case customFieldGroupCreated(CustomFieldGroup)
    case customFieldGroupUpdated(CustomFieldGroup)
    case customFieldGroupDeleted(id: String)
    case customFieldCreated(CustomField)
    case customFieldUpdated(CustomField)
    case customFieldDeleted(id: String)
    // PLANKA has no `customFieldValueCreate`: setting a value is an upsert that
    // broadcasts `customFieldValueUpdate` even on first set (see reconciler).
    case customFieldValueUpdated(CustomFieldValue)
    case customFieldValueDeleted(id: String)
}

public extension BoardRealtimeEvent {
    /// PLANKA socket event names this client reconciles into local state.
    static let handledNames: Set<String> = [
        "cardCreate", "cardUpdate", "cardDelete",
        "listCreate", "listUpdate", "listDelete",
        "taskListCreate", "taskListUpdate", "taskListDelete",
        "taskCreate", "taskUpdate", "taskDelete",
        "labelCreate", "labelUpdate", "labelDelete",
        "cardLabelCreate", "cardLabelDelete",
        "cardMembershipCreate", "cardMembershipDelete",
        "attachmentCreate", "attachmentUpdate", "attachmentDelete",
        // Phase 7 custom fields. Confirmed against PLANKA's own event names
        // (server/api/models/Webhook.js). Note: values have no `Create` event —
        // setting a value is an upsert broadcast as `customFieldValueUpdate`.
        "customFieldGroupCreate", "customFieldGroupUpdate", "customFieldGroupDelete",
        "customFieldCreate", "customFieldUpdate", "customFieldDelete",
        "customFieldValueUpdate", "customFieldValueDelete",
    ]

    /// Parse a PLANKA socket event from its name and the JSON of its `{ item: … }`
    /// payload. Returns nil for unhandled events or malformed payloads.
    static func parse(event name: String, payload data: Data) -> BoardRealtimeEvent? {
        let decoder = JSONDecoder.planka
        struct Wrap<U: Decodable>: Decodable { let item: U }
        struct IDWrap: Decodable { struct Item: Decodable { let id: String }; let item: Item }

        func item<T: Decodable>(_: T.Type) -> T? {
            (try? decoder.decode(Wrap<T>.self, from: data))?.item
        }
        func id() -> String? {
            (try? decoder.decode(IDWrap.self, from: data))?.item.id
        }

        switch name {
        case "cardCreate": return item(Card.self).map(BoardRealtimeEvent.cardCreated)
        case "cardUpdate": return item(PartialCard.self).map(BoardRealtimeEvent.cardUpdated)
        case "cardDelete": return id().map { .cardDeleted(id: $0) }
        case "listCreate": return item(PlankaList.self).map(BoardRealtimeEvent.listCreated)
        case "listUpdate": return item(PartialList.self).map(BoardRealtimeEvent.listUpdated)
        case "listDelete": return id().map { .listDeleted(id: $0) }
        case "taskListCreate": return item(TaskList.self).map(BoardRealtimeEvent.taskListCreated)
        case "taskListUpdate": return item(PartialTaskList.self).map(BoardRealtimeEvent.taskListUpdated)
        case "taskListDelete": return id().map { .taskListDeleted(id: $0) }
        case "taskCreate": return item(PlankaTask.self).map(BoardRealtimeEvent.taskCreated)
        case "taskUpdate": return item(PartialTask.self).map(BoardRealtimeEvent.taskUpdated)
        case "taskDelete": return id().map { .taskDeleted(id: $0) }
        case "labelCreate": return item(Label.self).map(BoardRealtimeEvent.labelCreated)
        case "labelUpdate": return item(Label.self).map(BoardRealtimeEvent.labelUpdated)
        case "labelDelete": return id().map { .labelDeleted(id: $0) }
        case "cardLabelCreate": return item(CardLabel.self).map(BoardRealtimeEvent.cardLabelCreated)
        case "cardLabelDelete": return id().map { .cardLabelDeleted(id: $0) }
        case "cardMembershipCreate": return item(CardMembership.self).map(BoardRealtimeEvent.cardMembershipCreated)
        case "cardMembershipDelete": return id().map { .cardMembershipDeleted(id: $0) }
        case "attachmentCreate": return item(Attachment.self).map(BoardRealtimeEvent.attachmentCreated)
        case "attachmentUpdate": return item(Attachment.self).map(BoardRealtimeEvent.attachmentUpdated)
        case "attachmentDelete": return id().map { .attachmentDeleted(id: $0) }
        case "customFieldGroupCreate": return item(CustomFieldGroup.self).map(BoardRealtimeEvent.customFieldGroupCreated)
        case "customFieldGroupUpdate": return item(CustomFieldGroup.self).map(BoardRealtimeEvent.customFieldGroupUpdated)
        case "customFieldGroupDelete": return id().map { .customFieldGroupDeleted(id: $0) }
        case "customFieldCreate": return item(CustomField.self).map(BoardRealtimeEvent.customFieldCreated)
        case "customFieldUpdate": return item(CustomField.self).map(BoardRealtimeEvent.customFieldUpdated)
        case "customFieldDelete": return id().map { .customFieldDeleted(id: $0) }
        case "customFieldValueUpdate": return item(CustomFieldValue.self).map(BoardRealtimeEvent.customFieldValueUpdated)
        case "customFieldValueDelete": return id().map { .customFieldValueDeleted(id: $0) }
        default: return nil
        }
    }
}
