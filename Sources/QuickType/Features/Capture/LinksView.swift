import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LinksView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedFolderPath = AppSettings.recentLinksFolderName
    @State private var editingLink: SavedLink?
    @State private var savingLink: SavedLink?
    @State private var newFolderName = ""
    @State private var selectedLinkID: UUID?
    @State private var focusedArea: LinksFocusArea = .links
    @State private var keyMonitor: Any?
    @State private var draggedLinkID: UUID?

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Folders")
                        .font(.title3.bold())
                    Spacer()
                }

                List(model.linkFolders, id: \.self, selection: $selectedFolderPath) { path in
                    folderRow(path)
                        .tag(path)
                }
                .scrollContentBackground(.hidden)
                .glassCard()

                HStack {
                    TextField("New folder", text: $newFolderName)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        model.createLinkFolder(named: newFolderName)
                        let resolvedFolder = normalizedFolder(newFolderName)
                        if !resolvedFolder.isEmpty {
                            selectedFolderPath = resolvedFolder
                        }
                        newFolderName = ""
                    }
                    .glassControl()
                }
            }
            .frame(width: 220)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(selectedFolderPath)
                        .font(.title3.bold())
                    Spacer()
                    if selectedFolderPath == AppSettings.recentLinksFolderName && !filteredLinks.isEmpty {
                        Button("Clear Recent") {
                            model.clearRecentLinks()
                        }
                        .glassControl()
                    }
                    Text("\(filteredLinks.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }

                if filteredLinks.isEmpty {
                    Text(selectedFolderPath == AppSettings.recentLinksFolderName
                        ? "Copied links land in Recent first. Save them into folders when you want to keep them."
                        : "Drop a link here or save one into this folder.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                        .onDrop(of: [UTType.text.identifier], delegate: FolderRowDropDelegate(folderPath: selectedFolderPath, model: model, draggedLinkID: $draggedLinkID))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(filteredLinks) { link in
                                LinkCard(
                                    link: link,
                                    isSelected: selectedLinkID == link.id,
                                    onOpen: { model.openSavedLink(link.id) },
                                    onCopy: { model.copySavedLink(link.id) },
                                    onSave: {
                                        if link.isPinned {
                                            model.unpinSavedLink(link.id)
                                        } else {
                                            savingLink = link
                                        }
                                    },
                                    onSummarize: { model.summarizeSavedLinkWithAI(link.id) },
                                    onEdit: { editingLink = link },
                                    onDelete: { model.deleteSavedLink(link.id) }
                                )
                                .onDrag {
                                    draggedLinkID = link.id
                                    return NSItemProvider(object: link.id.uuidString as NSString)
                                }
                                .onDrop(of: [UTType.text.identifier], delegate: LinkCardDropDelegate(targetLink: link, model: model, draggedLinkID: $draggedLinkID))
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .glassBackground()
        .sheet(item: $editingLink) { link in
            LinkEditor(link: link)
                .environmentObject(model)
        }
        .sheet(item: $savingLink) { link in
            LinkSaveSheet(link: link, suggestedFolder: link.folderPath == AppSettings.recentLinksFolderName ? model.firstSavedLinksFolder : link.folderPath)
                .environmentObject(model)
        }
        .onAppear {
            if !model.linkFolders.contains(selectedFolderPath) {
                selectedFolderPath = model.linkFolders.first ?? AppSettings.recentLinksFolderName
            }
            syncSelection()
            installKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onChange(of: selectedFolderPath) { _ in
            syncSelection()
        }
        .onChange(of: model.savedLinks) { _ in
            if !model.linkFolders.contains(selectedFolderPath) {
                selectedFolderPath = model.linkFolders.first ?? AppSettings.recentLinksFolderName
            }
            syncSelection()
        }
    }

    private func folderRow(_ path: String) -> some View {
        HStack {
            Text(path)
            Spacer()
            Text("\(model.orderedLinks(in: path).count)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedFolderPath = path
        }
        .onDrop(of: [UTType.text.identifier], delegate: FolderRowDropDelegate(folderPath: path, model: model, draggedLinkID: $draggedLinkID))
    }

    private var filteredLinks: [SavedLink] {
        model.orderedLinks(in: selectedFolderPath)
    }

    private func normalizedFolder(_ value: String) -> String {
        value
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "/")
    }

    private func syncSelection() {
        let links = filteredLinks
        if let selectedLinkID, links.contains(where: { $0.id == selectedLinkID }) {
            return
        }
        selectedLinkID = links.first?.id
        if links.isEmpty {
            focusedArea = .folders
        }
    }

    private func installKeyboardMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard editingLink == nil, savingLink == nil else { return event }
            guard !model.isHeaderKeyboardFocusActive else { return event }

            if model.settings.deleteSelectionHotkey.matches(event) {
                deleteSelectedLink()
                return nil
            }

            if model.settings.copySelectionHotkey.matches(event) {
                copySelectedLink()
                return nil
            }

            if model.settings.switchPaneHotkey.matches(event) {
                focusedArea = focusedArea == .folders ? .links : .folders
                return nil
            }

            if model.settings.activateSelectionHotkey.matches(event) {
                confirmSelection()
                return nil
            }

            if model.settings.editSelectionHotkey.matches(event) {
                openOrEditSelection()
                return nil
            }

            if model.settings.nextNavigationHotkey.matches(event) {
                moveSelection(delta: 1)
                return nil
            }

            if model.settings.previousNavigationHotkey.matches(event) {
                moveSelection(delta: -1)
                return nil
            }

            return event
        }
    }

    private func removeKeyboardMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func moveSelection(delta: Int) {
        switch focusedArea {
        case .folders:
            let folders = model.linkFolders
            guard !folders.isEmpty else { return }
            let currentIndex = folders.firstIndex(of: selectedFolderPath) ?? 0
            let nextIndex = min(max(currentIndex + delta, 0), folders.count - 1)
            selectedFolderPath = folders[nextIndex]
        case .links:
            let links = filteredLinks
            guard !links.isEmpty else { return }
            let currentIndex = links.firstIndex(where: { $0.id == selectedLinkID }) ?? 0
            let nextIndex = min(max(currentIndex + delta, 0), links.count - 1)
            selectedLinkID = links[nextIndex].id
        }
    }

    private func confirmSelection() {
        if focusedArea == .links {
            openSelectedLink()
        }
    }

    private func openOrEditSelection() {
        if focusedArea == .folders {
            focusedArea = .links
            syncSelection()
            return
        }

        guard let selectedLinkID else { return }
        editingLink = filteredLinks.first(where: { $0.id == selectedLinkID })
    }

    private func openSelectedLink() {
        guard let selectedLinkID else { return }
        model.openSavedLink(selectedLinkID)
    }

    private func copySelectedLink() {
        guard focusedArea == .links, let selectedLinkID else { return }
        model.copySavedLink(selectedLinkID)
    }

    private func deleteSelectedLink() {
        guard focusedArea == .links, let selectedLinkID else { return }
        model.deleteSavedLink(selectedLinkID)
    }
}

