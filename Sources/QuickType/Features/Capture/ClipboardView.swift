import AppKit
import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingItem: ClipboardItem?
    @State private var keyMonitor: Any?
    @State private var selectedSection: ClipboardSection = .kept
    @State private var selectedItemID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                clipboardSection(
                    title: "Kept",
                    items: model.keptClipboardItems,
                    emptyMessage: "Saved clipboard items will appear here."
                )

                clipboardSection(
                    title: "Recent",
                    items: model.recentClipboardItems,
                    emptyMessage: "Copy text anywhere and QuickType will hold it here temporarily."
                )
            }
            .padding()
        }
        .glassBackground()
        .sheet(item: $editingItem) { item in
            ClipboardItemEditor(item: item) { updatedTitle, updatedContent in
                model.updateClipboardItem(item.id, title: updatedTitle, content: updatedContent)
            }
        }
        .onAppear {
            syncSelection()
            installKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onChange(of: model.keptClipboardItems) { _ in
            syncSelection()
        }
        .onChange(of: model.recentClipboardItems) { _ in
            syncSelection()
        }
    }

    @ViewBuilder
    private func clipboardSection(title: String, items: [ClipboardItem], emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.bold())
                Spacer()
                if title == "Recent", !items.isEmpty {
                    Button("Clear Recent") {
                        model.clearRecentClipboardItems()
                    }
                    .glassControl()
                }
                Text("\(items.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
            }

            if items.isEmpty {
                Text(emptyMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
            } else {
                ForEach(items) { item in
                    ClipboardItemCard(
                        item: item,
                        shortcutLabel: title == "Kept" ? shortcutLabel(for: item, within: items) : nil,
                        isSelected: selectedItemID == item.id,
                        onInsert: { model.insertClipboardItem(item.id) },
                        onCopy: { model.copyClipboardItem(item.id) },
                        onSummarize: { model.summarizeClipboardItemWithAI(item.id) },
                        onCreateAction: { model.createQuickActionFromClipboardItem(item.id) },
                        onSaveToQuickNote: { model.saveClipboardItemToQuickNote(item.id) },
                        onEdit: { editingItem = item },
                        onDelete: { model.deleteClipboardItem(item.id) },
                        onKeepToggle: {
                            if item.isKept {
                                model.unkeepClipboardItem(item.id)
                            } else {
                                model.keepClipboardItem(item.id)
                            }
                        }
                    )
                }
            }
        }
    }

    private func shortcutLabel(for item: ClipboardItem, within items: [ClipboardItem]) -> String? {
        guard let index = items.firstIndex(where: { $0.id == item.id }),
              index < 10 else {
            return nil
        }
        return index == 9 ? "0" : "\(index + 1)"
    }

    private func installKeyboardMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard editingItem == nil else { return event }
            guard !model.isHeaderKeyboardFocusActive else { return event }

            if event.modifierFlags.contains(.command),
               Int(event.keyCode) == 51 {
                deleteSelectedItem()
                return nil
            }

            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "c" {
                copySelectedItem()
                return nil
            }

            if event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
               let characters = event.charactersIgnoringModifiers,
               let index = shortcutIndex(for: characters) {
                model.insertKeptClipboardItem(atShortcutIndex: index)
                return nil
            }

            guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
                return event
            }

            switch Int(event.keyCode) {
            case 48:
                advanceSection()
                return nil
            case 49:
                activateSelectedItem()
                return nil
            case 36, 76:
                editSelectedItem()
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

    private func shortcutIndex(for characters: String) -> Int? {
        switch characters {
        case "1": 0
        case "2": 1
        case "3": 2
        case "4": 3
        case "5": 4
        case "6": 5
        case "7": 6
        case "8": 7
        case "9": 8
        case "0": 9
        default: nil
        }
    }

    private func syncSelection() {
        let kept = model.keptClipboardItems
        let recent = model.recentClipboardItems

        if case .kept = selectedSection, kept.isEmpty, !recent.isEmpty {
            selectedSection = .recent
        } else if case .recent = selectedSection, recent.isEmpty, !kept.isEmpty {
            selectedSection = .kept
        }

        let items = itemsForSelectedSection()
        if let selectedItemID, items.contains(where: { $0.id == selectedItemID }) {
            return
        }
        selectedItemID = items.first?.id
    }

    private func itemsForSelectedSection() -> [ClipboardItem] {
        switch selectedSection {
        case .kept:
            return model.keptClipboardItems
        case .recent:
            return model.recentClipboardItems
        }
    }

    private func advanceSection() {
        let order: [ClipboardSection] = [.kept, .recent]
        guard let currentIndex = order.firstIndex(of: selectedSection) else { return }

        for offset in 1...order.count {
            let candidate = order[(currentIndex + offset) % order.count]
            let hasItems = candidate == .kept ? !model.keptClipboardItems.isEmpty : !model.recentClipboardItems.isEmpty
            if hasItems {
                selectedSection = candidate
                selectedItemID = itemsForSelectedSection().first?.id
                break
            }
        }
    }

    private func moveSelection(delta: Int) {
        let items = itemsForSelectedSection()
        guard !items.isEmpty else { return }
        let currentIndex = items.firstIndex(where: { $0.id == selectedItemID }) ?? 0
        let nextIndex = min(max(currentIndex + delta, 0), items.count - 1)
        selectedItemID = items[nextIndex].id
    }

    private func activateSelectedItem() {
        guard let selectedItemID else { return }
        model.insertClipboardItem(selectedItemID)
    }

    private func editSelectedItem() {
        guard let selectedItemID else { return }
        editingItem = model.keptClipboardItems.first(where: { $0.id == selectedItemID })
            ?? model.recentClipboardItems.first(where: { $0.id == selectedItemID })
    }

    private func copySelectedItem() {
        guard let selectedItemID else { return }
        model.copyClipboardItem(selectedItemID)
    }

    private func deleteSelectedItem() {
        guard let selectedItemID else { return }
        model.deleteClipboardItem(selectedItemID)
    }
}

