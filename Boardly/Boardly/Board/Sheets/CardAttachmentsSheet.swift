import SwiftUI
import BoardlyKit
import PhotosUI
import UniformTypeIdentifiers

/// Design 08d — attach a file (photo library / file) or a link to a card, and
/// see the card's existing attachments.
struct CardAttachmentsSheet: View {
    let cardId: String
    @Bindable var boardVM: BoardViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var photoItem: PhotosPickerItem?
    @State private var showFileImporter = false
    @State private var showLinkInput = false
    @State private var linkURL = ""
    @State private var linkName = ""

    private var attachments: [Attachment] {
        guard let card = boardVM.payload?.card(id: cardId) else { return [] }
        return boardVM.payload?.attachments(for: card) ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "Attach", onCancel: { dismiss() }, onDone: { dismiss() })
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    optionsCard
                    if !attachments.isEmpty { existingSection }
                }
                .padding(20)
            }
        }
        .background(Color.boardlyBackground)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item]) { result in
            handleFile(result)
        }
        .onChange(of: photoItem) { _, item in Task { await handlePhoto(item) } }
        .alert("Paste a link", isPresented: $showLinkInput) {
            TextField("https://…", text: $linkURL)
            TextField("Name (optional)", text: $linkName)
            Button("Add") { addLink() }
            Button("Cancel", role: .cancel) { linkURL = ""; linkName = "" }
        }
    }

    private var optionsCard: some View {
        VStack(spacing: 0) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                optionRow("Photo Library", systemImage: "photo.on.rectangle")
            }
            Divider().padding(.leading, 62)
            Button { showFileImporter = true } label: {
                optionRow("Choose a File", systemImage: "doc")
            }
            Divider().padding(.leading, 62)
            Button { showLinkInput = true } label: {
                optionRow("Paste a Link", systemImage: "link")
            }
        }
        .buttonStyle(.plain)
        .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.boardlySeparator, lineWidth: 0.5))
    }

    private func optionRow(_ title: String, systemImage: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.boardlySurfaceSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(title)
                .font(.boardlyBody)
                .foregroundStyle(Color.boardlyInk)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.boardlyTextTertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private var existingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("On this card · \(attachments.count)")
                .font(.boardlyMonoLabel)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Color.boardlyTextSecondary)
            VStack(spacing: 0) {
                ForEach(Array(attachments.enumerated()), id: \.element.id) { index, attachment in
                    attachmentRow(attachment)
                    if index < attachments.count - 1 { Divider().padding(.leading, 62) }
                }
            }
            .background(Color.boardlySurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.boardlySeparator, lineWidth: 0.5))
        }
    }

    private func attachmentRow(_ attachment: Attachment) -> some View {
        HStack(spacing: 14) {
            Image(systemName: attachment.type == "link" ? "link" : "paperclip")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.boardlySurfaceSecondary, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(attachment.name)
                .font(.sans(14, .semibold))
                .foregroundStyle(Color.boardlyInk)
                .lineLimit(1)
            Spacer(minLength: 0)
            Button(role: .destructive) {
                Task { await boardVM.removeAttachment(attachment) }
            } label: {
                Image(systemName: "trash").foregroundStyle(Color.labelRose)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Actions

    private func handlePhoto(_ item: PhotosPickerItem?) async {
        guard let item, let data = try? await item.loadTransferable(type: Data.self) else { return }
        let type = item.supportedContentTypes.first
        let ext = type?.preferredFilenameExtension ?? "jpg"
        let mime = type?.preferredMIMEType ?? "image/jpeg"
        await boardVM.uploadAttachment(cardId: cardId, fileName: "photo.\(ext)", mimeType: mime, data: data)
        dismiss()
    }

    private func handleFile(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { return }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        Task {
            await boardVM.uploadAttachment(cardId: cardId, fileName: url.lastPathComponent, mimeType: mime, data: data)
            dismiss()
        }
    }

    private func addLink() {
        let url = linkURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !url.isEmpty else { return }
        let name = linkName.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await boardVM.addLinkAttachment(cardId: cardId, url: url, name: name.isEmpty ? url : name)
            dismiss()
        }
        linkURL = ""; linkName = ""
    }
}
