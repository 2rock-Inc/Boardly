import SwiftUI
import BoardlyKit

@Observable
@MainActor
final class ProjectListViewModel {
    var payload: ProjectsPayload?
    var currentUser: User?
    var isLoading = true
    var error: String?

    func load(using client: PlankaClient) async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let payload = try await client.getProjects()
            self.payload = payload
            resolveCurrentUser(in: payload, client: client)
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func resolveCurrentUser(in payload: ProjectsPayload, client: PlankaClient) {
        guard let uid = client.currentUserId() else { return }
        currentUser = payload.users.first { $0.id == uid }
    }
}

// Stable project color shared by favorite cards and project headers.
func projectColor(_ id: String) -> Color {
    [Color.labelTeal, .labelBlue, .labelPurple, .labelGreen][boardlyStableHash(id) % 4]
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
        let favorites = projects.filter { $0.isFavorite == true && !payload.boards(for: $0).isEmpty }

        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                searchField

                if projects.isEmpty {
                    emptyState
                } else {
                    if !favorites.isEmpty {
                        sectionLabel("Favoris")
                        favoritesRow(favorites, payload: payload)
                    }

                    sectionLabel("Tous les projets")
                    ForEach(projects) { project in
                        let boards = payload.boards(for: project)
                        if !boards.isEmpty {
                            ProjectCard(
                                project: project,
                                boards: boards,
                                members: payload.members(for: project),
                                onOpenBoard: { path.append(.board(id: $0.id, name: $0.name, projectName: project.name)) },
                                onOpenProject: { path.append(.project(id: project.id, name: project.name)) }
                            )
                        }
                    }
                }
            }
            .padding(20)
        }
        .refreshable { await viewModel.load(using: client) }
        .scrollDismissesKeyboard(.immediately)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Projets")
                .font(.boardlyTitle)
                .foregroundStyle(Color.boardlyInk)
            Spacer()
            Button {
                // Project creation lands in Phase 5 (admin POST /projects).
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            if let user = viewModel.currentUser {
                AvatarView(name: user.name, size: 34, bordered: false)
            }
        }
        .padding(.top, 8)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.boardlyMonoLabel)
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.boardlyTextSecondary)
    }

    private func favoritesRow(_ favorites: [Project], payload: ProjectsPayload) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(favorites) { project in
                    let boards = payload.boards(for: project)
                    Button {
                        if let first = boards.first {
                            path.append(.board(id: first.id, name: first.name))
                        }
                    } label: {
                        FavoriteCard(project: project, boardCount: boards.count)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.bottom, 2)
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.boardlyTextTertiary)
            TextField("Rechercher un projet, un board…", text: $query)
                .font(.boardlyBody)
                .foregroundStyle(Color.boardlyInk)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
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

    private func filteredProjects(_ payload: ProjectsPayload) -> [Project] {
        guard !query.isEmpty else { return payload.projects }
        let q = query.lowercased()
        return payload.projects.filter { project in
            project.name.lowercased().contains(q)
                || payload.boards(for: project).contains { $0.name.lowercased().contains(q) }
        }
    }
}

// MARK: - Favorite card (horizontal)

private struct FavoriteCard: View {
    let project: Project
    let boardCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(projectColor(project.id))
                .frame(height: 5)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.labelTeal)
                    Text(project.name)
                        .font(.boardlyMonoCaption)
                        .foregroundStyle(Color.boardlyTextSecondary)
                        .lineLimit(1)
                }
                Text("\(boardCount) board\(boardCount > 1 ? "s" : "")")
                    .font(.sans(17, .bold))
                    .foregroundStyle(Color.boardlyInk)
                    .lineLimit(1)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: 170)
        .background(Color.boardlySurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.boardlySeparator, lineWidth: 0.5)
        )
    }
}

// MARK: - Project card (colored header + member avatars + board rows)

private struct ProjectCard: View {
    let project: Project
    let boards: [Board]
    let members: [User]
    let onOpenBoard: (Board) -> Void
    let onOpenProject: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Text(project.name)
                    .font(.sans(16, .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                AvatarStack(members: members)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(projectColor(project.id))
            .contentShape(Rectangle())
            .onTapGesture { onOpenProject() }

            VStack(spacing: 0) {
                ForEach(Array(boards.enumerated()), id: \.element.id) { index, board in
                    Button { onOpenBoard(board) } label: {
                        BoardRow(board: board)
                    }
                    .buttonStyle(.plain)
                    if index < boards.count - 1 {
                        Divider().padding(.leading, 38)
                    }
                }
            }
            .background(Color.boardlySurface)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.boardlySeparator, lineWidth: 0.5)
        )
    }
}

private struct BoardRow: View {
    let board: Board

    private static let dotColors: [Color] = [.labelTeal, .labelBlue, .labelGreen, .labelPurple, .labelRose]
    private var dotColor: Color {
        Self.dotColors[boardlyStableHash(board.id) % Self.dotColors.count]
    }

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(dotColor)
                .frame(width: 8, height: 8)
            Text(board.name)
                .font(.sans(15, .semibold))
                .foregroundStyle(Color.boardlyInk)
                .lineLimit(1)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.boardlyTextTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

private struct AvatarStack: View {
    let members: [User]

    var body: some View {
        let shown = members.prefix(3)
        HStack(spacing: -8) {
            ForEach(shown) { user in
                AvatarView(name: user.name, size: 26)
            }
            if members.count > shown.count {
                Text("+\(members.count - shown.count)")
                    .font(.mono(10, .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(.white.opacity(0.25), in: Circle())
                    .overlay(Circle().stroke(Color.boardlySurface, lineWidth: 2))
            }
        }
    }
}
