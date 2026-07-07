import BoardlyKit
import SwiftUI

/// Client-side board filter — applied to the visible cards of every list.
struct BoardFilter: Equatable {
    var memberIds: Set<String> = []
    var labelIds: Set<String> = []
    var due: DueFilter?

    enum DueFilter: String, CaseIterable, Identifiable {
        case overdue, hasDue, noDue
        var id: String { rawValue }
        var localizedName: LocalizedStringResource {
            switch self {
            case .overdue: "Overdue"
            case .hasDue: "With due date"
            case .noDue: "No due date"
            }
        }
    }

    var isActive: Bool { !memberIds.isEmpty || !labelIds.isEmpty || due != nil }

    /// Whether a card passes the filter. Empty facets don't constrain; within a
    /// facet a card matches on *any* selected value; facets are combined with AND.
    func matches(_ card: Card, in payload: BoardPayload) -> Bool {
        if !memberIds.isEmpty {
            let cardMembers = Set(payload.members(for: card).map(\.id))
            if cardMembers.isDisjoint(with: memberIds) { return false }
        }
        if !labelIds.isEmpty {
            let cardLabels = Set(payload.labels(for: card).map(\.id))
            if cardLabels.isDisjoint(with: labelIds) { return false }
        }
        switch due {
        case .overdue:
            guard let d = card.dueDate, d < Date(), card.isDueCompleted != true else { return false }
        case .hasDue:
            guard card.dueDate != nil else { return false }
        case .noDue:
            guard card.dueDate == nil else { return false }
        case nil:
            break
        }
        return true
    }
}

/// Bottom-sheet to filter a board's cards by due date, members and labels.
/// Cancel closes without applying; Apply commits the draft.
struct BoardFiltersSheet: View {
    let payload: BoardPayload
    @Binding var filter: BoardFilter
    @Environment(\.dismiss) private var dismiss
    @State private var draft: BoardFilter

    init(payload: BoardPayload, filter: Binding<BoardFilter>) {
        self.payload = payload
        _filter = filter
        _draft = State(initialValue: filter.wrappedValue)
    }

    private var members: [User] { payload.boardMembers() }
    private var labels: [BoardlyKit.Label] {
        payload.labels.sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Filters",
                doneLabel: "Apply",
                onCancel: { dismiss() },
                onDone: { filter = draft; dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    dueSection
                    if !members.isEmpty { membersSection }
                    if !labels.isEmpty { labelsSection }
                    if draft.isActive {
                        Button { draft = BoardFilter() } label: {
                            Text("Clear filters")
                                .font(.boardlyCallout)
                                .foregroundStyle(Color.boardlyDestructive)
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(Color.boardlyBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(26)
    }

    // MARK: - Sections

    private var dueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BoardlyFieldLabel("Due date")
            HStack(spacing: 8) {
                ForEach(BoardFilter.DueFilter.allCases) { option in
                    let active = draft.due == option
                    Button {
                        draft.due = active ? nil : option
                    } label: {
                        Text(option.localizedName)
                            .font(.sans(13, .semibold))
                            .foregroundStyle(active ? .white : Color.boardlyInk)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                active ? Color.accentColor : Color.boardlyNeutralFill,
                                in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                }
            }
        }
    }

    private var membersSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BoardlyFieldLabel("Members")
            VStack(spacing: 0) {
                ForEach(Array(members.enumerated()), id: \.element.id) { index, user in
                    Button {
                        toggle(user.id, in: \.memberIds)
                    } label: {
                        HStack(spacing: 12) {
                            AvatarView(name: user.name, size: 32, bordered: false)
                            Text(verbatim: user.name)
                                .font(.boardlyCallout)
                                .foregroundStyle(Color.boardlyInk)
                            Spacer(minLength: 0)
                            SelectionToggle(isOn: draft.memberIds.contains(user.id))
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < members.count - 1 { Divider() }
                }
            }
            .boardlyCard(padding: 14)
        }
    }

    private var labelsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            BoardlyFieldLabel("Labels")
            VStack(spacing: 0) {
                ForEach(Array(labels.enumerated()), id: \.element.id) { index, label in
                    Button {
                        toggle(label.id, in: \.labelIds)
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color(plankaLabel: label.color))
                                .frame(width: 26, height: 18)
                            Text(verbatim: label.name ?? label.color)
                                .font(.boardlyCallout)
                                .foregroundStyle(Color.boardlyInk)
                            Spacer(minLength: 0)
                            SelectionToggle(isOn: draft.labelIds.contains(label.id))
                        }
                        .padding(.vertical, 10)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if index < labels.count - 1 { Divider() }
                }
            }
            .boardlyCard(padding: 14)
        }
    }

    private func toggle(_ id: String, in keyPath: WritableKeyPath<BoardFilter, Set<String>>) {
        if draft[keyPath: keyPath].contains(id) {
            draft[keyPath: keyPath].remove(id)
        } else {
            draft[keyPath: keyPath].insert(id)
        }
    }
}
