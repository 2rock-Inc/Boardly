import SwiftUI
import BoardlyKit

struct CardRowView: View {
    let card: Card
    let taskLists: [TaskList]
    let tasks: [PlankaTask]

    private var totalTasks: Int { tasks.count }
    private var completedTasks: Int { tasks.filter(\.isCompleted).count }
    private var hasTasks: Bool { totalTasks > 0 }
    private var hasMeta: Bool { hasTasks || card.dueDate != nil }

    private var dueDateColor: Color {
        guard let due = card.dueDate else { return .boardlyTextSecondary }
        if card.isDueCompleted == true { return .labelGreen }
        return due < Date() ? .labelRose : .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.name)
                .font(.sans(15, .semibold))
                .foregroundStyle(Color.boardlyInk)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            if hasMeta {
                HStack(spacing: 10) {
                    if let due = card.dueDate {
                        metaChip(
                            systemImage: "calendar",
                            text: due.formatted(.dateTime.month(.abbreviated).day()),
                            color: dueDateColor
                        )
                    }
                    if hasTasks {
                        metaChip(
                            systemImage: "checklist",
                            text: "\(completedTasks)/\(totalTasks)",
                            color: completedTasks == totalTasks ? .labelGreen : .boardlyTextSecondary
                        )
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.boardlySeparator, lineWidth: 0.5)
        )
    }

    private func metaChip(systemImage: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.mono(11, .medium))
        }
        .foregroundStyle(color)
    }
}
