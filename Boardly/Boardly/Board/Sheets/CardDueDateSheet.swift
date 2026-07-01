import SwiftUI
import BoardlyKit

/// Design 08b — set or clear a card's due date via a calendar bottom sheet.
struct CardDueDateSheet: View {
    let cardId: String
    @Bindable var boardVM: BoardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var hasDueDate = false
    @State private var date = Date()
    @State private var seeded = false

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: "Échéance",
                cancelLabel: "Annuler",
                doneLabel: "Enregistrer",
                onCancel: { dismiss() },
                onDone: { save() }
            )
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "calendar").foregroundStyle(Color.accentColor)
                        Text("Ajouter une échéance")
                            .font(.boardlyBody)
                            .foregroundStyle(Color.boardlyInk)
                        Spacer()
                        Toggle("", isOn: $hasDueDate).labelsHidden().tint(.accentColor)
                    }
                    .boardlyCard()

                    if hasDueDate {
                        DatePicker("", selection: $date, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.graphical)
                            .tint(.accentColor)
                            .boardlyCard()
                    }
                }
                .padding(20)
            }
        }
        .background(Color.boardlyBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .onAppear {
            guard !seeded else { return }
            seeded = true
            let due = boardVM.payload?.card(id: cardId)?.dueDate
            hasDueDate = due != nil
            date = due ?? Date()
        }
    }

    private func save() {
        let newDue = hasDueDate ? date : nil
        if let card = boardVM.payload?.card(id: cardId) {
            Task { await boardVM.updateDueDate(card, to: newDue) }
        }
        dismiss()
    }
}
