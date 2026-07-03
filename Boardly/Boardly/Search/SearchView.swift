import BoardlyKit
import SwiftUI

struct SearchView: View {
    let client: PlankaClient
    let initialQuery: String
    @State private var viewModel: SearchViewModel
    @State private var path: [AppRoute] = []

    init(client: PlankaClient, initialQuery: String = "") {
        self.client = client
        self.initialQuery = initialQuery
        _viewModel = State(initialValue: SearchViewModel(client: client))
    }

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationStack(path: $path) {
            ZStack {
                Color.boardlyBackground.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 16) {
                    Text("Search")
                        .font(.boardlyTitle)
                        .foregroundStyle(Color.boardlyInk)

                    searchField($viewModel.query)
                    scopeChips($viewModel.scope)
                    results
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .navigationDestination(for: AppRoute.self) { route in
                switch route {
                case let .project(id, name):
                    ProjectDetailView(client: client, projectId: id, projectName: name, path: $path)
                case let .board(id, name, projectName, focusCardId):
                    BoardView(
                        client: client,
                        boardId: id,
                        boardName: name,
                        projectName: projectName,
                        focusCardId: focusCardId)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            await viewModel.loadIfNeeded()
            if viewModel.query.isEmpty, !initialQuery.isEmpty { viewModel.query = initialQuery }
        }
    }

    // MARK: - Search field + chips

    private func searchField(_ text: Binding<String>) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.boardlyTextTertiary)
            TextField("Search…", text: text)
                .font(.boardlyBody)
                .foregroundStyle(Color.boardlyInk)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !text.wrappedValue.isEmpty {
                Button { text.wrappedValue = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.boardlyTextTertiary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.boardlySeparator, lineWidth: 1))
    }

    private func scopeChips(_ scope: Binding<SearchScope>) -> some View {
        HStack(spacing: 8) {
            ForEach(SearchScope.allCases) { item in
                let active = scope.wrappedValue == item
                Button { scope.wrappedValue = item } label: {
                    Text(LocalizedStringKey(item.rawValue))
                        .font(.sans(14, .semibold))
                        .foregroundStyle(active ? .white : Color.boardlyTextSecondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            active ? Color.accentColor : Color.boardlySurface,
                            in: Capsule())
                        .overlay(active ? nil : Capsule().stroke(Color.boardlySeparator, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Results

    @ViewBuilder
    private var results: some View {
        if let error = viewModel.error, !viewModel.isIndexing {
            errorState(error)
        } else if !viewModel.hasQuery {
            idle
        } else if !viewModel.hasAnyResult {
            emptyResults
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if !viewModel.cardResults.isEmpty {
                        section("Cards", count: viewModel.cardResults.count) {
                            ForEach(Array(viewModel.cardResults.enumerated()), id: \.element.id) { index, hit in
                                if index > 0 { Divider().padding(.leading, 48) }
                                cardRow(hit)
                            }
                        }
                    }
                    if !viewModel.boardResults.isEmpty {
                        section("Boards", count: viewModel.boardResults.count) {
                            ForEach(Array(viewModel.boardResults.enumerated()), id: \.element.id) { index, hit in
                                if index > 0 { Divider().padding(.leading, 48) }
                                boardRow(hit)
                            }
                        }
                    }
                    if !viewModel.projectResults.isEmpty {
                        section("Projects", count: viewModel.projectResults.count) {
                            ForEach(Array(viewModel.projectResults.enumerated()), id: \.element.id) { index, project in
                                if index > 0 { Divider().padding(.leading, 48) }
                                projectRow(project)
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
            }
        }
    }

    private func section(
        _ title: String,
        count: Int,
        @ViewBuilder content: () -> some View) -> some View
    {
        VStack(alignment: .leading, spacing: 8) {
            BoardlyFieldLabel("\(title) · \(count)")
            VStack(spacing: 0) {
                content()
            }
            .boardlyCard(padding: 0)
        }
    }

    private func cardRow(_ hit: CardHit) -> some View {
        Button {
            path.append(.board(
                id: hit.boardId,
                name: hit.boardName,
                projectName: hit.projectName,
                focusCardId: hit.card.id))
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.boardlyTextTertiary)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(highlighted(hit.card.name))
                        .font(.boardlyBody)
                        .foregroundStyle(Color.boardlyInk)
                        .lineLimit(1)
                    Text(context(hit.projectName, hit.listName))
                        .font(.boardlyMonoCaption)
                        .foregroundStyle(Color.boardlyTextTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func boardRow(_ hit: BoardHit) -> some View {
        Button {
            path.append(.board(id: hit.board.id, name: hit.board.name, projectName: hit.projectName))
        } label: {
            HStack(spacing: 12) {
                Capsule().fill(Color.accentColor).frame(width: 4, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(highlighted(hit.board.name))
                        .font(.boardlyBody)
                        .foregroundStyle(Color.boardlyInk)
                        .lineLimit(1)
                    Text(context(hit.projectName, String(localized: "\(hit.cardCount) cards")))
                        .font(.boardlyMonoCaption)
                        .foregroundStyle(Color.boardlyTextTertiary)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.boardlyTextTertiary)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func projectRow(_ project: Project) -> some View {
        Button {
            path.append(.project(id: project.id, name: project.name))
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(projectColor(project.id))
                    .frame(width: 26, height: 26)
                Text(highlighted(project.name))
                    .font(.boardlyBody)
                    .foregroundStyle(Color.boardlyInk)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.boardlyTextTertiary)
            }
            .padding(14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func context(_ a: String, _ b: String) -> String {
        [a, b].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    /// Highlight the matched substring (case/diacritic-insensitive) on the original
    /// text. Uses the trimmed query so it matches what filtering matched on.
    private func highlighted(_ text: String) -> AttributedString {
        var attributed = AttributedString(text)
        let query = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty,
              let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]),
              let attrRange = Range(range, in: attributed)
        else { return attributed }
        attributed[attrRange].backgroundColor = Color.yellow.opacity(0.4)
        attributed[attrRange].font = .boardlyBody.bold()
        return attributed
    }

    // MARK: - Idle / empty

    private var idle: some View {
        VStack(spacing: 12) {
            if viewModel.isIndexing {
                ProgressView().tint(Color.boardlyTextTertiary)
                Text("Indexing…")
                    .font(.boardlyCallout)
                    .foregroundStyle(Color.boardlyTextTertiary)
            } else {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(Color.boardlyTextTertiary)
                Text("Cards, boards, and projects")
                    .font(.boardlyBody)
                    .foregroundStyle(Color.boardlyTextSecondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private var emptyResults: some View {
        VStack(spacing: 10) {
            Text("No results")
                .font(.boardlyHeadline)
                .foregroundStyle(Color.boardlyInk)
            Text("for “\(viewModel.query)”")
                .font(.boardlyCallout)
                .foregroundStyle(Color.boardlyTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private func errorState(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.labelRose)
            Text(message)
                .font(.boardlyBody)
                .foregroundStyle(Color.boardlyTextSecondary)
                .multilineTextAlignment(.center)
            Button("Retry") { Task { await viewModel.loadIfNeeded() } }
                .buttonStyle(.boardlySecondary)
                .fixedSize()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}
