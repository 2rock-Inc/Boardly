import BoardlyKit
import SwiftUI

/// Manage a board's members — add/remove from the project team.
struct BoardMembersSheet: View {
    @Bindable var boardVM: BoardViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var memberIds: Set<String> {
        Set(boardVM.payload?.boardMemberships.map(\.userId) ?? [])
    }

    private var candidates: [User] {
        boardVM.projectUsers.filter {
            query.isEmpty
                || $0.name.localizedCaseInsensitiveContains(query)
                || ($0.username ?? "").localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Board members", onCancel: { dismiss() }, onDone: { dismiss() })

            searchField
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            ScrollView {
                let current = candidates.filter { memberIds.contains($0.id) }
                let others = candidates.filter { !memberIds.contains($0.id) }
                VStack(alignment: .leading, spacing: 20) {
                    if !current.isEmpty { section("Board members · \(current.count)", users: current) }
                    if !others.isEmpty { section("Project team", users: others) }
                    if boardVM.projectUsers.isEmpty {
                        Text("No project members to add.")
                            .font(.boardlyBody)
                            .foregroundStyle(Color.boardlyTextTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    }
                }
                .padding(20)
            }
        }
        .background(Color.boardlyBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationCornerRadius(26)
        .task { await boardVM.loadBoardMemberCandidates() }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Color.boardlyTextTertiary)
            TextField("Search members", text: $query)
                .font(.boardlyBody)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.boardlySeparator, lineWidth: 1))
    }

    private func section(_ title: LocalizedStringKey, users: [User]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).boardlyMonoLabel().foregroundStyle(Color.boardlyTextSecondary)
            VStack(spacing: 0) {
                ForEach(Array(users.enumerated()), id: \.element.id) { index, user in
                    memberRow(user)
                    if index < users.count - 1 { Divider().padding(.leading, 62) }
                }
            }
            .boardlyCard(padding: 14)
        }
    }

    private func memberRow(_ user: User) -> some View {
        let isMember = memberIds.contains(user.id)
        return Button {
            Task {
                if isMember { await boardVM.removeBoardMember(userId: user.id) }
                else { await boardVM.addBoardMember(user) }
            }
        } label: {
            HStack(spacing: 12) {
                AvatarView(name: user.name, size: 36, bordered: false)
                VStack(alignment: .leading, spacing: 1) {
                    Text(verbatim: user.name)
                        .font(.boardlyCallout)
                        .foregroundStyle(Color.boardlyInk)
                    if let username = user.username {
                        Text(verbatim: "@\(username)")
                            .font(.boardlyMonoCaption)
                            .foregroundStyle(Color.boardlyTextTertiary)
                    }
                }
                Spacer(minLength: 0)
                SelectionToggle(isOn: isMember)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
