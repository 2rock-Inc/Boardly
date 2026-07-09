import BoardlyKit
import SwiftUI
import UIKit

enum BoardViewMode: String, CaseIterable {
    case kanban, list, grid

    var localizedName: LocalizedStringResource {
        switch self {
        case .kanban: "Kanban"
        case .list: "List"
        case .grid: "Grid"
        }
    }
}

/// Thin wrapper that binds a board to its *shared*, ref-counted session. Opening
/// the same board from Projects and Search must not spin up two socket subscriptions
/// — both acquire the one `BoardViewModel` held by `BoardSessionStore` (realtime
/// starts on the first consumer, tears down on the last).
struct BoardView: View {
    let client: PlankaClient
    let boardId: String
    let boardName: String
    let projectName: String?
    /// When set (e.g. arriving from search), the board opens this card once loaded.
    let focusCardId: String?

    @Environment(BoardSessionStore.self) private var sessions
    @State private var lease: BoardSessionLease?

    init(
        client: PlankaClient,
        boardId: String,
        boardName: String,
        projectName: String? = nil,
        focusCardId: String? = nil)
    {
        self.client = client
        self.boardId = boardId
        self.boardName = boardName
        self.projectName = projectName
        self.focusCardId = focusCardId
    }

    var body: some View {
        Group {
            if let lease {
                BoardScreen(
                    viewModel: lease.viewModel,
                    boardName: boardName,
                    projectName: projectName,
                    focusCardId: focusCardId)
            } else {
                ZStack {
                    Color.boardlyBackground.ignoresSafeArea()
                    ProgressView().tint(.accentColor)
                }
                .toolbar(.hidden, for: .navigationBar)
            }
        }
        // Acquire once, on first appearance. The lease is held in @State and only
        // released when this view is destroyed (popped) — NOT on the transient
        // onDisappear a tab switch or a pushed card detail triggers. That keeps the
        // shared session (and its socket) alive across tab round-trips.
        .onAppear {
            if lease == nil {
                lease = BoardSessionLease(boardId: boardId, client: client, store: sessions)
            }
        }
    }
}

/// Holds a board session for as long as a `BoardView` is alive: `init` acquires,
/// `deinit` releases. Because it lives in the view's `@State`, `deinit` runs only
/// when the view is truly torn down (popped off the stack), so a tab switch — which
/// merely fires `onDisappear` — never releases the session.
@MainActor
private final class BoardSessionLease {
    let viewModel: BoardViewModel
    private let boardId: String
    private let store: BoardSessionStore

    init(boardId: String, client: PlankaClient, store: BoardSessionStore) {
        self.boardId = boardId
        self.store = store
        viewModel = store.acquire(boardId: boardId, client: client)
    }

    deinit {
        // deinit is nonisolated — hop back to the main actor to release.
        let store = store
        let boardId = boardId
        Task { @MainActor in store.release(boardId: boardId) }
    }
}

// MARK: - Board screen

private struct BoardScreen: View {
    let viewModel: BoardViewModel
    let boardName: String
    let projectName: String?
    /// When set (e.g. arriving from search), the board opens this card once loaded.
    let focusCardId: String?

    @State private var selectedCardId: SelectedCard?
    @State private var didFocusCard = false
    @State private var mode: BoardViewMode = .kanban
    @State private var showAddCard = false
    @State private var newCardTitle = ""
    @State private var showCustomFieldsSheet = false
    @State private var showFilters = false
    @State private var filter = BoardFilter()
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false
    @State private var exportFile: ExportFile?
    @Environment(\.dismiss) private var dismiss

    /// Live board name — reflects a rename, falling back to the nav-time name.
    private var currentBoardName: String { viewModel.payload?.board.name ?? boardName }

    /// Cards of a list after applying the active filter (members / labels / due).
    private func visibleCards(in list: PlankaList, payload: BoardPayload) -> [Card] {
        payload.cards(for: list).filter { filter.matches($0, in: payload) }
    }

