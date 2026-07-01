import SwiftUI
import BoardlyKit

struct BoardStat: Identifiable {
    let board: Board
    var listCount: Int?
    var cardCount: Int?
    var id: String { board.id }
}

@Observable
@MainActor
final class ProjectDetailViewModel {
    var project: Project?
    var stats: [BoardStat] = []
    var isLoading = true
    var error: String?

    func load(projectId: String, using client: PlankaClient) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let payload = try await client.getProjects()
            guard let project = payload.projects.first(where: { $0.id == projectId }) else {
                error = "Projet introuvable."
                return
            }
            self.project = project
            let boards = payload.boards(for: project)
            stats = boards.map { BoardStat(board: $0) }
            await loadCounts(client: client)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // One board fetch per board (bounded drill-in) to surface real card/list counts.
    private func loadCounts(client: PlankaClient) async {
        await withTaskGroup(of: (String, Int, Int)?.self) { group in
            for stat in stats {
                let id = stat.board.id
                group.addTask {
                    guard let payload = try? await client.getBoard(id: id) else { return nil }
                    return (id, payload.sortedLists().count, payload.cards.count)
                }
            }
            for await result in group {
                guard let (id, lists, cards) = result,
                      let idx = stats.firstIndex(where: { $0.board.id == id }) else { continue }
                stats[idx].listCount = lists
                stats[idx].cardCount = cards
            }
        }
    }
}

struct ProjectDetailView: View {
    let client: PlankaClient
    let projectId: String
    let projectName: String
    @Binding var path: [AppRoute]
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = ProjectDetailViewModel()

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ZStack(alignment: .top) {
            Color.boardlyBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    hero
                    body(for: viewModel.project)
                }
            }
            .ignoresSafeArea(edges: .top)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task { await viewModel.load(projectId: projectId, using: client) }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            projectColor(projectId)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                }
                Spacer()
                Text("PROJET")
                    .font(.boardlyMonoLabel)
                    .tracking(2)
                    .foregroundStyle(.white.opacity(0.7))
                Text(viewModel.project?.name ?? projectName)
                    .font(.sans(28, .heavy))
                    .foregroundStyle(.white)
                    .lineLimit(2)
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 22)
        }
        .frame(height: 220)
    }

    @ViewBuilder
    private func body(for project: Project?) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            if let description = project?.description, !description.isEmpty {
                Text(description)
                    .font(.boardlyBody)
                    .foregroundStyle(Color.boardlyTextSecondary)
            }

            HStack {
                Text("Boards · \(viewModel.stats.count)")
                    .font(.boardlyMonoLabel)
                    .tracking(1.5)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.boardlyTextSecondary)
                Spacer()
                Label("Board", systemImage: "plus")
                    .font(.boardlyCallout)
                    .foregroundStyle(Color.accentColor)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(viewModel.stats) { stat in
                    Button {
                        path.append(.board(id: stat.board.id, name: stat.board.name, projectName: project?.name))
                    } label: {
                        BoardGridCard(stat: stat)
                    }
                    .buttonStyle(.plain)
                }
                NewBoardCard()
            }
        }
        .padding(20)
    }
}

private struct BoardGridCard: View {
    let stat: BoardStat

    private static let palette: [Color] = [.labelTeal, .labelBlue, .labelGreen, .labelPurple, .labelRose]
    private var accent: Color { Self.palette[boardlyStableHash(stat.board.id) % Self.palette.count] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle().fill(accent).frame(height: 5)
            VStack(alignment: .leading, spacing: 10) {
                Text(stat.board.name)
                    .font(.sans(15, .bold))
                    .foregroundStyle(Color.boardlyInk)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                miniBar

                Text(metaText)
                    .font(.mono(11, .medium))
                    .foregroundStyle(Color.boardlyTextSecondary)
            }
            .padding(14)
        }
        .background(Color.boardlySurface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.boardlySeparator, lineWidth: 0.5)
        )
    }

    private var miniBar: some View {
        HStack(spacing: 3) {
            let filled = min(stat.listCount ?? 0, 5)
            ForEach(0 ..< 5, id: \.self) { i in
                RoundedRectangle(cornerRadius: 2)
                    .fill(i < filled ? Self.palette[i % Self.palette.count] : Color.boardlySurfaceSecondary)
                    .frame(height: 5)
            }
        }
    }

    private var metaText: String {
        guard let cards = stat.cardCount, let lists = stat.listCount else { return "…" }
        return "\(cards) carte\(cards > 1 ? "s" : "") · \(lists) liste\(lists > 1 ? "s" : "")"
    }
}

private struct NewBoardCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color.boardlyTextTertiary)
            Text("Nouveau board")
                .font(.boardlyCallout)
                .foregroundStyle(Color.boardlyTextSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(Color.boardlySeparator)
        )
    }
}
