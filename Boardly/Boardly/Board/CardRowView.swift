import BoardlyKit
import SwiftUI

struct CardRowView: View {
    let card: Card
    let taskLists: [TaskList]
    let tasks: [PlankaTask]
    var labels: [BoardlyKit.Label] = []
    var members: [User] = []
    /// Cover image URL, resolved from the card's cover attachment (nil = no cover).
    var coverURL: URL?
    /// Image byte loader (goes through the board's cache); nil in previews.
    var loadImage: ((URL) async -> Data?)?

    private var totalTasks: Int { tasks.count }
    private var completedTasks: Int { tasks.filter(\.isCompleted).count }
    private var hasTasks: Bool { totalTasks > 0 }
    private var commentsTotal: Int { card.commentsTotal ?? 0 }
    private var stopwatch: Stopwatch? { card.stopwatchValue }
    private var hasMeta: Bool {
        hasTasks || card.dueDate != nil || commentsTotal > 0 || stopwatch != nil || !members.isEmpty
    }

    private var dueDateColor: Color {
        guard let due = card.dueDate else { return .boardlyTextSecondary }
        if card.isDueCompleted == true { return .labelGreen }
        return due < Date() ? .boardlyDestructive : .accentColor
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let coverURL, let loadImage {
                CardCoverThumbnail(url: coverURL, load: loadImage)
            }

            VStack(alignment: .leading, spacing: 8) {
                if !labels.isEmpty {
                    HStack(spacing: 5) {
                        ForEach(labels) { label in
                            Text(label.name ?? "•")
                                .font(.sans(11, .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color(plankaLabel: label.color), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                }

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
                                color: dueDateColor)
                        }
                        if hasTasks {
                            metaChip(
                                systemImage: "checklist",
                                text: "\(completedTasks)/\(totalTasks)",
                                color: completedTasks == totalTasks ? .labelGreen : .boardlyTextSecondary)
                        }
                        if let stopwatch {
                            metaChip(
                                systemImage: "stopwatch",
                                text: compactDuration(stopwatch.elapsed()),
                                color: stopwatch.isRunning ? .accentColor : .boardlyTextSecondary)
                        }
                        if commentsTotal > 0 {
                            metaChip(systemImage: "bubble.left", text: "\(commentsTotal)", color: .boardlyTextSecondary)
                        }
                        Spacer(minLength: 0)
                        if !members.isEmpty {
                            HStack(spacing: -6) {
                                ForEach(members.prefix(3)) { user in
                                    AvatarView(name: user.name, size: 22)
                                }
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }

    private func metaChip(systemImage: String, text: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(text)
                .font(.sans(12, .medium))
        }
        .foregroundStyle(color)
    }

    /// Compact elapsed time for a card chip: `1h05` with hours, else `42m`.
    private func compactDuration(_ seconds: Int) -> String {
        let h = seconds / 3600, m = (seconds % 3600) / 60
        return h > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(m)m"
    }
}

/// Edge-to-edge cover thumbnail for a kanban card (80pt tall, rounded top only).
private struct CardCoverThumbnail: View {
    let url: URL
    let load: (URL) async -> Data?
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Color.boardlyNeutralFill
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 80)
        .clipped()
        .task(id: url) { image = await load(url).flatMap(UIImage.init(data:)) }
    }
}

extension BoardPayload {
    /// Resolves a card's cover image URL from its cover attachment, if any.
    func coverURL(for card: Card) -> URL? {
        guard let coverId = card.coverAttachmentId,
              let attachment = attachments.first(where: { $0.id == coverId }),
              let data = try? JSONEncoder().encode(attachment.data),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        let urlString = (obj["url"] as? String)
            ?? ((obj["image"] as? [String: Any])?["url"] as? String)
            ?? ((obj["thumbnailUrls"] as? [String: Any])?["outside360"] as? String)
        return urlString.flatMap(URL.init(string:))
    }
}
