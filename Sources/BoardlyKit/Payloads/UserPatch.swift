import Foundation

/// Partial update for `PATCH /users/{id}` — the current user's preferences.
/// Only the set fields are sent. Values are the PLANKA enums:
/// `defaultHomeView` ∈ {gridProjects, groupedProjects};
/// `defaultEditorMode` ∈ {wysiwyg, markup};
/// `defaultProjectsOrder` ∈ {byDefault, alphabetically, byCreationTime}.
public struct UserPatch: Encodable, Sendable {
    public var defaultHomeView: String?
    public var defaultEditorMode: String?
    public var defaultProjectsOrder: String?

    public init(
        defaultHomeView: String? = nil,
        defaultEditorMode: String? = nil,
        defaultProjectsOrder: String? = nil)
    {
        self.defaultHomeView = defaultHomeView
        self.defaultEditorMode = defaultEditorMode
        self.defaultProjectsOrder = defaultProjectsOrder
    }

    // Optional fields synthesize to `encodeIfPresent`, so nil properties are
    // omitted from the PATCH body.
}
