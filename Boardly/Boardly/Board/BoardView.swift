import SwiftUI
import BoardlyKit

struct BoardView: View {
    let client: PlankaClient
    let boardId: String
    let boardName: String

    @State private var viewModel: BoardViewModel
    @State private var selectedCardId: String?

    init(client: PlankaClient, boardId: String, boardName: String) {
        self.client = client
        self.boardId = boardId
        self.boardName = boardName
        _viewModel = State(initialValue: BoardViewModel(client: client, boardId: boardId))
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.payload == nil {
                ProgressView("Loading board…")
            } else if let error = viewModel.error {
                ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
            } else if let payload = viewModel.payload {
                boardColumns(payload)
            }
        }
        .navigationTitle(boardName)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .sheet(item: $selectedCardId) { cardId in
            NavigationStack {
                CardDetailView(cardId: cardId, boardVM: viewModel)
            }
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }
        )) {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
    }

    @ViewBuilder
    private func boardColumns(_ payload: BoardPayload) -> some View {
        let lists = payload.sortedLists()
        if lists.isEmpty {
            ContentUnavailableView(
                "No Lists",
                systemImage: "rectangle.split.3x1",
                description: Text("Add lists to this board from the web app.")
            )
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(lists) { list in
                        ListColumnView(
                            list: list,
                            cards: payload.cards(for: list),
                            payload: payload,
                            onCardTap: { card in selectedCardId = card.id },
                            onCreateCard: { name in
                                Task { await viewModel.createCard(in: list, name: name) }
                            }
                        )
                        .containerRelativeFrame(.horizontal, count: 1, spacing: 12)
                    }
                }
                .scrollTargetLayout()
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollTargetBehavior(.viewAligned)
            .background(Color(.systemGroupedBackground))
        }
    }
}

extension String: @retroactive Identifiable {
    public var id: String { self }
}
