import SwiftUI

struct LinksView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedFolderPath = ""
    @State private var editingLink: SavedLink?
    @State private var newFolderName = ""
    @State private var selectedLinkID: UUID?
    @State private var focusedArea: LinksFocusArea = .links
    @State private var keyMonitor: Any?

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Folders")
                        .font(.title3.bold())
                    Spacer()
                }

                List(folderPaths, id: \.self, selection: $selectedFolderPath) { path in
                    Text(path.isEmpty ? "All Links" : path)
                        .tag(path)
                }
                .scrollContentBackground(.hidden)
                .glassCard()

                HStack {
                    TextField("New folder", text: $newFolderName)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        let folder = normalizedFolder(newFolderName)
                        guard !folder.isEmpty else { return }
                        selectedFolderPath = folder
                        newFolderName = ""
                    }
                    .glassControl()
                }
            }
            .frame(width: 220)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(selectedFolderPath.isEmpty ? "All Links" : selectedFolderPath)
                        .font(.title3.bold())
                    Spacer()
                    Text("\(filteredLinks.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }

                if filteredLinks.isEmpty {
                    Text("Copied web links are saved here automatically.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(filteredLinks) { link in
                                LinkCard(
                                    link: link,
                                    isSelected: selectedLinkID == link.id,
                                    onOpen: { model.openSavedLink(link.id) },
                                    onSummarize: { model.summarizeSavedLinkWithAI(link.id) },
                                    onEdit: { editingLink = link },
                                    onDelete: { model.deleteSavedLink(link.id) }
                                )
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
        .onAppear {
            if selectedFolderPath.isEmpty, !folderPaths.contains("") {
                selectedFolderPath = folderPaths.first ?? ""
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
            syncSelection()
        }
    }

    private var folderPaths: [String] {
        let paths = Set(model.savedLinks.map(\.folderPath))
        return [""] + paths.filter { !$0.isEmpty }.sorted()
    }

    private var filteredLinks: [SavedLink] {
        if selectedFolderPath.isEmpty {
            return model.savedLinks
        }
        return model.savedLinks.filter { $0.folderPath == selectedFolderPath }
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
            guard editingLink == nil else { return event }
            guard !model.isHeaderKeyboardFocusActive else { return event }

            if event.modifierFlags.contains(.command),
               Int(event.keyCode) == 51 {
                deleteSelectedLink()
                return nil
            }

            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "c" {
                copySelectedLink()
                return nil
            }

            guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
                return event
            }

            switch Int(event.keyCode) {
            case 48:
                focusedArea = focusedArea == .folders ? .links : .folders
                return nil
            case 49:
                confirmSelection()
                return nil
            case 36, 76:
                openOrEditSelection()
                return nil
            case 125:
                moveSelection(delta: 1)
                return nil
            case 126:
                moveSelection(delta: -1)
                return nil
            default:
                return event
            }
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
            let folders = folderPaths
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
                    if !link.folderPath.isEmpty {
                        Text(link.folderPath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                actionButton(systemName: "arrow.up.right.square", helpText: "Open link", action: onOpen)
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
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 360)
        .glassBackground()
    }
}
