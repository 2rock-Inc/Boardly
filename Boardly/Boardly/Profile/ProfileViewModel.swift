import Foundation
import BoardlyKit

@Observable
@MainActor
final class ProfileViewModel {
    private let client: PlankaClient
    var user: User?
    var services: [NotificationService] = []
    var plankaVersion: String?
    var isLoading = false
    var error: String?

    init(client: PlankaClient) {
        self.client = client
    }

    var isAdmin: Bool { user?.role == "admin" }

    func load() async {
        isLoading = true
        error = nil
        defer { isLoading = false }
        do {
            let payload = try await client.getCurrentUser()
            user = payload.user
            services = payload.notificationServices
        } catch {
            self.error = "Impossible de charger le profil."
        }
        // Best-effort, fetched once per session — used only for the version footer.
        if plankaVersion == nil {
            plankaVersion = try? await client.validateInstance().version
        }
    }

    // MARK: - Preferences

    var homeView: HomeViewOption { .from(user?.defaultHomeView) }
    var editorMode: EditorModeOption { .from(user?.defaultEditorMode) }

    func setHomeView(_ option: HomeViewOption) {
        updatePreference(UserPatch(defaultHomeView: option.rawValue))
    }

    func setEditorMode(_ option: EditorModeOption) {
        updatePreference(UserPatch(defaultEditorMode: option.rawValue))
    }

    private var prefTask: Task<Void, Never>?

    /// Apply a preference PATCH. Rapid toggles cancel the in-flight request so the
    /// last selection wins (out-of-order responses can't overwrite the newer one).
    private func updatePreference(_ patch: UserPatch) {
        error = nil
        prefTask?.cancel()
        prefTask = Task {
            do {
                let updated = try await client.updateCurrentUser(patch: patch)
                if !Task.isCancelled { user = updated }
            } catch is CancellationError {
                // Superseded by a newer toggle — ignore.
            } catch {
                if !Task.isCancelled { self.error = "Impossible d’enregistrer la préférence." }
            }
        }
    }

    // MARK: - Notification services (user-scoped)

    func addService(url: String, format: String) async {
        guard let userId = user?.id else { return }
        do {
            let service = try await client.createUserNotificationService(userId: userId, url: url, format: format)
            services.append(service)
        } catch {
            self.error = "Impossible d’ajouter le service."
        }
    }

    func updateService(id: String, url: String, format: String) async {
        do {
            let updated = try await client.updateNotificationService(id: id, url: url, format: format)
            if let index = services.firstIndex(where: { $0.id == id }) { services[index] = updated }
        } catch {
            self.error = "Impossible de modifier le service."
        }
    }

    func deleteService(_ service: NotificationService) async {
        let previous = services
        services.removeAll { $0.id == service.id }
        do {
            try await client.deleteNotificationService(id: service.id)
        } catch {
            services = previous
            self.error = "Impossible de supprimer le service."
        }
    }

    /// Send a test notification. Returns whether it was accepted.
    func testService(_ service: NotificationService) async -> Bool {
        do {
            try await client.testNotificationService(id: service.id)
            return true
        } catch {
            self.error = "Échec de l’envoi du test."
            return false
        }
    }
}
