import SwiftUI
import BoardlyKit

struct CardRowView: View {
    let card: Card
    let taskLists: [TaskList]
    let tasks: [PlankaTask]

    private var totalTasks: Int { tasks.count }
    private var completedTasks: Int { tasks.filter(\.isCompleted).count }
    private var hasTasks: Bool { totalTasks > 0 }

    private var dueDateColor: Color {
        guard let due = card.dueDate else { return .secondary }
        if card.isDueCompleted == true { return .green }
        return due < Date() ? .red : .orange
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.name)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)

            if hasTasks || card.dueDate != nil {
                HStack(spacing: 10) {
                    if hasTasks {
                        Label("\(completedTasks)/\(totalTasks)", systemImage: "checkmark.circle")
                            .font(.caption2)
                            .foregroundStyle(completedTasks == totalTasks ? .green : .secondary)
                    }
                    if let due = card.dueDate {
                        Label(due.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                            .font(.caption2)
                            .foregroundStyle(dueDateColor)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 8))
    }
}
