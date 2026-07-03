import BoardlyKit
import SwiftUI

struct ListColumnView: View {
    let list: PlankaList
    let cards: [Card]
    let payload: BoardPayload
    let onCardTap: (Card) -> Void
    let onCreateCard: (String) -> Void

    @State private var newCardName = ""
    @State private var isAddingCard = false
    @FocusState private var addFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header — list name + count pill, sitting directly on the paper.
            HStack(spacing: 8) {
                Text(list.name ?? "Untitled")
                    .font(.sans(16, .bold))
                    .foregroundStyle(Color.boardlyInk)
                    .lineLimit(1)
                Text("\(cards.count)")
                    .font(.mono(11, .medium))
                    .foregroundStyle(Color.boardlyTextSecondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Color.boardlySurfaceSecondary, in: Capsule())
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 4)

            // Cards
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(cards) { card in
                        Button { onCardTap(card) } label: {
                            CardRowView(
                                card: card,
                                taskLists: payload.taskLists(for: card),
                                tasks: payload.taskLists(for: card).flatMap { payload.tasks(for: $0) },
                                labels: payload.labels(for: card),
                                members: payload.members(for: card))
                        }
                        .buttonStyle(.plain)
                    }

                    if isAddingCard {
                        TextField("Card title", text: $newCardName)
                            .font(.boardlyBody)
                            .padding(12)
                            .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(Color.accentColor, lineWidth: 1))
                            .focused($addFieldFocused)
                            .onSubmit { submitNewCard() }
                    }
                }
            }
            .frame(maxHeight: 460)

            // Add card
            Button {
                isAddingCard = true
                addFieldFocused = true
            } label: {
                Label("Add a card", systemImage: "plus")
                    .font(.sans(14, .semibold))
                    .foregroundStyle(Color.boardlyTextSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func submitNewCard() {
        let name = newCardName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { onCreateCard(name) }
        newCardName = ""
        isAddingCard = false
    }
}
