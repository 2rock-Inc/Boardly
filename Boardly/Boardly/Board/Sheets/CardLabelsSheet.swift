import SwiftUI
import BoardlyKit

/// Design 08c — assign/unassign the board's labels to a card, plus create one.
struct CardLabelsSheet: View {
    let cardId: String
    @Bindable var boardVM: BoardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showCreate = false
    @State private var newLabelName = ""

    private var card: Card? { boardVM.payload?.card(id: cardId) }
    private var boardLabels: [BoardlyKit.Label] {
        (boardVM.payload?.labels ?? []).sorted { ($0.position ?? 0) < ($1.position ?? 0) }
    }
    private var assignedIds: Set<String> {
        guard let card, let payload = boardVM.payload else { return [] }
        return Set(payload.labels(for: card).map(\.id))
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Labels", onCancel: { dismiss() }, onDone: { dismiss() })
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(boardLabels) { label in
                        labelRow(label)
                    }
                    Button { showCreate = true } label: {
                        SwiftUI.Label("Create Label", systemImage: "plus")
                            .font(.boardlyCallout)
                            .foregroundStyle(Color.accentColor)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
        }
        .background(Color.boardlyBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .alert("New Label", isPresented: $showCreate) {
            TextField("Name", text: $newLabelName)
            Button("Create") {
                let name = newLabelName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty { Task { await boardVM.createLabel(name: name, color: "lagoon-blue") } }
                newLabelName = ""
            }
            Button("Cancel", role: .cancel) { newLabelName = "" }
        }
    }

    private func labelRow(_ label: BoardlyKit.Label) -> some View {
        let assigned = assignedIds.contains(label.id)
        return Button {
            guard let card else { return }
            Task {
                if assigned { await boardVM.removeLabel(label, from: card) }
                else { await boardVM.addLabel(label, to: card) }
            }
        } label: {
            HStack(spacing: 12) {
                Text(label.name ?? "—")
                    .font(.sans(14, .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(plankaLabel: label.color), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                SelectionToggle(isOn: assigned)
            }
        }
        .buttonStyle(.plain)
    }
}
