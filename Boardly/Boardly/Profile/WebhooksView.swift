import SwiftUI
import BoardlyKit

@Observable
@MainActor
final class WebhooksViewModel {
    private let client: PlankaClient
    var webhooks: [Webhook] = []
    var isLoading = false
    var error: String?

    init(client: PlankaClient) {
        self.client = client
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            webhooks = try await client.getWebhooks()
        } catch PlankaAPIError.forbidden {
            error = "Accès réservé aux administrateurs."
        } catch {
            self.error = "Impossible de charger les webhooks."
        }
    }

    func create(name: String, url: String, accessToken: String?, events: [String]?) async {
        do {
            let webhook = try await client.createWebhook(
                name: name, url: url, accessToken: accessToken, events: events)
            webhooks.append(webhook)
        } catch {
            self.error = "Impossible de créer le webhook."
        }
    }

    func delete(_ webhook: Webhook) async {
        let previous = webhooks
        webhooks.removeAll { $0.id == webhook.id }
        do {
            try await client.deleteWebhook(id: webhook.id)
        } catch {
            webhooks = previous
            self.error = "Impossible de supprimer le webhook."
        }
    }
}

/// Profil → Webhooks (admin only): list and manage instance webhooks.
struct WebhooksView: View {
    let client: PlankaClient
    @State private var viewModel: WebhooksViewModel?
    @State private var showAdd = false

    var body: some View {
        ZStack {
            Color.boardlyBackground.ignoresSafeArea()
            ScrollView {
                if let viewModel {
                    VStack(alignment: .leading, spacing: 16) {
                        if let error = viewModel.error {
                            Text(error).font(.boardlyCallout).foregroundStyle(Color.labelRose)
                        }
                        if viewModel.webhooks.isEmpty, viewModel.error == nil {
                            Text("Aucun webhook configuré.")
                                .font(.boardlyBody)
                                .foregroundStyle(Color.boardlyTextSecondary)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(viewModel.webhooks.enumerated()), id: \.element.id) { index, hook in
                                    if index > 0 { Divider().padding(.leading, 14) }
                                    row(hook, viewModel: viewModel)
                                }
                            }
                            .boardlyCard(padding: 0)
                        }

                        Button {
                            showAdd = true
                        } label: {
                            Label("Ajouter un webhook", systemImage: "plus")
                        }
                        .buttonStyle(.boardlySecondary)
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("Webhooks")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil { viewModel = WebhooksViewModel(client: client) }
            await viewModel?.load()
        }
        .sheet(isPresented: $showAdd) {
            if let viewModel {
                WebhookSheet { name, url, token, events in
                    Task { await viewModel.create(name: name, url: url, accessToken: token, events: events) }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    private func row(_ hook: Webhook, viewModel: WebhooksViewModel) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(hook.name)
                    .font(.sans(15, .semibold))
                    .foregroundStyle(Color.boardlyInk)
                Text(hook.url)
                    .font(.boardlyMonoCaption)
                    .foregroundStyle(Color.boardlyTextSecondary)
                    .lineLimit(1)
                Text(eventsLabel(hook))
                    .font(.boardlyMonoCaption)
                    .foregroundStyle(Color.boardlyTextTertiary)
            }
            Spacer(minLength: 8)
            Button(role: .destructive) {
                Task { await viewModel.delete(hook) }
            } label: {
                Image(systemName: "trash").foregroundStyle(Color.labelRose)
            }
        }
        .padding(14)
    }

    private func eventsLabel(_ hook: Webhook) -> String {
        guard let events = hook.events, !events.isEmpty else { return "Tous les événements" }
        return events.joined(separator: ", ")
    }
}

// MARK: - Add sheet

private struct WebhookSheet: View {
    let onSave: (_ name: String, _ url: String, _ accessToken: String?, _ events: [String]?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var url = ""
    @State private var accessToken = ""
    @State private var events = ""

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && !url.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Nouveau webhook", onCancel: { dismiss() }, onDone: {
                guard canSave else { return }
                let eventList = events
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                onSave(name, url,
                       accessToken.isEmpty ? nil : accessToken,
                       eventList.isEmpty ? nil : eventList)
                dismiss()
            })
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    field("Nom", text: $name, placeholder: "Mon webhook")
                    field("URL", text: $url, placeholder: "https://…", url: true)
                    field("Token d’accès (optionnel)", text: $accessToken, placeholder: "secret", secure: true)
                    field("Événements (séparés par des virgules, vide = tous)",
                          text: $events, placeholder: "cardCreate, cardUpdate")
                }
                .padding(20)
            }
        }
        .background(Color.boardlyBackground)
    }

    @ViewBuilder
    private func field(_ label: String, text: Binding<String>, placeholder: String,
                       url: Bool = false, secure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            BoardlyFieldLabel(label)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                        .keyboardType(url ? .URL : .default)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .boardlyField()
        }
    }
}
