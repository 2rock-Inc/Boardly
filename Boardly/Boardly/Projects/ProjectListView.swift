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
                        let boards = payload.boards(for: project)
                        if !boards.isEmpty {
                            ProjectCard(
                                project: project,
                                boards: boards,
                                members: payload.members(for: project),
                                onOpenBoard: { path.append(.board(id: $0.id, name: $0.name)) }
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

// MARK: - Project card (colored header + member avatars + board rows)

private struct ProjectCard: View {
    let project: Project
    let boards: [Board]
    let members: [User]
    let onOpenBoard: (Board) -> Void

    private static let headerColors: [Color] = [.labelTeal, .labelBlue, .labelPurple, .labelGreen]
    private var headerColor: Color {
        Self.headerColors[abs(project.id.hashValue) % Self.headerColors.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Text(project.name)
                    .font(.sans(16, .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer(minLength: 8)
                AvatarStack(members: members)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(headerColor)

            // Board rows
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
        Self.dotColors[abs(board.id.hashValue) % Self.dotColors.count]
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
