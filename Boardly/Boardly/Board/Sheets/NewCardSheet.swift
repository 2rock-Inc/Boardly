import BoardlyKit
import SwiftUI

/// Bottom-sheet to create a card — title + destination list.
struct NewCardSheet: View {
    let lists: [PlankaList]
    let onCreate: (PlankaList, String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedListId: String
    @FocusState private var focused: Bool

    init(lists: [PlankaList], onCreate: @escaping (PlankaList, String) -> Void) {
        self.lists = lists
        self.onCreate = onCreate
        _selectedListId = State(initialValue: lists.first?.id ?? "")
    }

    private var selectedList: PlankaList? { lists.first { $0.id == selectedListId } }
    private var trimmed: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "New Card", doneLabel: "Create", onCancel: { dismiss() }, onDone: {
                guard let list = selectedList, !trimmed.isEmpty else { return }
                onCreate(list, trimmed)
                dismiss()
            })

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    TextField("Card title", text: $title, axis: .vertical)
                        .font(.sans(22, .semibold))
                        .foregroundStyle(Color.boardlyInk)
                        .focused($focused)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        BoardlyFieldLabel("List")
                        Menu {
                            ForEach(lists) { list in
                                Button { selectedListId = list.id } label: { Text(verbatim: list.name ?? "—") }
                            }
                        } label: {
                            HStack {
                                Text(verbatim: selectedList?.name ?? "—")
                                    .foregroundStyle(Color.boardlyInk)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(Color.boardlyTextTertiary)
                            }
                            .boardlyField()
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(Color.boardlyBackground)
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(26)
        .onAppear { focused = true }
    }
}
