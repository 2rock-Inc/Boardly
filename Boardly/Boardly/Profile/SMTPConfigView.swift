import SwiftUI
import BoardlyKit

@Observable
@MainActor
final class SMTPConfigViewModel {
    private let client: PlankaClient

    var host = ""
    var portText = ""
    var from = ""
    var user = ""
    var password = ""
    var secure = false

    var isLoading = false
    var isSaving = false
    var error: String?
    var notice: String?

    init(client: PlankaClient) {
        self.client = client
    }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            apply(try await client.getConfig())
        } catch PlankaAPIError.forbidden {
            error = "Accès réservé aux administrateurs."
        } catch {
            self.error = "Impossible de charger la configuration."
        }
    }

    private func apply(_ config: Config) {
        host = config.smtpHost ?? ""
        portText = config.smtpPort.map(String.init) ?? ""
        from = config.smtpFrom ?? ""
        user = config.smtpUser ?? ""
        password = config.smtpPassword ?? ""
        secure = config.smtpSecure ?? false
    }

    func save() async {
        isSaving = true
        error = nil
        notice = nil
        defer { isSaving = false }
        let patch = ConfigPatch(
            smtpHost: host.isEmpty ? nil : host,
            smtpPort: Int(portText),
            smtpSecure: secure,
            smtpUser: user.isEmpty ? nil : user,
            smtpPassword: password.isEmpty ? nil : password,
            smtpFrom: from.isEmpty ? nil : from
        )
        do {
            apply(try await client.updateConfig(patch: patch))
            notice = "Configuration enregistrée."
        } catch {
            self.error = "Échec de l’enregistrement."
        }
    }

    func sendTest() async {
        error = nil
        notice = nil
        do {
            try await client.testSMTP()
            notice = "E-mail de test envoyé."
        } catch {
            self.error = "Échec de l’envoi du test (SMTP configuré via l’UI requis)."
        }
    }
}

/// Profil → Configuration SMTP (admin only): edit instance mail settings + test.
struct SMTPConfigView: View {
    let client: PlankaClient
    @State private var viewModel: SMTPConfigViewModel?

    var body: some View {
        ZStack {
            Color.boardlyBackground.ignoresSafeArea()
            ScrollView {
                if let viewModel {
                    form(viewModel)
                }
            }
        }
        .navigationTitle("Configuration SMTP")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if viewModel == nil { viewModel = SMTPConfigViewModel(client: client) }
            await viewModel?.load()
        }
    }

    @ViewBuilder
    private func form(_ viewModel: SMTPConfigViewModel) -> some View {
        @Bindable var viewModel = viewModel
        VStack(alignment: .leading, spacing: 16) {
            if let notice = viewModel.notice {
                Text(notice).font(.boardlyCallout).foregroundStyle(Color.labelGreen)
            }
            if let error = viewModel.error {
                Text(error).font(.boardlyCallout).foregroundStyle(Color.labelRose)
            }

            field("Serveur SMTP", text: $viewModel.host, placeholder: "smtp.example.com", url: true)
            field("Port", text: $viewModel.portText, placeholder: "587", number: true)
            field("Expéditeur (From)", text: $viewModel.from, placeholder: "no-reply@example.com", url: true)
            field("Utilisateur", text: $viewModel.user, placeholder: "utilisateur")

            VStack(alignment: .leading, spacing: 6) {
                BoardlyFieldLabel("Mot de passe")
                SecureField("••••••••", text: $viewModel.password).boardlyField()
            }

            Toggle("Connexion sécurisée (TLS)", isOn: $viewModel.secure)
                .font(.boardlyBody)
                .tint(.accentColor)

            Button {
                Task { await viewModel.save() }
            } label: {
                if viewModel.isSaving { ProgressView().tint(.white) } else { Text("Enregistrer") }
            }
            .buttonStyle(.boardlyPrimary)
            .padding(.top, 4)

            Button("Envoyer un e-mail de test") {
                Task { await viewModel.sendTest() }
            }
            .buttonStyle(.boardlySecondary)
        }
        .padding(20)
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String,
                       url: Bool = false, number: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            BoardlyFieldLabel(label)
            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(number ? .numberPad : (url ? .URL : .default))
                .boardlyField()
        }
    }
}
