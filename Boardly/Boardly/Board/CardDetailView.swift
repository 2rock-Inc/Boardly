import SwiftUI
import BoardlyKit

struct CardDetailView: View {
    let cardId: String
    @Bindable var boardVM: BoardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var isEditingName = false
    @State private var editedName = ""
    @State private var editedDescription = ""
    @State private var hasDueDate = false
    @State private var editedDueDate = Date()
    @State private var newTaskName = ""
    @State private var addingTaskInListId: String? = nil
    @FocusState private var taskFieldFocused: Bool

    private var card: Card? { boardVM.payload?.card(id: cardId) }

    var body: some View {
        Group {
            if let card, let payload = boardVM.payload {
                cardContent(card: card, payload: payload)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(card?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(content: {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        })
    }

    @ViewBuilder
    private func cardContent(card: Card, payload: BoardPayload) -> some View {
        List {
            // Name
            Section("Title") {
                if isEditingName {
                    TextField("Card name", text: $editedName)
                        .onSubmit { saveCardName(card: card) }
                } else {
                    Text(card.name)
                        .onTapGesture {
                            editedName = card.name
                            isEditingName = true
                        }
                }
            }

            // Description
            Section("Description") {
                ZStack(alignment: .topLeading) {
                    if editedDescription.isEmpty {
                        Text("Add a description…")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 4)
                    }
                    TextEditor(text: $editedDescription)
                        .frame(minHeight: 80)
                }
                .onAppear { editedDescription = card.description ?? "" }
                Button("Save") { saveDescription(card: card) }
                    .disabled(editedDescription == (card.description ?? ""))
            }

            // Due date
            Section("Due Date") {
                Toggle("Set due date", isOn: $hasDueDate)
                if hasDueDate {
                    DatePicker(
                        "Date",
                        selection: $editedDueDate,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                }
                Button("Save") { saveDueDate(card: card) }
                    .disabled(!dueDateChanged(card: card))
            }
            .onAppear {
                hasDueDate = card.dueDate != nil
                editedDueDate = card.dueDate ?? Date()
            }

            // Task lists
            let taskLists = payload.taskLists(for: card)
            if !taskLists.isEmpty {
                ForEach(taskLists) { taskList in
                    taskListSection(taskList: taskList, payload: payload)
                }
            }

            // Move card
            Section("Move to List") {
                let otherLists = payload.sortedLists().filter { $0.id != card.listId }
                ForEach(otherLists) { list in
                    Button {
                        Task { await boardVM.moveCard(card, to: list) }
                    } label: {
                        Label(list.name ?? "Untitled", systemImage: "arrow.right")
                    }
                }
            }

            // Delete
            Section {
                Button(role: .destructive) {
                    Task {
                        await boardVM.deleteCard(card)
                        dismiss()
                    }
                } label: {
                    Label("Delete Card", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func taskListSection(taskList: TaskList, payload: BoardPayload) -> some View {
        let tasks = payload.tasks(for: taskList)
        let completed = tasks.filter(\.isCompleted).count
        Section {
            ForEach(tasks) { task in
                HStack(spacing: 12) {
                    Button {
                        Task { await boardVM.toggleTask(task) }
                    } label: {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(task.isCompleted ? .green : .secondary)
                            .font(.title3)
                    }
                    .buttonStyle(.plain)

                    Text(task.name)
                        .strikethrough(task.isCompleted)
                        .foregroundStyle(task.isCompleted ? .secondary : .primary)

                    Spacer()
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        Task { await boardVM.deleteTask(task) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }

            // Add task inline
            if addingTaskInListId == taskList.id {
                HStack {
                    Image(systemName: "circle")
                        .foregroundStyle(.tertiary)
                        .font(.title3)
                    TextField("New task", text: $newTaskName)
                        .focused($taskFieldFocused)
                        .onSubmit { submitTask(taskList: taskList) }
                }
            }

            Button {
                addingTaskInListId = taskList.id
                newTaskName = ""
                taskFieldFocused = true
            } label: {
                Label("Add task", systemImage: "plus")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Text(taskList.name)
                Spacer()
                if !tasks.isEmpty {
                    Text("\(completed)/\(tasks.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

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

    private func dueDateChanged(card: Card) -> Bool {
        if hasDueDate {
            guard let existing = card.dueDate else { return true }
            // Tolerate sub-second drift from the DatePicker round-trip.
            return abs(existing.timeIntervalSince(editedDueDate)) >= 1
        } else {
            return card.dueDate != nil
        }
    }

    private func saveDueDate(card: Card) {
        let patch = hasDueDate
            ? CardPatch(dueDate: editedDueDate)
            : CardPatch(clearDueDate: true)
        Task { await boardVM.updateCard(card, patch: patch) }
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
