import SwiftUI
import BoardlyKit

/// Design 08a — assign/unassign board members to a card.
struct CardMembersSheet: View {
    let cardId: String
    @Bindable var boardVM: BoardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var card: Card? { boardVM.payload?.card(id: cardId) }

    private var assignedIds: Set<String> {
        guard let card, let payload = boardVM.payload else { return [] }
        return Set(payload.members(for: card).map(\.id))
    }

    private var boardMembers: [User] {
        (boardVM.payload?.boardMembers() ?? [])
            .filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)
                || ($0.username ?? "").localizedCaseInsensitiveContains(query) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Membres", onCancel: { dismiss() }, onDone: { dismiss() })

            searchField
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            ScrollView {
                let assigned = boardMembers.filter { assignedIds.contains($0.id) }
                let others = boardMembers.filter { !assignedIds.contains($0.id) }

                VStack(alignment: .leading, spacing: 20) {
                    if !assigned.isEmpty {
                        section("Sur la carte · \(assigned.count)", users: assigned)
                    }
                    if !others.isEmpty {
                        section("Équipe du board", users: others)
                    }
                }
                .padding(20)
            }
        }
        .background(Color.boardlyBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.boardlyTextTertiary)
            TextField("Rechercher un membre", text: $query)
                .font(.boardlyBody)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.boardlySeparator, lineWidth: 1))
    }

    private func section(_ title: String, users: [User]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.boardlyMonoLabel)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.boardlyTextSecondary)
            VStack(spacing: 0) {
                ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                    memberRow(user)
                    if index < users.count - 1 { Divider().padding(.leading, 62) }
                }
            }
            .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.boardlySeparator, lineWidth: 0.5))
        }
    }

    private func memberRow(_ user: User) -> some View {
        let assigned = assignedIds.contains(user.id)
        return Button {
            guard let card else { return }
            Task {
                if assigned { await boardVM.removeMember(user, from: card) }
                else { await boardVM.addMember(user, to: card) }
            }
        } label: {
            HStack(spacing: 14) {
                AvatarView(name: user.name, size: 36, bordered: false)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(.sans(15, .semibold))
                        .foregroundStyle(Color.boardlyInk)
                    if let username = user.username {
                        Text("@\(username)")
                            .font(.boardlyMonoCaption)
                            .foregroundStyle(Color.boardlyTextSecondary)
                    }
                }
                Spacer(minLength: 0)
                SelectionToggle(isOn: assigned)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
