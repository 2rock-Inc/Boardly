import BoardlyKit
import SwiftUI

/// Design 05quinquies — manage a board's custom-field groups: toggle the project's
/// inherited groups on/off, and create/delete board-specific groups and fields.
struct BoardCustomFieldsSheet: View {
    @Bindable var boardVM: BoardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showAddGroup = false
    @State private var newGroupName = ""
    @State private var addFieldGroup: CustomFieldGroup?
    @State private var newFieldName = ""

    /// Board-specific groups (not instances of an inherited base group).
    private var boardOwnGroups: [CustomFieldGroup] {
        (boardVM.payload?.boardCustomFieldGroups() ?? []).filter { $0.baseCustomFieldGroupId == nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Custom Fields", onCancel: { dismiss() }, onDone: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    inheritedSection
                    boardFieldsSection
                }
                .padding(20)
            }
        }
        .background(Color.boardlyBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .task { await boardVM.loadBaseGroups() }
        .alert("New Group", isPresented: $showAddGroup) {
            TextField("Group name", text: $newGroupName)
            Button("Add") {
                let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { Task { await boardVM.addBoardGroup(name: name) } }
                newGroupName = ""
            }
            Button("Cancel", role: .cancel) { newGroupName = "" }
        }
        .alert("New Field", isPresented: Binding(
            get: { addFieldGroup != nil },
            set: { if !$0 { addFieldGroup = nil } }))
        {
            TextField("Field name", text: $newFieldName)
            Button("Add") {
                let name = newFieldName.trimmingCharacters(in: .whitespacesAndNewlines)
                if let group = addFieldGroup, !name.isEmpty {
                    Task { await boardVM.addCustomField(to: group, name: name) }
                }
                newFieldName = ""
                addFieldGroup = nil
            }
            Button("Cancel", role: .cancel) { newFieldName = ""; addFieldGroup = nil }
        }
    }

    // MARK: - Inherited groups

    @ViewBuilder private var inheritedSection: some View {
        if !boardVM.baseGroups.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                BoardlyFieldLabel("Inherited from project")
                ForEach(boardVM.baseGroups, id: \.id) { base in
                    inheritedRow(base)
                }
            }
        }
    }

    private func inheritedRow(_ base: BaseCustomFieldGroup) -> some View {
        let on = boardVM.instance(ofBase: base) != nil
        let count = boardVM.fields(inBaseGroup: base).count
        return Button {
            Task {
                if on { await boardVM.disableBaseGroup(base) }
                else { await boardVM.enableBaseGroup(base) }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(base.name)
                        .font(.sans(15, .semibold))
                        .foregroundStyle(Color.boardlyInk)
                    Text("\(count) field\(count == 1 ? "" : "s")")
                        .font(.boardlyMonoCaption)
                        .foregroundStyle(Color.boardlyTextTertiary)
                }
                Spacer(minLength: 8)
                SelectionToggle(isOn: on)
            }
            .padding(14)
            .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.boardlySeparator, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Board-specific groups

    private var boardFieldsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            BoardlyFieldLabel("Board fields")
            ForEach(boardOwnGroups, id: \.id) { group in
                groupCard(group)
            }
            Button { showAddGroup = true } label: {
                SwiftUI.Label("Add Group", systemImage: "plus")
                    .font(.boardlyCallout)
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        }
    }

    private func groupCard(_ group: CustomFieldGroup) -> some View {
        let fields = boardVM.payload?.fields(in: group) ?? []
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(group.name ?? "Untitled")
                    .font(.sans(15, .semibold))
                    .foregroundStyle(Color.boardlyInk)
                Spacer(minLength: 0)
                Menu {
                    Button { addFieldGroup = group } label: {
                        SwiftUI.Label("Add Field", systemImage: "plus")
                    }
                    Button(role: .destructive) {
                        Task { await boardVM.deleteCustomFieldGroup(group) }
                    } label: {
                        SwiftUI.Label("Delete Group", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(Color.boardlyTextSecondary)
                        .padding(6)
                }
            }
            if fields.isEmpty {
                Text("No fields")
                    .font(.boardlyCallout)
                    .italic()
                    .foregroundStyle(Color.boardlyTextTertiary)
            } else {
                ForEach(fields, id: \.id) { field in
                    HStack(spacing: 8) {
                        Text(field.name)
                            .font(.boardlyCallout)
                            .foregroundStyle(Color.boardlyInk)
                        Spacer(minLength: 0)
                        Button { Task { await boardVM.deleteCustomField(field) } } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(Color.labelRose)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .boardlyCard()
    }
}
