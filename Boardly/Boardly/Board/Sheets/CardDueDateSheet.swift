import BoardlyKit
import SwiftUI

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
                title: "Due Date",
                cancelLabel: "Cancel",
                doneLabel: "Save",
                onCancel: { dismiss() },
                onDone: { save() })
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "calendar").foregroundStyle(Color.accentColor)
                        Text("Add a due date")
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
        .presentationCornerRadius(26)
        .onAppear {
            guard !seeded else { return }
            seeded = true
            let due = boardVM.payload?.card(id: cardId)?.dueDate
            hasDueDate = due != nil
            date = due ?? Date()
        }
    }

    private func save() {
        guard let card = boardVM.payload?.card(id: cardId) else { dismiss(); return }
        let newDue = hasDueDate ? date : nil
        if changed(current: card.dueDate, new: newDue) {
            Task { await boardVM.updateDueDate(card, to: newDue) }
        }
        dismiss()
    }

    /// Avoid a redundant PATCH (and a spurious activity entry) on a no-op save.
    private func changed(current: Date?, new: Date?) -> Bool {
        switch (current, new) {
        case (nil, nil): false
        case (nil, _), (_, nil): true
        case let (a?, b?): abs(a.timeIntervalSince(b)) >= 1
        }
    }
}