private enum LinksFocusArea {
    case folders
    case links
}

private struct LinkCard: View {
    let link: SavedLink
    let isSelected: Bool
    let onOpen: () -> Void
    let onCopy: () -> Void
    let onSave: () -> Void
    let onSummarize: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(link.title)
                            .font(.headline)
                            .lineLimit(1)
                        badge(link.kind == .web ? "Web" : "Local")
                        if link.isPinned {
                            badge("Saved")
                        }
                        if link.awaitingAIResponse {
                            badge("Waiting")
                        } else if link.summary != nil {
                            badge("AI")
                        }
                    }
                    Text(link.url)
                        .font(.footnote.monospaced())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(link.folderPath)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                actionButton(systemName: "arrow.up.right.square", helpText: "Open link", action: onOpen)
                actionButton(systemName: "doc.on.doc", helpText: "Copy link", action: onCopy)
                actionButton(systemName: link.isPinned ? "pin.slash" : "pin", helpText: link.isPinned ? "Move back to Recent" : "Save to folder", action: onSave)
                actionButton(systemName: "sparkles", helpText: "Summarize link", action: onSummarize)
                actionButton(systemName: "pencil", helpText: "Edit link", action: onEdit)
                actionButton(systemName: "trash", helpText: "Delete link", role: .destructive, action: onDelete)
            }

            if let summary = link.summary, !summary.isEmpty {
                Text(summary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            if let notes = link.notes, !notes.isEmpty {
                Text(notes)
                    .font(.body.monospaced())
                    .lineLimit(3)
            }
        }
        .padding(14)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.4) : .clear, lineWidth: 2)
        )
    }

    private func badge(_ text: String) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.thinMaterial, in: Capsule())
    }

    @ViewBuilder
    private func actionButton(
        systemName: String,
        helpText: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(.thinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )
        }
        .buttonStyle(GlassIconButtonStyle())
        .help(helpText)
    }
}

