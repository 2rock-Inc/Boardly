import SwiftUI
import BoardlyKit

@Observable
@MainActor
final class ProjectListViewModel {
    var payload: ProjectsPayload?
    var isLoading = false
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

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.payload == nil {
                ProgressView()
            } else if let error = viewModel.error {
                ContentUnavailableView(error, systemImage: "exclamationmark.triangle")
            } else if let payload = viewModel.payload {
                projectList(payload)
            }
        }
        .navigationTitle("Projects")
        .task { await viewModel.load(using: client) }
        .refreshable { await viewModel.load(using: client) }
    }

    @ViewBuilder
    private func projectList(_ payload: ProjectsPayload) -> some View {
        if payload.projects.isEmpty {
            ContentUnavailableView(
                "No Projects",
                systemImage: "folder",
                description: Text("No projects found on this server.")
            )
        } else {
            List {
                ForEach(payload.projects) { project in
                    let boards = payload.boards(for: project)
                    if !boards.isEmpty {
                        Section(project.name) {
                            ForEach(boards) { board in
                                Button {
                                    path.append(.board(id: board.id, name: board.name))
                                } label: {
                                    HStack {
                                        Image(systemName: "rectangle.split.3x1")
                                            .foregroundStyle(.secondary)
                                        Text(board.name)
                                            .foregroundStyle(.primary)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundStyle(.tertiary)
                                            .font(.caption)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}
