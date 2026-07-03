import BoardlyKit
import PhotosUI
import SwiftUI

/// "Modifier le projet" — a 4-tab editor sheet, shown from the project hero's
/// pencil (managers only). Tabs: Général · Responsables · Arrière-plan · Champs perso.
struct EditProjectSheet: View {
    let viewModel: ProjectDetailViewModel
    let client: PlankaClient
    let onDeleted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var tab: EditTab

    init(viewModel: ProjectDetailViewModel, client: PlankaClient,
         initialTab: EditTab = .general, onDeleted: @escaping () -> Void) {
        self.viewModel = viewModel
        self.client = client
        self.onDeleted = onDeleted
        _tab = State(initialValue: initialTab)
    }

    enum EditTab: String, CaseIterable, Identifiable {
        case general = "Général"
        case managers = "Responsables"
        case background = "Arrière-plan"
        case customFields = "Champs perso"
        var id: String { rawValue }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            ScrollView {
                Group {
                    switch tab {
                    case .general:
                        GeneralTab(viewModel: viewModel, client: client, onDeleted: onDeleted, dismiss: { dismiss() })
                    case .managers:
                        ManagersTab(viewModel: viewModel, client: client)
                    case .background:
                        BackgroundTab(viewModel: viewModel, client: client)
                    case .customFields:
                        CustomFieldsTab(viewModel: viewModel, client: client)
                    }
                }
                .padding(20)
            }
        }
        .background(Color.boardlyBackground)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(26)
    }

    private var header: some View {
        HStack {
            Text("Modifier le projet")
                .font(.sans(20, .bold))
                .foregroundStyle(Color.boardlyInk)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.boardlyTextSecondary)
                    .padding(8)
                    .background(Color.boardlySurfaceSecondary, in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 22)
        .padding(.bottom, 12)
    }

    private var tabBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(EditTab.allCases) { item in
                    let active = tab == item
                    Button { tab = item } label: {
                        Text(item.rawValue)
                            .font(.sans(14, .semibold))
                            .foregroundStyle(active ? .white : Color.boardlyTextSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(active ? Color.accentColor : Color.boardlySurfaceSecondary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)
        }
    }
}

// MARK: - Général

private struct GeneralTab: View {
    let viewModel: ProjectDetailViewModel
    let client: PlankaClient
    let onDeleted: () -> Void
    let dismiss: () -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var isHidden = false
    @State private var isSaving = false
    @State private var seeded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let error = viewModel.error {
                Text(error).font(.boardlyCallout).foregroundStyle(Color.labelRose)
            }

            BoardlyFieldLabel("Titre")
            TextField("Titre du projet", text: $name).boardlyField()

            BoardlyFieldLabel("Description")
            TextField("Description", text: $description, axis: .vertical)
                .lineLimit(3 ... 6)
                .boardlyField()

