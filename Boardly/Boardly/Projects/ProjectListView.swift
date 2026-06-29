import SwiftUI
import BoardlyKit

@Observable
@MainActor
final class ProjectListViewModel {
    var payload: ProjectsPayload?
    var isLoading = true
    var error: String?

    func load(using client: PlankaClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            payload = try await client.getProjects()
        } catch {
            self.error = error.localizedDescription
        }
    }
}

struct ProjectListView: View {
    let client: PlankaClient
    @Binding var path: [AppRoute]
    @State private var viewModel = ProjectListViewModel()
    @State private var query = ""

    var body: some View {
        ZStack {
            Color.boardlyBackground.ignoresSafeArea()

            if viewModel.payload == nil && viewModel.error == nil {
                ProgressView().tint(.accentColor)
            } else if let error = viewModel.error {
                ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
            } else if let payload = viewModel.payload {
                content(payload)
            }
        }
        .navigationTitle("")
        .task { await viewModel.load(using: client) }
    }

    @ViewBuilder
    private func content(_ payload: ProjectsPayload) -> some View {
        let projects = filteredProjects(payload)

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Projets")
                    .font(.boardlyTitle)
                    .foregroundStyle(Color.boardlyInk)
                    .padding(.top, 8)

                searchField

                if projects.isEmpty {
                    emptyState
                } else {
                    ForEach(projects) { project in
                        projectSection(project, boards: payload.boards(for: project))
                    }
                }
            }
            .padding(20)
        }
        .refreshable { await viewModel.load(using: client) }
        .scrollDismissesKeyboard(.immediately)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.boardlyTextTertiary)
            TextField("Rechercher un projet, un board…", text: $query)
                .font(.boardlyBody)
                .foregroundStyle(Color.boardlyInk)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color.boardlySurface, in: Capsule())
        .overlay(Capsule().stroke(Color.boardlySeparator, lineWidth: 1))
    }

    @ViewBuilder
    private func projectSection(_ project: Project, boards: [Board]) -> some View {
        if !boards.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(project.name)
                    .font(.boardlyMonoLabel)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.boardlyTextSecondary)

                ForEach(boards) { board in
                    Button {
                        path.append(.board(id: board.id, name: board.name))
                    } label: {
                        BoardRowView(board: board)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "folder")
                .font(.system(size: 32))
                .foregroundStyle(Color.boardlyTextTertiary)
            Text(query.isEmpty ? "Aucun projet" : "Aucun résultat")
                .font(.boardlyHeadline)
                .foregroundStyle(Color.boardlyInk)
            Text(query.isEmpty ? "Aucun projet sur ce serveur." : "Essaie un autre terme.")
                .font(.boardlyBody)
                .foregroundStyle(Color.boardlyTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // Client-side filter over already-loaded data (the global search screen is Phase 5).
    private func filteredProjects(_ payload: ProjectsPayload) -> [Project] {
        guard !query.isEmpty else { return payload.projects }
        let q = query.lowercased()
        return payload.projects.filter { project in
            project.name.lowercased().contains(q)
                || payload.boards(for: project).contains { $0.name.lowercased().contains(q) }
        }
    }
}

private struct BoardRowView: View {
    let board: Board

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "rectangle.split.3x1")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.boardlySurfaceSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text(board.name)
                .font(.boardlyHeadline)
                .foregroundStyle(Color.boardlyInk)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.boardlyTextTertiary)
        }
        .boardlyCard()
    }
}
