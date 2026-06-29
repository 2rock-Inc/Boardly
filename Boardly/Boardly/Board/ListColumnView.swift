import SwiftUI
import BoardlyKit

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
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(list.name ?? "Untitled")
                    .font(.headline)
                    .lineLimit(1)
                Spacer()
                Text("\(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary, in: Capsule())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Cards — VStack (not lazy) so height is always known at first layout pass
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 8) {
                    ForEach(cards) { card in
                        Button {
                            onCardTap(card)
                        } label: {
                            CardRowView(
                                card: card,
                                taskLists: payload.taskLists(for: card),
                                tasks: payload.taskLists(for: card).flatMap { payload.tasks(for: $0) }
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    // Inline add card
                    if isAddingCard {
                        TextField("Card title", text: $newCardName)
                            .padding(10)
                            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
                            .focused($addFieldFocused)
                            .onSubmit { submitNewCard() }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 400)

            Divider()

            // Add card button
            Button {
                isAddingCard = true
                addFieldFocused = true
            } label: {
                Label("Add card", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
            }
        }
        .background(.background)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func submitNewCard() {
        let name = newCardName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty { onCreateCard(name) }
        newCardName = ""
        isAddingCard = false
    }
}