private struct LinkEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @State private var title: String
    @State private var folderPath: String
    @State private var notes: String
    let link: SavedLink

    init(link: SavedLink) {
        self.link = link
        _title = State(initialValue: link.title)
        _folderPath = State(initialValue: link.folderPath)
        _notes = State(initialValue: link.notes ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Link")
                .font(.title3.bold())

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
            TextField("Folder Path", text: $folderPath)
                .textFieldStyle(.roundedBorder)
            Text(link.url)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)
            TextEditor(text: $notes)
                .font(.body.monospaced())
                .frame(minHeight: 180)
                .glassCard()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    model.updateSavedLink(link.id, title: title, folderPath: folderPath, notes: notes)
                    dismiss()
                }
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 360)
        .glassBackground()
    }
}

private struct LinkSaveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel
    @State private var selectedFolder: String
    @State private var newFolderName = ""
    let link: SavedLink
    let suggestedFolder: String

    init(link: SavedLink, suggestedFolder: String) {
        self.link = link
        self.suggestedFolder = suggestedFolder
        _selectedFolder = State(initialValue: suggestedFolder)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save Link")
                .font(.title3.bold())

            Text(link.url)
                .font(.footnote.monospaced())
                .foregroundStyle(.secondary)

            Picker("Folder", selection: $selectedFolder) {
                ForEach(model.linkFolders.filter { $0 != AppSettings.recentLinksFolderName }, id: \.self) { folder in
                    Text(folder).tag(folder)
                }
                if !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(normalizedFolder(newFolderName)).tag(normalizedFolder(newFolderName))
                }
            }

            HStack {
                TextField("New folder", text: $newFolderName)
                    .textFieldStyle(.roundedBorder)
                Button("Use") {
                    let folder = normalizedFolder(newFolderName)
                    guard !folder.isEmpty else { return }
                    selectedFolder = folder
                }
                .glassControl()
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    let folder = normalizedFolder(selectedFolder.isEmpty ? newFolderName : selectedFolder)
                    model.saveSavedLink(link.id, toFolder: folder)
                    dismiss()
                }
                .disabled(normalizedFolder(selectedFolder.isEmpty ? newFolderName : selectedFolder).isEmpty)
            }
        }
        .padding()
        .frame(minWidth: 420)
        .glassBackground()
    }

    private func normalizedFolder(_ value: String) -> String {
        value
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "/")
    }
}

private struct FolderRowDropDelegate: DropDelegate {
    let folderPath: String
    let model: AppModel
    @Binding var draggedLinkID: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        draggedLinkID != nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedLinkID else { return false }
        model.moveSavedLink(draggedLinkID, toFolder: folderPath)
        self.draggedLinkID = nil
        return true
    }
}

private struct LinkCardDropDelegate: DropDelegate {
    let targetLink: SavedLink
    let model: AppModel
    @Binding var draggedLinkID: UUID?

    func validateDrop(info: DropInfo) -> Bool {
        draggedLinkID != nil
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedLinkID, draggedLinkID != targetLink.id else { return false }
        model.moveSavedLink(draggedLinkID, toFolder: targetLink.folderPath, before: targetLink.id)
        self.draggedLinkID = nil
        return true
    }
}
