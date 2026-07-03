import BoardlyKit
import SwiftUI

/// Design 08e — edit a card's custom-field values. Values are free text (≤512);
/// clearing a field deletes its value. Changes are saved on Done.
struct CardCustomFieldsSheet: View {
    let cardId: String
    @Bindable var boardVM: BoardViewModel
    @Environment(\.dismiss) private var dismiss

    /// Edited text keyed by "\(groupId):\(fieldId)", seeded from current values.
    @State private var edits: [String: String] = [:]
    @State private var seeded = false

    private var card: Card? { boardVM.payload?.card(id: cardId) }

    private var groups: [CustomFieldGroup] {
        guard let card, let payload = boardVM.payload else { return [] }
        return payload.customFieldGroups(for: card).filter { !payload.fields(in: $0).isEmpty }
    }

    private func fields(in group: CustomFieldGroup) -> [CustomField] {
        boardVM.payload?.fields(in: group) ?? []
    }

    private func key(_ groupId: String, _ fieldId: String) -> String { "\(groupId):\(fieldId)" }

    private func storedValue(_ group: CustomFieldGroup, _ field: CustomField) -> String {
        guard let card, let payload = boardVM.payload else { return "" }
        return payload.value(on: card, group: group, field: field)?.content ?? ""
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Custom Fields", onCancel: { dismiss() }, onDone: { save(); dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(groups) { group in
                        groupSection(group)
                    }
                    Text("Free text · up to 512 characters per field. Clearing a field deletes its value.")
                        .font(.boardlyCaption)
                        .foregroundStyle(Color.boardlyTextTertiary)
                }
                .padding(20)
            }
        }
        .background(Color.boardlyBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .onAppear(perform: seedIfNeeded)
    }

    private func groupSection(_ group: CustomFieldGroup) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            if let name = group.name, !name.isEmpty {
                BoardlyFieldLabel(verbatim: name)
            }
            ForEach(fields(in: group)) { field in
                VStack(alignment: .leading, spacing: 6) {
                    Text(field.name)
                        .font(.sans(14, .semibold))
                        .foregroundStyle(Color.boardlyInk)
                    TextField("Add a value…", text: binding(group: group, field: field))
                        .font(.boardlyBody)
                        .foregroundStyle(Color.boardlyInk)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .stroke(Color.boardlySeparator, lineWidth: 0.5))
                }
            }
        }
    }

    private func binding(group: CustomFieldGroup, field: CustomField) -> Binding<String> {
        let k = key(group.id, field.id)
        return Binding(
            get: { edits[k] ?? storedValue(group, field) },
            set: { edits[k] = String($0.prefix(512)) })
    }

    private func seedIfNeeded() {
        guard !seeded else { return }
        seeded = true
        for group in groups {
            for field in fields(in: group) {
                edits[key(group.id, field.id)] = storedValue(group, field)
            }
        }
    }

    /// Persist only the fields whose text changed: set the new value, or clear it
    /// when emptied.
    private func save() {
        guard let card else { return }
        for group in groups {
            for field in fields(in: group) {
                let k = key(group.id, field.id)
                let new = (edits[k] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let old = storedValue(group, field)
                guard new != old else { continue }
                Task {
                    if new.isEmpty {
                        await boardVM.clearCustomFieldValue(groupId: group.id, fieldId: field.id, card: card)
                    } else {
                        await boardVM.setCustomFieldValue(new, groupId: group.id, fieldId: field.id, card: card)
                    }
                }
            }
        }
    }
}
