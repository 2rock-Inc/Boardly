import BoardlyKit
import SwiftUI

/// Draft for the add/edit notification-service sheet. `id == nil` means new.
private struct NotificationServiceDraft: Identifiable {
    var id: String?
    var url: String = ""
    var format: String = "text"
    var editingID: String { id ?? "new" }
}

/// Profile → Notifications: manage the current user's outbound notification
/// services (a URL + message format PLANKA pushes notifications to).
struct NotificationServicesView: View {
    let viewModel: ProfileViewModel
    @State private var draft: NotificationServiceDraft?
    @State private var testedID: String?

    var body: some View {
        ZStack {
            Color.boardlyBackground.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Boardly will send your notifications to these external services (Apprise, chat, webhook…).")
                        .font(.boardlyCallout)
                        .foregroundStyle(Color.boardlyTextSecondary)

                    if viewModel.services.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.services.enumerated()), id: \.element.id) { index, service in
                                if index > 0 { Divider().padding(.leading, 14) }
                                row(service)
                            }
                        }
                        .boardlyCard(padding: 0)
                    }

                    Button {
                        draft = NotificationServiceDraft()
                    } label: {
                        Label("Add Service", systemImage: "plus")
                    }
                    .buttonStyle(.boardlySecondary)
                }
                .padding(20)
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $draft) { current in
            NotificationServiceSheet(draft: current) { saved in
                Task {
                    if let id = saved.id {
                        await viewModel.updateService(id: id, url: saved.url, format: saved.format)
                    } else {
                        await viewModel.addService(url: saved.url, format: saved.format)
                    }
                }
            }
            .presentationDetents([.height(320)])
        }
    }

    private func row(_ service: NotificationService) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(service.url)
                    .font(.boardlyBody)
                    .foregroundStyle(Color.boardlyInk)
                    .lineLimit(1)
                Text(service.format.uppercased())
                    .font(.boardlyMonoCaption)
                    .foregroundStyle(Color.boardlyTextTertiary)
            }
            Spacer(minLength: 8)
            Button {
                Task { if await viewModel.testService(service) { testedID = service.id } }
            } label: {
                Image(systemName: testedID == service.id ? "checkmark.circle.fill" : "paperplane")
                    .foregroundStyle(testedID == service.id ? Color.labelGreen : Color.accentColor)
            }
            Button {
                draft = NotificationServiceDraft(id: service.id, url: service.url, format: service.format)
            } label: {
                Image(systemName: "pencil").foregroundStyle(Color.boardlyTextSecondary)
            }
            Button(role: .destructive) {
                Task { await viewModel.deleteService(service) }
            } label: {
                Image(systemName: "trash").foregroundStyle(Color.boardlyDestructive)
            }
        }
        .padding(14)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "bell.slash")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(Color.boardlyTextTertiary)
            Text("No services configured")
                .font(.boardlyHeadline)
                .foregroundStyle(Color.boardlyInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

// MARK: - Add / edit sheet

private struct NotificationServiceSheet: View {
    @State var draft: NotificationServiceDraft
    let onSave: (NotificationServiceDraft) -> Void
    @Environment(\.dismiss) private var dismiss

    private let formats = ["text", "markdown", "html"]

    private var canSave: Bool {
        !draft.url.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(
                title: draft.id == nil ? "New Service" : "Edit",
                onCancel: { dismiss() },
                onDone: {
                    guard canSave else { return }
                    onSave(draft)
                    dismiss()
                })
            VStack(alignment: .leading, spacing: 16) {
                BoardlyFieldLabel("Service URL")
                TextField("https://…", text: $draft.url)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .boardlyField()

                BoardlyFieldLabel("Format")
                Picker("Format", selection: $draft.format) {
                    Text("Text").tag("text")
                    Text("Markdown").tag("markdown")
                    Text("HTML").tag("html")
                }
                .pickerStyle(.segmented)
            }
            .padding(20)
            Spacer()
        }
        .background(Color.boardlyBackground)
    }
}
