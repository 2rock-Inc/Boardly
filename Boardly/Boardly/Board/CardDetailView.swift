import SwiftUI
import BoardlyKit

struct CardDetailView: View {
    let cardId: String
    @Bindable var boardVM: BoardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var editedDescription = ""
    @State private var newTaskName = ""
    @State private var addingTaskInListId: String?
    @FocusState private var taskFieldFocused: Bool
    @State private var didSeedEditState = false
    @State private var showLabelsSheet = false
    @State private var showMembersSheet = false
    @State private var showDueDateSheet = false

    private var card: Card? { boardVM.payload?.card(id: cardId) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.boardlyBackground.ignoresSafeArea()

            if let card, let payload = boardVM.payload {
                content(card: card, payload: payload)
                closeButton
            } else {
                ProgressView().tint(.accentColor)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showLabelsSheet) {
            CardLabelsSheet(cardId: cardId, boardVM: boardVM)
        }
        .sheet(isPresented: $showMembersSheet) {
            CardMembersSheet(cardId: cardId, boardVM: boardVM)
        }
        .sheet(isPresented: $showDueDateSheet) {
            CardDueDateSheet(cardId: cardId, boardVM: boardVM)
        }
        .alert("Couldn’t save card", isPresented: Binding(
            get: { boardVM.error != nil },
            set: { if !$0 { boardVM.error = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(boardVM.error ?? "")
        }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.black.opacity(0.3), in: Circle())
        }
        .padding(.leading, 16)
        .padding(.top, 12)
    }

    // MARK: - Content

    private func content(card: Card, payload: BoardPayload) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                coverHero(card: card)

                VStack(alignment: .leading, spacing: 20) {
                    let cardLabels = payload.labels(for: card)
                    if !cardLabels.isEmpty { labelRow(cardLabels) }

                    titleField(card: card)
                    metaSubtitle(card: card, payload: payload)

                    let cardMembers = payload.members(for: card)
                    if !cardMembers.isEmpty {
                        HStack(spacing: -8) {
                            ForEach(cardMembers) { user in
                                AvatarView(name: user.name, size: 30)
                            }
                        }
                    }

                    quickActions(card: card)

                    if let due = card.dueDate {
                        Button { showDueDateSheet = true } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                Text(due.formatted(.dateTime.weekday().day().month().hour().minute()))
                                    .font(.boardlyCallout)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(due < Date() ? Color.labelRose : Color.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.boardlySeparator, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    descriptionSection(card: card)

                    ForEach(payload.taskLists(for: card)) { taskList in
                        taskListSection(taskList: taskList, payload: payload)
                    }

                    commentsSection(card: card)
                    moveSection(card: card, payload: payload)
                    deleteButton(card: card)
                }
                .padding(20)
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .onAppear {
            guard !didSeedEditState else { return }
            didSeedEditState = true
            editedDescription = card.description ?? ""
        }
    }

    // MARK: - Cover (Phase 4 wires a real cover image; placeholder hero for now)

    private func coverHero(card: Card) -> some View {
        LinearGradient(
            colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .frame(height: 180)
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "rectangle.stack")
                .font(.system(size: 64, weight: .light))
                .foregroundStyle(.white.opacity(0.18))
                .padding(20)
        }
    }

    // MARK: - Labels

    private func labelRow(_ labels: [BoardlyKit.Label]) -> some View {
        HStack(spacing: 6) {
            ForEach(labels) { label in
                Text(label.name ?? "•")
                    .font(.boardlyMonoLabel)
                    .textCase(.uppercase)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(plankaLabel: label.color), in: Capsule())
            }
        }
    }

    // MARK: - Title

    @ViewBuilder
    private func titleField(card: Card) -> some View {
        if isEditingName {
            TextField("Titre de la carte", text: $editedName, axis: .vertical)
                .font(.boardlyTitle)
                .foregroundStyle(Color.boardlyInk)
                .onSubmit { saveCardName(card: card) }
                .submitLabel(.done)
        } else {
            Text(card.name)
                .font(.boardlyTitle)
                .foregroundStyle(Color.boardlyInk)
                .onTapGesture {
                    editedName = card.name
                    isEditingName = true
                }
        }
    }

    private func metaSubtitle(card: Card, payload: BoardPayload) -> some View {
        let listName = payload.sortedLists().first { $0.id == card.listId }?.name ?? "—"
        var parts = ["dans \(listName)"]
        if let created = card.createdAt {
            parts.append("créée \(created.formatted(.relative(presentation: .named)))")
        }
        return Text(parts.joined(separator: " · "))
            .font(.boardlyMonoCaption)
            .foregroundStyle(Color.boardlyTextSecondary)
    }

    // MARK: - Quick actions (Échéance functional; others land in Phase 4)

    private func quickActions(card: Card) -> some View {
        HStack(spacing: 8) {
            quickAction("Membres", systemImage: "person.2", enabled: true) {
                showMembersSheet = true
            }
            quickAction("Échéance", systemImage: "calendar", enabled: true) {
                showDueDateSheet = true
            }
            quickAction("Label", systemImage: "tag", enabled: true) {
                showLabelsSheet = true
            }
            quickAction("Joindre", systemImage: "paperclip", enabled: false) {}
        }
    }