            Button {
                Task {
                    isSaving = true
                    let ok = await viewModel.saveGeneral(name: name, description: description, using: client)
                    isSaving = false
                    if ok { dismiss() }
                }
            } label: {
                if isSaving { ProgressView().tint(.white) } else { Text("Sauvegarder") }
            }
            .buttonStyle(.boardlyPrimary)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)

            sectionSeparator("Affichage")

            Toggle(isOn: $isHidden) {
                Text("Masquer de la liste des projets et des favoris")
                    .font(.boardlyBody)
                    .foregroundStyle(Color.boardlyInk)
            }
            .tint(.accentColor)
            .onChange(of: isHidden) { _, newValue in
                Task { await viewModel.setHidden(newValue, using: client) }
            }

            sectionSeparator("Zone dangereuse")
            dangerZone
        }
        // Seed from the project once it's available (it may still be loading when
        // the sheet opens); `.task(id:)` re-runs when the id goes nil → loaded.
        .task(id: viewModel.project?.id) {
            guard !seeded, let project = viewModel.project else { return }
            seeded = true
            name = project.name
            description = project.description ?? ""
            isHidden = project.isHidden
        }
    }

    @ViewBuilder
    private var dangerZone: some View {
        if viewModel.hasBoards {
            Text("Supprimez tous les tableaux pour pouvoir supprimer ce projet.")
                .font(.boardlyCallout)
                .foregroundStyle(Color.labelRose)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.labelRose.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            Button(role: .destructive) {
                Task {
                    if await viewModel.deleteProject(using: client) {
                        dismiss()
                        onDeleted()
                    }
                }
            } label: {
                Text("Supprimer le projet")
                    .font(.sans(15, .semibold))
                    .foregroundStyle(Color.labelRose)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.labelRose.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

// MARK: - Responsables

private struct ManagersTab: View {
    let viewModel: ProjectDetailViewModel
    let client: PlankaClient

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let error = viewModel.error {
                Text(error).font(.boardlyCallout).foregroundStyle(Color.labelRose)
            }

            BoardlyFieldLabel("Responsables · \(viewModel.managerUsers.count)")

            ForEach(viewModel.managers, id: \.id) { manager in
                let user = viewModel.user(manager.userId)
                HStack(spacing: 12) {
                    AvatarView(name: user?.name ?? "?", size: 40, bordered: false)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(user?.name ?? "Utilisateur")
                            .font(.sans(15, .semibold))
                            .foregroundStyle(Color.boardlyInk)
                        Text(viewModel.isMe(manager.userId) ? "Responsable · vous" : "Responsable")
                            .font(.boardlyCallout)
                            .foregroundStyle(Color.boardlyTextSecondary)
                    }
                    Spacer(minLength: 8)
                    if viewModel.managers.count > 1 {
                        Button {
                            Task { await viewModel.removeManager(manager, using: client) }
                        } label: {
                            Image(systemName: "xmark").foregroundStyle(Color.boardlyTextTertiary)
                        }
                    }
                }
                .padding(14)
                .boardlyCard(padding: 0)
            }

            Menu {
                let candidates = viewModel.addableUsers()
                if candidates.isEmpty {
                    Text("Aucun membre à ajouter")
                } else {
                    ForEach(candidates, id: \.id) { user in
                        Button(user.name) {
                            Task { await viewModel.addManager(userId: user.id, using: client) }
                        }
                    }
                }
            } label: {
                Label("Ajouter un responsable", systemImage: "plus")
                    .font(.sans(15, .semibold))
                    .foregroundStyle(Color.boardlyInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(Color.boardlySeparator)
                    )
            }

            sectionSeparator("Zone dangereuse")
            Text("Un seul responsable doit rester pour rendre ce projet privé.")
                .font(.boardlyCallout)
                .foregroundStyle(Color.labelRose)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color.labelRose.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

// MARK: - Arrière-plan

private struct BackgroundTab: View {
    let viewModel: ProjectDetailViewModel
    let client: PlankaClient
    @State private var photoItem: PhotosPickerItem?
    @State private var isUploading = false

    private let columns = [GridItem(.adaptive(minimum: 68), spacing: 12)]

    private var currentGradient: String? {
        viewModel.project?.backgroundType == "gradient" ? viewModel.project?.backgroundGradient : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let error = viewModel.error {
                Text(error).font(.boardlyCallout).foregroundStyle(Color.labelRose)
            }

            BoardlyFieldLabel("Aperçu")
            preview

            BoardlyFieldLabel("Dégradés")
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(PlankaGradient.names, id: \.self) { gradientName in
                    Button {
                        Task { await viewModel.setGradient(gradientName, using: client) }
                    } label: {
                        PlankaGradient.linear(gradientName)
                            .frame(height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.accentColor, lineWidth: currentGradient == gradientName ? 3 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            BoardlyFieldLabel("Image")
            PhotosPicker(selection: $photoItem, matching: .images) {
                Label("Importer une image", systemImage: "square.and.arrow.up")
                    .font(.sans(15, .semibold))
                    .foregroundStyle(Color.boardlyInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(Color.boardlySeparator)
                    )
            }

            if viewModel.project?.backgroundType != nil {
                Button {
                    Task { await viewModel.clearBackground(using: client) }
                } label: {
                    Text("Aucun arrière-plan")
                        .font(.boardlyCallout)
                        .foregroundStyle(Color.boardlyTextSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
        }
        .overlay {
            if isUploading {
                ZStack { Color.black.opacity(0.12).ignoresSafeArea(); ProgressView().tint(Color.boardlyInk) }
            }
        }
        .task(id: photoItem) {
            guard let item = photoItem else { return }
            isUploading = true
            defer { isUploading = false }
            photoItem = nil
            if let data = try? await item.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data),
               let jpeg = uiImage.jpegData(compressionQuality: 0.9) {
                _ = await viewModel.uploadImage(data: jpeg, fileName: "background.jpg", mimeType: "image/jpeg", using: client)
            } else {
                viewModel.error = "Image illisible."
            }
        }
    }

    @ViewBuilder
    private var preview: some View {
        ZStack(alignment: .bottomLeading) {
            previewBackground
            LinearGradient(colors: [.clear, .black.opacity(0.3)], startPoint: .center, endPoint: .bottom)
            Text(viewModel.project?.name ?? "Projet")
                .font(.sans(17, .bold))
                .foregroundStyle(.white)
                .padding(14)
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var previewBackground: some View {
        if viewModel.project?.backgroundType == "image",
           let image = viewModel.currentBackgroundImage,
           let url = client.resourceURL(image.url) {
            BackgroundImageView(url: url) { await client.imageData(url: $0) }
        } else if let gradient = currentGradient {
            PlankaGradient.linear(gradient)
        } else if let id = viewModel.project?.id {
            projectColor(id)
        } else {
            Color.boardlySurfaceSecondary
        }
    }
}

// MARK: - Champs perso de base

private struct CustomFieldsTab: View {
    let viewModel: ProjectDetailViewModel
    let client: PlankaClient

    @State private var showAddGroup = false
    @State private var newGroupName = ""
    @State private var addFieldGroup: BaseCustomFieldGroup?
    @State private var newFieldName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Groupes de champs réutilisables, hérités par tous les tableaux du projet.")
                .font(.boardlyCallout)
                .foregroundStyle(Color.boardlyTextSecondary)

            if let error = viewModel.error {
                Text(error).font(.boardlyCallout).foregroundStyle(Color.labelRose)
            }

            ForEach(viewModel.baseGroups, id: \.id) { group in
                groupCard(group)
            }

            Button { showAddGroup = true } label: {
                Label("Ajouter un groupe", systemImage: "plus")
                    .font(.sans(15, .semibold))
                    .foregroundStyle(Color.boardlyInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            .foregroundStyle(Color.boardlySeparator)
                    )
            }
        }
        .alert("Nouveau groupe", isPresented: $showAddGroup) {
            TextField("Nom du groupe", text: $newGroupName)
            Button("Ajouter") {
                let name = newGroupName.trimmingCharacters(in: .whitespaces)
                newGroupName = ""
                guard !name.isEmpty else { return }
                Task { await viewModel.addGroup(name: name, using: client) }
            }
            Button("Annuler", role: .cancel) { newGroupName = "" }
        }
        .alert("Nouveau champ", isPresented: Binding(get: { addFieldGroup != nil }, set: { if !$0 { addFieldGroup = nil } })) {
            TextField("Nom du champ", text: $newFieldName)
            Button("Ajouter") {
                let name = newFieldName.trimmingCharacters(in: .whitespaces)
                let group = addFieldGroup
                newFieldName = ""
                addFieldGroup = nil
                guard !name.isEmpty, let group else { return }
                Task { await viewModel.addField(to: group, name: name, using: client) }
            }
            Button("Annuler", role: .cancel) { newFieldName = ""; addFieldGroup = nil }
        }
    }

    private func groupCard(_ group: BaseCustomFieldGroup) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(group.name)
                    .font(.sans(16, .bold))
                    .foregroundStyle(Color.boardlyInk)
                Spacer()
                Menu {
                    Button { addFieldGroup = group } label: { Label("Ajouter un champ", systemImage: "plus") }
                    Button(role: .destructive) {
                        Task { await viewModel.deleteGroup(group, using: client) }
                    } label: { Label("Supprimer le groupe", systemImage: "trash") }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.boardlyTextSecondary)
                        .frame(width: 30, height: 30)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            let fields = viewModel.fields(in: group)
            if fields.isEmpty {
                Text("Aucun champ")
                    .font(.boardlyCallout)
                    .foregroundStyle(Color.boardlyTextTertiary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            } else {
                ForEach(fields, id: \.id) { field in
                    HStack {
                        Text(field.name)
                            .font(.boardlyBody)
                            .foregroundStyle(Color.boardlyInk)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
                .padding(.bottom, 6)
            }
        }
        .boardlyCard(padding: 0)
    }
}

// MARK: - Shared

/// A centered uppercase mono section divider (e.g. "AFFICHAGE", "ZONE DANGEREUSE").
private func sectionSeparator(_ title: String) -> some View {
    HStack(spacing: 12) {
        Rectangle().fill(Color.boardlySeparator).frame(height: 1)
        Text(title)
            .font(.boardlyMonoLabel)
            .tracking(1.5)
            .textCase(.uppercase)
            .foregroundStyle(Color.boardlyTextTertiary)
            .fixedSize()
        Rectangle().fill(Color.boardlySeparator).frame(height: 1)
    }
    .padding(.vertical, 4)
}
