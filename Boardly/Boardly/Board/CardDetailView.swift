import BoardlyKit
import SwiftUI
import UIKit

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
    @State private var showAttachmentsSheet = false
    @State private var showCustomFieldsSheet = false
    @State private var comments: [Comment] = []
    @State private var commentsLoaded = false
    @State private var newComment = ""
    @State private var actions: [Action] = []
    @State private var topInset: CGFloat = 0

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
        .background {
            GeometryReader { proxy in
                Color.clear
                    .onAppear { topInset = proxy.safeAreaInsets.top }
                    .onChange(of: proxy.safeAreaInsets.top) { _, new in topInset = new }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if card != nil { commentInputBar }
        }
        .task {
            if let loaded = await boardVM.loadComments(cardId: cardId) {
                comments = loaded
                commentsLoaded = true
            }
            actions = await boardVM.loadActions(cardId: cardId)
        }
        .sheet(isPresented: $showLabelsSheet) {
            CardLabelsSheet(cardId: cardId, boardVM: boardVM)
        }
        .sheet(isPresented: $showMembersSheet) {
            CardMembersSheet(cardId: cardId, boardVM: boardVM)
        }
        .sheet(isPresented: $showDueDateSheet) {
            CardDueDateSheet(cardId: cardId, boardVM: boardVM)
        }
        .sheet(isPresented: $showAttachmentsSheet) {
            CardAttachmentsSheet(cardId: cardId, boardVM: boardVM)
        }
        .sheet(isPresented: $showCustomFieldsSheet) {
            CardCustomFieldsSheet(cardId: cardId, boardVM: boardVM)
        }
        .alert("Couldn’t save card", isPresented: Binding(
            get: { boardVM.error != nil },
            set: { if !$0 { boardVM.error = nil } }))
        {
            Button("OK", role: .cancel) {}
        } message: {
            Text(boardVM.error ?? "")
        }
    }

    private var closeButton: some View {
        Button { dismiss() } label: {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Color.boardlyInk)
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.9), in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
        .padding(.leading, 16)
        .padding(.top, 12)
    }

    // MARK: - Content

    private func content(card: Card, payload: BoardPayload) -> some View {
        let hasCover = card.coverAttachmentId != nil
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if hasCover {
                    coverHero(url: coverImageURL(card: card, payload: payload))
                }

                VStack(alignment: .leading, spacing: 20) {
                    labelRow(payload.labels(for: card))

                    VStack(alignment: .leading, spacing: 5) {
                        titleField(card: card)
                        metaSubtitle(card: card, payload: payload)
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
                            .foregroundStyle(due < Date() ? Color.boardlyDestructive : Color.accentColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.boardlySeparator, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain)
                    }

                    chronoSection(card: card)

                    descriptionSection(card: card)

                    let cardAttachments = payload.attachments(for: card)
                    if !cardAttachments.isEmpty {
                        attachmentsSection(cardAttachments)
                    }

                    customFieldsSection(card: card, payload: payload)

                    ForEach(payload.taskLists(for: card)) { taskList in
                        taskListSection(taskList: taskList, payload: payload)
                    }

                    commentsSection(card: card)
                    if !actions.isEmpty { activitySection(payload: payload) }
                    moveSection(card: card, payload: payload)
                    deleteButton(card: card)
                }
                .padding(20)
            }
        }
        .ignoresSafeArea(edges: hasCover ? .top : [])
        .scrollDismissesKeyboard(.immediately)
        .onAppear {
            guard !didSeedEditState else { return }
            didSeedEditState = true
            editedDescription = card.description ?? ""
        }
    }

    // MARK: - Cover (shown only when the card has a cover attachment)

    private func coverHero(url: URL?) -> some View {
        CoverImageView(url: url, height: 180 + topInset) { await boardVM.loadImage(url: $0) }
    }

    /// The card's cover image URL, resolved from its cover attachment (if set).
    private func coverImageURL(card: Card, payload: BoardPayload) -> URL? {
        guard let coverId = card.coverAttachmentId,
              let attachment = payload.attachments.first(where: { $0.id == coverId }),
              let data = try? JSONEncoder().encode(attachment.data),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let urlString = (obj["url"] as? String)
            ?? ((obj["image"] as? [String: Any])?["url"] as? String)
            ?? ((obj["thumbnailUrls"] as? [String: Any])?["outside360"] as? String)
        return urlString.flatMap(URL.init(string:))
    }

    // MARK: - Labels

    private func labelRow(_ labels: [BoardlyKit.Label]) -> some View {
        HStack(spacing: 6) {
            ForEach(labels) { label in
                Button { showLabelsSheet = true } label: {
                    Text(label.name ?? "•")
                        .font(.sans(12, .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Color(plankaLabel: label.color), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            Button { showLabelsSheet = true } label: {
                Text("+ Label")
                    .font(.sans(12, .semibold))
                    .foregroundStyle(Color.boardlyTextTertiary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .stroke(Color.boardlySeparator, style: StrokeStyle(lineWidth: 1, dash: [3, 2])))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Title

    @ViewBuilder
    private func titleField(card: Card) -> some View {
        if isEditingName {
            TextField("Card title", text: $editedName, axis: .vertical)
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
        let creator = card.creatorUserId.flatMap { id in payload.users.first { $0.id == id } }

        // Build with AttributedString (plain runs) so untrusted list/user names are
        // never parsed as markdown; only the list name is bolded programmatically.
        var text = AttributedString("in ")
        var name = AttributedString(listName)
        name.font = .sans(13, .bold)
        text.append(name)
        if let creator { text.append(AttributedString(" · created by \(creator.name)")) }
        if let created = card.createdAt {
            text.append(AttributedString(" · \(created.formatted(.relative(presentation: .named)))"))
        }
        return Text(text)
            .font(.sans(13, .regular))
            .foregroundStyle(Color.boardlyTextSecondary)
    }

    // MARK: - Quick actions (Due date functional; others land in Phase 4)

    private func quickActions(card _: Card) -> some View {
        HStack(spacing: 8) {
            quickAction("Members", systemImage: "person.2") { showMembersSheet = true }
            quickAction("Due date", systemImage: "calendar") { showDueDateSheet = true }
            quickAction("Attach", systemImage: "paperclip") { showAttachmentsSheet = true }
        }
    }

    private func quickAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                Text(title)
                    .font(.sans(14, .semibold))
                    .foregroundStyle(Color.boardlyInk)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.boardlySeparator, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Description

    private func descriptionSection(card: Card) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            BoardlyFieldLabel("Description")
            ZStack(alignment: .topLeading) {
                if editedDescription.isEmpty {
                    Text("Add a description…")
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
                Button("Save") { saveDescription(card: card) }
                    .font(.boardlyCallout)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .boardlyCard()
    }

    // MARK: - Tasks

    private func attachmentsSection(_ attachments: [Attachment]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            BoardlyFieldLabel("Attachments")
            VStack(spacing: 0) {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                    HStack(spacing: 12) {
                        Image(systemName: attachment.type == "link" ? "link" : "paperclip")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 32, height: 32)
                            .background(Color.boardlySurfaceSecondary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        Text(attachment.name)
                            .font(.boardlyCallout)
                            .foregroundStyle(Color.boardlyInk)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 6)
                    if index < attachments.count - 1 { Divider() }
                }
            }
        }
        .boardlyCard()
    }

    // MARK: - Custom fields (Phase 7)

    @ViewBuilder
    private func customFieldsSection(card: Card, payload: BoardPayload) -> some View {
        let groups = payload.customFieldGroups(for: card).filter { !payload.fields(in: $0).isEmpty }
        if !groups.isEmpty {
            Button { showCustomFieldsSheet = true } label: {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 6) {
                        Image(systemName: "square.grid.2x2").font(.boardlyMonoLabel)
                        BoardlyFieldLabel("Custom Fields")
                        Spacer(minLength: 0)
                    }
                    ForEach(groups) { group in
                        let fields = payload.fields(in: group)
                        VStack(alignment: .leading, spacing: 0) {
                            if let name = group.name, !name.isEmpty {
                                Text(name)
                                    .font(.boardlyCaption)
                                    .foregroundStyle(Color.boardlyTextSecondary)
                                    .padding(.bottom, 8)
                            }
                            ForEach(Array(fields.enumerated()), id: \.element.id) { index, field in
                                HStack(spacing: 12) {
                                    Text(field.name)
                                        .font(.sans(14, .semibold))
                                        .foregroundStyle(Color.boardlyInk)
                                    Spacer(minLength: 8)
                                    fieldValue(card: card, group: group, field: field, payload: payload)
                                }
                                .padding(.vertical, 9)
                                if index < fields.count - 1 { Divider() }
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            .boardlyCard()
        }
    }

    @ViewBuilder
    private func fieldValue(card: Card, group: CustomFieldGroup, field: CustomField, payload: BoardPayload) -> some View {
        if let content = payload.value(on: card, group: group, field: field)?.content,
           !content.isEmpty
        {
            Text(content)
                .font(.sans(14, .semibold))
                .foregroundStyle(Color.boardlyInk)
                .lineLimit(1)
                .multilineTextAlignment(.trailing)
        } else {
            Text("Empty")
                .font(.boardlyCallout)
                .italic()
                .foregroundStyle(Color.boardlyTextTertiary)
        }
    }

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
                    } label: { SwiftUI.Label("Delete", systemImage: "trash") }
                }
            }

            if addingTaskInListId == taskList.id {
                HStack(spacing: 12) {
                    Image(systemName: "circle").foregroundStyle(Color.boardlyTextTertiary).font(.system(size: 20))
                    TextField("New task", text: $newTaskName)
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
                SwiftUI.Label("Add a task", systemImage: "plus")
                    .font(.boardlyCallout)
                    .foregroundStyle(Color.boardlyTextSecondary)
            }
        }
        .boardlyCard()
    }

    // MARK: - Comments (read-only count for now; full thread arrives in Phase 4)

    private func chronoSection(card: Card) -> some View {
        let sw = card.stopwatchValue
        let running = sw?.isRunning ?? false
        return HStack(spacing: 12) {
            Image(systemName: "stopwatch")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.accentColor)
            Text("Timer")
                .font(.boardlyHeadline)
                .foregroundStyle(Color.boardlyInk)
            Spacer(minLength: 0)
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Text(formatDuration(sw?.elapsed(now: context.date) ?? 0))
                    .font(.mono(16, .medium))
                    .foregroundStyle(running ? Color.accentColor : Color.boardlyTextSecondary)
            }
            Button { Task { await boardVM.toggleStopwatch(card) } } label: {
                Image(systemName: running ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .boardlyCard()
    }

    private func formatDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d:%02d", seconds / 3600, (seconds % 3600) / 60, seconds % 60)
    }

    private func activitySection(payload: BoardPayload) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.boardlyTextSecondary)
                Text("Activity")
                    .font(.boardlyHeadline)
                    .foregroundStyle(Color.boardlyInk)
                Spacer(minLength: 0)
            }
            ForEach(actions) { action in
                let author = payload.users.first { $0.id == action.userId }
                HStack(alignment: .top, spacing: 10) {
                    AvatarView(name: author?.name ?? "?", size: 28, bordered: false)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(actionText(action, author: author))
                            .font(.boardlyCallout)
                            .foregroundStyle(Color.boardlyInk)
                        if let date = action.createdAt {
                            Text(date.formatted(.relative(presentation: .named)))
                                .font(.boardlyMonoCaption)
                                .foregroundStyle(Color.boardlyTextTertiary)
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func actionText(_ action: Action, author: User?) -> String {
        let who = author?.name ?? "Someone"
        switch action.type {
        case "createCard": return "\(who) created the card"
        case "moveCard": return "\(who) moved the card"
        case "addMemberToCard": return "\(who) added a member"
        case "removeMemberFromCard": return "\(who) removed a member"
        case "completeTask": return "\(who) completed a task"
        case "uncompleteTask": return "\(who) reopened a task"
        default: return "\(who) updated the card"
        }
    }

    private func commentsSection(card: Card) -> some View {
        let count = commentsLoaded ? comments.count : (card.commentsTotal ?? 0)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.boardlyTextSecondary)
                Text("Comments · \(count)")
                    .font(.boardlyHeadline)
                    .foregroundStyle(Color.boardlyInk)
                Spacer(minLength: 0)
            }

            if commentsLoaded, comments.isEmpty {
                Text("No comments yet.")
                    .font(.boardlyCallout)
                    .foregroundStyle(Color.boardlyTextTertiary)
            } else {
                ForEach(comments) { comment in
                    CommentBubble(
                        comment: comment,
                        author: boardVM.payload?.users.first { $0.id == comment.userId },
                        onDelete: {
                            Task {
                                if await boardVM.deleteComment(id: comment.id, cardId: cardId) {
                                    comments.removeAll { $0.id == comment.id }
                                }
                            }
                        })
                }
            }
        }
    }

    private var commentInputBar: some View {
        HStack(spacing: 10) {
            if let user = boardVM.currentUser {
                AvatarView(name: user.name, size: 32, bordered: false)
            }
            TextField("Add a comment…", text: $newComment, axis: .vertical)
                .font(.boardlyBody)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Color.boardlySurfaceSecondary, in: Capsule())
            Button { sendComment() } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor, in: Circle())
            }
            .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    private func sendComment() {
        let text = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        Task {
            if let comment = await boardVM.postComment(cardId: cardId, text: text) {
                comments.append(comment)
                newComment = "" // clear only once the post succeeds — keep the text on failure
            }
        }
    }

    // MARK: - Move / Delete

    private func moveSection(card: Card, payload: BoardPayload) -> some View {
        let otherLists = payload.sortedLists().filter { $0.id != card.listId }
        return VStack(alignment: .leading, spacing: 12) {
            BoardlyFieldLabel("Move to")
            ForEach(otherLists) { list in
                Button {
                    Task { await boardVM.moveCard(card, to: list) }
                } label: {
                    HStack {
                        SwiftUI.Label(list.name ?? "Untitled", systemImage: "arrow.right")
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
            SwiftUI.Label("Delete Card", systemImage: "trash")
                .font(.sans(15, .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.boardlyDestructive, in: Capsule())
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

private struct CoverImageView: View {
    let url: URL?
    let height: CGFloat
    let load: (URL) async -> Data?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.7)],
                    startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipped()
        .task(id: url) {
            guard let url else { return }
            image = await load(url).flatMap(UIImage.init(data:))
        }
    }
}

private struct CommentBubble: View {
    let comment: Comment
    let author: User?
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(name: author?.name ?? "?", size: 32, bordered: false)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(author?.name ?? "User")
                        .font(.sans(14, .semibold))
                        .foregroundStyle(Color.boardlyInk)
                    if let date = comment.createdAt {
                        Text("· \(date.formatted(.relative(presentation: .named)))")
                            .font(.boardlyMonoCaption)
                            .foregroundStyle(Color.boardlyTextTertiary)
                    }
                    Spacer(minLength: 0)
                }
                Text(comment.text)
                    .font(.boardlyBody)
                    .foregroundStyle(Color.boardlyInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.boardlySeparator, lineWidth: 0.5))
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                SwiftUI.Label("Delete", systemImage: "trash")
            }
        }
    }
}