    private let grid = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color.boardlyBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    header
                    viewSelector
                }
                .background(Color.boardlySurface.ignoresSafeArea(edges: .top))
                boardContent
            }

            if viewModel.payload != nil {
                fab
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if viewModel.payload == nil { await viewModel.load() }
            // The view may have been dismissed while the load was in flight; don't
            // resurrect realtime (or open a card) on a board the user already left.
            guard !Task.isCancelled else { return }
            // Deep-open the focused card at most once, and only if it still exists
            // on this board (it may have been deleted/moved since indexing).
            if let focusCardId, !didFocusCard,
               viewModel.payload?.cards.contains(where: { $0.id == focusCardId }) == true
            {
                didFocusCard = true
                selectedCardId = SelectedCard(id: focusCardId)
            }
            // Realtime is owned by the shared session (started on first acquire);
            // this screen only consumes it. Release happens via the view's lease
            // (see BoardView), not here — a tab switch must not tear it down.
        }
        .refreshable { await viewModel.load() }
        .navigationDestination(item: $selectedCardId) { selected in
            CardDetailView(cardId: selected.id, boardVM: viewModel)
        }
        .sheet(isPresented: $showFilters) {
            if let payload = viewModel.payload {
                BoardFiltersSheet(payload: payload, filter: $filter)
            }
        }
        .sheet(isPresented: $showCustomFieldsSheet) {
            BoardCustomFieldsSheet(boardVM: viewModel)
        }
        .alert("New Card", isPresented: $showAddCard) {
            TextField("Card title", text: $newCardTitle)
            Button("Add") { addCardToFirstList() }
            Button("Cancel", role: .cancel) { newCardTitle = "" }
        } message: {
            if let list = viewModel.payload?.sortedLists().first {
                Text("Added to “\(list.name ?? "—")”")
            }
        }
        .alert("Rename board", isPresented: $showRename) {
            TextField("Board name", text: $renameText)
            Button("Save") { Task { await viewModel.renameBoard(to: renameText) } }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Delete board?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) { Task { await viewModel.deleteBoard() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes the board and all its cards.")
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.error != nil },
            set: { if !$0 { viewModel.error = nil } }))
        {
            Button("OK") { viewModel.error = nil }
        } message: {
            Text(viewModel.error ?? "")
        }
        .sheet(item: $exportFile) { file in
            ShareSheet(items: [file.url])
        }
        .onChange(of: viewModel.boardDeleted) { _, deleted in
            if deleted { dismiss() }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.boardlyInk)
            }
            .boardlyTapTarget("Back")
            VStack(alignment: .leading, spacing: 1) {
                Text(currentBoardName)
                    .font(.sans(20, .bold))
                    .foregroundStyle(Color.boardlyInk)
                    .lineLimit(1)
                if let projectName {
                    Text(projectName)
                        .font(.boardlyMonoCaption)
                        .foregroundStyle(Color.boardlyTextSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button { showFilters = true } label: {
                Image(systemName: filter.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease")
                    .foregroundStyle(filter.isActive ? Color.accentColor : Color.boardlyTextSecondary)
            }
            .boardlyTapTarget("Filter and sort")
            Menu {
                Button {
                    renameText = currentBoardName
                    showRename = true
                } label: {
                    Label("Rename board", systemImage: "pencil")
                }
                Button { showCustomFieldsSheet = true } label: {
                    Label("Custom Fields", systemImage: "square.grid.2x2")
                }
                Button {
                    exportFile = ExportFile(csv: viewModel.exportCSV(), name: currentBoardName)
                } label: {
                    Label("Export CSV", systemImage: "square.and.arrow.up")
                }
                Divider()
                Button(role: .destructive) { showDeleteConfirm = true } label: {
                    Label("Delete board", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(Color.boardlyTextSecondary)
            }
            .boardlyTapTarget("Board menu")
        }
        .font(.system(size: 17, weight: .semibold))
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var viewSelector: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(BoardViewMode.allCases, id: \.self) { item in
                    let active = mode == item
                    Text(item.localizedName)
                        .font(.sans(14, .semibold))
                        .foregroundStyle(active ? Color.boardlyInk : Color.boardlyTextSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(active ? Color.boardlySurface : .clear))
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.15)) { mode = item }
                        }
                }
            }
            .padding(4)
            .background(Color.boardlySurfaceSecondary, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Content

    @ViewBuilder
    private var boardContent: some View {
        if let payload = viewModel.payload {
            if payload.sortedLists().isEmpty {
                ContentUnavailableView(
                    "No lists",
                    systemImage: "rectangle.split.3x1",
                    description: Text("Add lists to this board from the web app."))
            } else {
                switch mode {
                case .kanban: kanbanMode(payload)
                case .list: listeMode(payload)
                case .grid: grilleMode(payload)
                }
            }
        } else if let error = viewModel.error {
            ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
        } else {
            ProgressView().tint(.accentColor)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Kanban

    private func kanbanMode(_ payload: BoardPayload) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 16) {
                    ForEach(payload.sortedLists()) { list in
                        ListColumnView(
                            list: list,
                            cards: visibleCards(in: list, payload: payload),
                            payload: payload,
                            onCardTap: { selectedCardId = SelectedCard(id: $0.id) },
                            onCreateCard: { name in
                                Task { await viewModel.createCard(in: list, name: name) }
                            })
                            .frame(width: 280)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    // MARK: Liste

    private func listeMode(_ payload: BoardPayload) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ForEach(payload.sortedLists()) { list in
                    let cards = visibleCards(in: list, payload: payload)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Text(list.name ?? "Untitled")
                                .font(.sans(16, .bold))
                                .foregroundStyle(Color.boardlyInk)
                            Text("\(cards.count)")
                                .font(.mono(11, .medium))
                                .foregroundStyle(Color.boardlyTextSecondary)
                                .padding(.horizontal, 7).padding(.vertical, 2)
                                .background(Color.boardlySurfaceSecondary, in: Capsule())
                            Spacer(minLength: 0)
                        }
                        ForEach(cards) { card in
                            ListModeCardRow(
                                card: card,
                                tasks: payload.taskLists(for: card).flatMap { payload.tasks(for: $0) },
                                onTap: { selectedCardId = SelectedCard(id: card.id) },
                                onToggleTask: { task in Task { await viewModel.toggleTask(task) } })
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: Grille

    private func grilleMode(_ payload: BoardPayload) -> some View {
        ScrollView {
            LazyVGrid(columns: grid, spacing: 12) {
                ForEach(payload.sortedLists()) { list in
                    ForEach(visibleCards(in: list, payload: payload)) { card in
                        Button { selectedCardId = SelectedCard(id: card.id) } label: {
                            CardRowView(
                                card: card,
                                taskLists: payload.taskLists(for: card),
                                tasks: payload.taskLists(for: card).flatMap { payload.tasks(for: $0) },
                                labels: payload.labels(for: card),
                                members: payload.members(for: card))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: - FAB

    private var fab: some View {
        Button {
            newCardTitle = ""
            showAddCard = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.accentColor, in: Circle())
                .shadow(color: Color.accentColor.opacity(0.4), radius: 10, y: 4)
        }
        .accessibilityLabel("Add card")
        .padding(.trailing, 20)
        .padding(.bottom, 20)
    }

    private func addCardToFirstList() {
        let title = newCardTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, let list = viewModel.payload?.sortedLists().first else { return }
        Task { await viewModel.createCard(in: list, name: title) }
        newCardTitle = ""
    }
}

// MARK: - List-mode card row (card + its tasks)

private struct ListModeCardRow: View {
    let card: Card
    let tasks: [PlankaTask]
    let onTap: () -> Void
    let onToggleTask: (PlankaTask) -> Void

    private var completed: Int { tasks.filter(\.isCompleted).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button(action: onTap) {
                HStack(spacing: 10) {
                    Text(card.name)
                        .font(.sans(15, .semibold))
                        .foregroundStyle(Color.boardlyInk)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                    if let due = card.dueDate {
                        Text(due.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.mono(11, .medium))
                            .foregroundStyle(due < Date() ? Color.boardlyDestructive : Color.boardlyTextSecondary)
                    }
                    if !tasks.isEmpty {
                        Text("\(completed)/\(tasks.count)")
                            .font(.mono(11, .medium))
                            .foregroundStyle(Color.boardlyTextSecondary)
                    }
                }
            }
            .buttonStyle(.plain)

            if !tasks.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(tasks) { task in
                        Button { onToggleTask(task) } label: {
                            HStack(spacing: 8) {
                                Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(task.isCompleted ? Color.labelGreen : Color.boardlyTextTertiary)
                                    .font(.system(size: 15))
                                Text(task.name)
                                    .font(.boardlyCallout)
                                    .strikethrough(task.isCompleted)
                                    .foregroundStyle(task.isCompleted ? Color.boardlyTextSecondary : Color.boardlyInk)
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.leading, 2)
            }
        }
        .boardlyCard()
    }
}

private struct SelectedCard: Identifiable, Hashable {
    let id: String
}

/// A CSV export written to a temp file, ready to share.
private struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL

    init(csv: String, name: String) {
        let safe = name.isEmpty ? "board" : name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safe).csv")
        try? Data(csv.utf8).write(to: url)
        self.url = url
    }
}

/// Thin wrapper around `UIActivityViewController` for the system share sheet.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}
