import SwiftUI
import PhotosUI
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
    var backgroundImages: [BackgroundImage] = []
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
            self.backgroundImages = payload.backgroundImages
            let boards = payload.boards(for: project)
            stats = boards.map { BoardStat(board: $0) }
            await loadCounts(client: client)
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Background

    /// The uploaded image currently set as the project's background, if any.
    var currentBackgroundImage: BackgroundImage? {
        guard let id = project?.backgroundImageId else { return nil }
        return backgroundImages.first { $0.id == id }
    }

    @discardableResult
    func setGradient(_ name: String, using client: PlankaClient) async -> Bool {
        guard let id = project?.id else { return false }
        error = nil
        do {
            project = try await client.updateProject(
                id: id, patch: ProjectPatch(backgroundType: "gradient", backgroundGradient: name))
            return true
        } catch {
            self.error = "Impossible de changer le fond."
            return false
        }
    }

    @discardableResult
    func uploadImage(data: Data, fileName: String, mimeType: String, using client: PlankaClient) async -> Bool {
        guard let id = project?.id else { return false }
        error = nil
        do {
            let image = try await client.uploadBackgroundImage(
                projectId: id, fileName: fileName, mimeType: mimeType, data: data)
            backgroundImages.append(image)
            project = try await client.updateProject(
                id: id, patch: ProjectPatch(backgroundType: "image", backgroundImageId: image.id))
            return true
        } catch {
            self.error = "Échec de l’envoi de l’image de fond."
            return false
        }
    }

    @discardableResult
    func clearBackground(using client: PlankaClient) async -> Bool {
        guard let id = project?.id else { return false }
        error = nil
        do {
            project = try await client.updateProject(id: id, patch: ProjectPatch(clearBackground: true))
            return true
        } catch {
            self.error = "Impossible de retirer le fond."
            return false
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
    @State private var showBackgroundPicker = false

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
        .sheet(isPresented: $showBackgroundPicker) {
            BackgroundPickerSheet(viewModel: viewModel, client: client)
                .presentationDetents([.medium, .large])
        }
    }

    // MARK: - Hero

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            heroBackground
            // Scrim so white text stays legible over light gradients/images.
            LinearGradient(colors: [.clear, .black.opacity(0.35)],
                           startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button { showBackgroundPicker = true } label: {
                        Image(systemName: "paintbrush.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(9)
                            .background(.black.opacity(0.22), in: Circle())
                    }
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
        .clipped()
    }

    @ViewBuilder
    private var heroBackground: some View {
        if let project = viewModel.project,
           project.backgroundType == "image",
           let image = viewModel.currentBackgroundImage,
           let url = client.resourceURL(image.url) {
            BackgroundImageView(url: url) { await client.imageData(url: $0) }
        } else if let project = viewModel.project,
                  project.backgroundType == "gradient",
                  let name = project.backgroundGradient {
            PlankaGradient.linear(name)
        } else {
            projectColor(projectId)
        }
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
            VStack(alignment: .leading, spacing: 14) {
                Text(stat.board.name)
                    .font(.sans(16, .bold))
                    .foregroundStyle(Color.boardlyInk)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                miniBar

                Text(metaText)
                    .font(.mono(11, .medium))
                    .foregroundStyle(Color.boardlyTextSecondary)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
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
        .frame(maxWidth: .infinity, minHeight: 132)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .foregroundStyle(Color.boardlySeparator)
        )
    }
}

// MARK: - Background image (authenticated)

private struct BackgroundImageView: View {
    let url: URL
    let load: (URL) async -> Data?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.boardlySurfaceSecondary
            }
        }
        .task(id: url) { image = await load(url).flatMap(UIImage.init(data:)) }
    }
}

// MARK: - Background picker sheet

private struct BackgroundPickerSheet: View {
    let viewModel: ProjectDetailViewModel
    let client: PlankaClient
    @Environment(\.dismiss) private var dismiss
    @State private var photoItem: PhotosPickerItem?
    @State private var isUploading = false

    private let columns = [GridItem(.adaptive(minimum: 92), spacing: 10)]

    private var currentGradient: String? {
        viewModel.project?.backgroundType == "gradient" ? viewModel.project?.backgroundGradient : nil
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Fond du projet", onCancel: { dismiss() }, onDone: { dismiss() })

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let error = viewModel.error {
                        Text(error)
                            .font(.boardlyCallout)
                            .foregroundStyle(Color.labelRose)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 10) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label("Importer une image", systemImage: "photo")
                                .font(.sans(15, .semibold))
                                .foregroundStyle(Color.boardlyInk)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.boardlySurfaceSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                        if viewModel.project?.backgroundType != nil {
                            Button {
                                Task { if await viewModel.clearBackground(using: client) { dismiss() } }
                            } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color.labelRose)
                                    .padding(13)
                                    .background(Color.boardlySurfaceSecondary, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }

                    BoardlyFieldLabel("Dégradés")
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(PlankaGradient.names, id: \.self) { name in
                            Button {
                                Task { if await viewModel.setGradient(name, using: client) { dismiss() } }
                            } label: {
                                PlankaGradient.linear(name)
                                    .frame(height: 54)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(Color.boardlyInk, lineWidth: currentGradient == name ? 3 : 0)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .background(Color.boardlyBackground)
        .overlay {
            if isUploading {
                ZStack {
                    Color.black.opacity(0.15).ignoresSafeArea()
                    ProgressView().tint(Color.boardlyInk)
                }
            }
        }
        .task(id: photoItem) {
            guard let photoItem else { return }
            isUploading = true
            defer { isUploading = false }
            self.photoItem = nil
            if let data = try? await photoItem.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data),
               let jpeg = uiImage.jpegData(compressionQuality: 0.9) {
                if await viewModel.uploadImage(
                    data: jpeg, fileName: "background.jpg", mimeType: "image/jpeg", using: client) {
                    dismiss()
                }
            } else {
                viewModel.error = "Image illisible."
            }
        }
    }
}
