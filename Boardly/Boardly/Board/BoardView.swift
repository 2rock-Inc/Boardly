import SwiftUI
import BoardlyKit

struct BoardView: View {
    let client: PlankaClient
    let boardId: String
    let boardName: String

    @State private var viewModel: BoardViewModel
    @State private var selectedCardId: SelectedCard?

    init(client: PlankaClient, boardId: String, boardName: String) {
        self.client = client
        self.boardId = boardId
        self.boardName = boardName
        _viewModel = State(initialValue: BoardViewModel(client: client, boardId: boardId))
    }

    var body: some View {
        boardContent
            .navigationTitle(boardName)
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.load() }
            .refreshable { await viewModel.load() }
            .sheet(item: $selectedCardId) { selected in
                NavigationStack {
                    CardDetailView(cardId: selected.id, boardVM: viewModel)
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

    // @ViewBuilder var instead of Group{} — Group with conditional branches
    // behaves like ZStack (centers content); @ViewBuilder var passes layout through.
    @ViewBuilder
    private var boardContent: some View {
        if viewModel.isLoading && viewModel.payload == nil {
            ProgressView("Loading board…")
        } else if let error = viewModel.error {
            ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
        } else if let payload = viewModel.payload {
            boardColumns(payload)
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
            // The ScrollView wraps only the kanban row; a Spacer OUTSIDE (in the
            // VStack) fills the remaining height so the columns stay pinned to top.
            // Putting the Spacer inside the ScrollView doesn't work — the horizontal
            // scroll view floats small content to the vertical centre.
            VStack(alignment: .leading, spacing: 0) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(lists) { list in
                            ListColumnView(
                                list: list,
                                cards: payload.cards(for: list),
                                payload: payload,
                                onCardTap: { card in selectedCardId = SelectedCard(id: card.id) },
                                onCreateCard: { name in
                                    Task { await viewModel.createCard(in: list, name: name) }
                                }
                            )
                            .frame(width: 300)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Color(.systemGroupedBackground))
        }
    }
}

private struct SelectedCard: Identifiable {
    let id: String
}