private enum ClipboardSection {
    case kept
    case recent
}

private struct ClipboardItemCard: View {
    let item: ClipboardItem
    let shortcutLabel: String?
    let isSelected: Bool
    let onInsert: () -> Void
    let onCopy: () -> Void
    let onSummarize: () -> Void
    let onCreateAction: () -> Void
    let onSaveToQuickNote: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onKeepToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        if let shortcutLabel {
                            Text(shortcutLabel)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 22, height: 22)
                                .background(.thinMaterial, in: Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                                )
                        }
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(1)
                        if item.awaitingAIResponse {
                            Text("Waiting")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.thinMaterial, in: Capsule())
                        } else if item.aiResponse != nil {
                            Text("AI")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture(perform: onInsert)
                Spacer()
                actionButton(systemName: "doc.on.doc", helpText: "Copy item", action: onCopy)
                actionButton(systemName: "sparkles", helpText: "Summarize with AI", action: onSummarize)
                actionButton(systemName: "bolt.fill", helpText: "Create quick action", action: onCreateAction)
                actionButton(systemName: "square.and.arrow.down", helpText: "Save to Quick Note", action: onSaveToQuickNote)
                actionButton(systemName: "pencil", helpText: "Edit item", action: onEdit)
                actionButton(systemName: "trash", helpText: "Delete item", role: .destructive, action: onDelete)
                actionButton(
                    systemName: item.isKept ? "pin.fill" : "pin",
                    helpText: item.isKept ? "Unkeep item" : "Keep item",
                    action: onKeepToggle
                )
            }

            Text(item.content)
                .font(.body.monospaced())
                .lineLimit(4)
                .textSelection(.enabled)
                .contentShape(Rectangle())
                .onTapGesture(perform: onInsert)

            HStack {
                Spacer()
                Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.4) : .clear, lineWidth: 2)
        )
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

private struct ClipboardItemEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var content: String
    let item: ClipboardItem
    let onSave: (String, String) -> Void

    init(item: ClipboardItem, onSave: @escaping (String, String) -> Void) {
        self.item = item
        self.onSave = onSave
        _title = State(initialValue: item.title)
        _content = State(initialValue: item.content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Edit Clipboard Item")
                .font(.title3.bold())

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $content)
                .font(.body.monospaced())
                .frame(minHeight: 220)

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    onSave(title, content)
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 360)
        .glassBackground()
    }
}