    private func quickAction(_ title: String, systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                Text(title)
                    .font(.boardlyMonoLabel)
            }
            .foregroundStyle(enabled ? Color.accentColor : Color.boardlyTextTertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.boardlySeparator, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.5)
    }

    // MARK: - Description

    private func descriptionSection(card: Card) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BoardlyFieldLabel("Description")
            ZStack(alignment: .topLeading) {
                if editedDescription.isEmpty {
                    Text("Ajouter une description…")
                        .font(.boardlyBody)
                        .foregroundStyle(Color.boardlyTextTertiary)
                        .padding(.top, 8)
                        .padding(.leading, 4)
                }
                TextEditor(text: $editedDescription)
                    .font(.boardlyBody)
                    .foregroundStyle(Color.boardlyInk)
                    .frame(minHeight: 80)
                    .scrollContentBackground(.hidden)
            }
            if editedDescription != (card.description ?? "") {
                Button("Enregistrer") { saveDescription(card: card) }
                    .font(.boardlyCallout)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .boardlyCard()
    }

    // MARK: - Tasks

    private func taskListSection(taskList: TaskList, payload: BoardPayload) -> some View {
        let tasks = payload.tasks(for: taskList)
        let completed = tasks.filter(\.isCompleted).count
        let progress = tasks.isEmpty ? 0 : Double(completed) / Double(tasks.count)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(taskList.name)
                    .font(.boardlyHeadline)
                    .foregroundStyle(Color.boardlyInk)
                Spacer()
                Text("\(completed)/\(tasks.count)")
                    .font(.mono(12, .medium))
                    .foregroundStyle(Color.boardlyTextSecondary)
            }

            if !tasks.isEmpty {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.boardlySurfaceSecondary)
                        Capsule().fill(Color.accentColor)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 5)
            }

            ForEach(tasks) { task in
                HStack(spacing: 12) {
                    Button { Task { await boardVM.toggleTask(task) } } label: {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isCompleted ? Color.labelGreen : Color.boardlyTextTertiary)
                            .font(.system(size: 20))
                    }
                    .buttonStyle(.plain)

                    Text(task.name)
                        .font(.boardlyBody)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? Color.boardlyTextSecondary : Color.boardlyInk)

                    Spacer(minLength: 0)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await boardVM.deleteTask(task) }
                    } label: { SwiftUI.Label("Supprimer", systemImage: "trash") }
                }
            }

            if addingTaskInListId == taskList.id {
                HStack(spacing: 12) {
                    Image(systemName: "circle").foregroundStyle(Color.boardlyTextTertiary).font(.system(size: 20))
                    TextField("Nouvelle tâche", text: $newTaskName)
                        .font(.boardlyBody)
                        .focused($taskFieldFocused)
                        .onSubmit { submitTask(taskList: taskList) }
                }
            }

            Button {
                addingTaskInListId = taskList.id
                newTaskName = ""
                taskFieldFocused = true
            } label: {
                SwiftUI.Label("Ajouter une tâche", systemImage: "plus")
                    .font(.boardlyCallout)
                    .foregroundStyle(Color.boardlyTextSecondary)
            }
        }
        .boardlyCard()
    }

    // MARK: - Comments (read-only count for now; full thread arrives in Phase 4)

    private func commentsSection(card: Card) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Commentaires")
                    .font(.boardlyHeadline)
                    .foregroundStyle(Color.boardlyInk)
                Spacer()
                Text("\(card.commentsTotal ?? 0)")
                    .font(.mono(12, .medium))
                    .foregroundStyle(Color.boardlyTextSecondary)
            }
            HStack(spacing: 10) {
                Image(systemName: "bubble.left")
                    .foregroundStyle(Color.boardlyTextTertiary)
                Text("Les commentaires arrivent en Phase 4.")
                    .font(.boardlyCallout)
                    .foregroundStyle(Color.boardlyTextTertiary)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
        }
        .boardlyCard()
    }

    // MARK: - Move / Delete

    private func moveSection(card: Card, payload: BoardPayload) -> some View {
        let otherLists = payload.sortedLists().filter { $0.id != card.listId }
        return VStack(alignment: .leading, spacing: 12) {
            BoardlyFieldLabel("Déplacer vers")
            ForEach(otherLists) { list in
                Button {
                    Task { await boardVM.moveCard(card, to: list) }
                } label: {
                    HStack {
                        SwiftUI.Label(list.name ?? "Sans titre", systemImage: "arrow.right")
                            .font(.boardlyBody)
                            .foregroundStyle(Color.boardlyInk)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .boardlyCard()
    }

    private func deleteButton(card: Card) -> some View {
        Button(role: .destructive) {
            Task {
                await boardVM.deleteCard(card)
                dismiss()
            }
        } label: {
            SwiftUI.Label("Supprimer la carte", systemImage: "trash")
                .font(.sans(15, .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.labelRose, in: Capsule())
        }
    }

    // MARK: - Helpers & actions

    private func saveCardName(card: Card) {
        let name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != card.name else { isEditingName = false; return }
        Task {
            await boardVM.updateCard(card, patch: CardPatch(name: name))
            isEditingName = false
        }
    }

    private func saveDescription(card: Card) {
        Task { await boardVM.updateCard(card, patch: CardPatch(description: editedDescription)) }
    }

    private func submitTask(taskList: TaskList) {
        let name = newTaskName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            Task { await boardVM.createTask(in: taskList, name: name) }
        }
        newTaskName = ""
        addingTaskInListId = nil
    }
}
