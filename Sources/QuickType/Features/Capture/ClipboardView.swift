import AppKit
import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingItem: ClipboardItem?
    @State private var keyMonitor: Any?
    @State private var selectedSection: ClipboardSection = .kept
    @State private var selectedItemID: UUID?
    @State private var expandedItemIDs: Set<UUID> = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                clipboardSection(
                    title: "Saved",
                    items: model.keptClipboardItems,
                    section: .kept,
                    emptyMessage: "Saved clips will appear here."
                )

                clipboardSection(
                    title: "Recent",
                    items: model.recentClipboardItems,
                    section: .recent,
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
    private func clipboardSection(title: String, items: [ClipboardItem], section: ClipboardSection, emptyMessage: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.bold())
                Spacer()
                if section == .recent, !items.isEmpty {
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
                    ClipboardAccordionCard(
                        item: item,
                        isExpanded: expandedItemIDs.contains(item.id),
                        isSelected: selectedItemID == item.id,
                        onToggleExpanded: { toggleExpanded(item.id) },
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

    private func toggleExpanded(_ itemID: UUID) {
        if expandedItemIDs.contains(itemID) {
            expandedItemIDs.remove(itemID)
        } else {
            expandedItemIDs.insert(itemID)
        }
    }

    private func installKeyboardMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard editingItem == nil else { return event }
            guard !model.isHeaderKeyboardFocusActive else { return event }

            if model.settings.deleteSelectionHotkey.matches(event) {
                deleteSelectedItem()
                return nil
            }

            if model.settings.copySelectionHotkey.matches(event) {
                copySelectedItem()
                return nil
            }

            if model.settings.switchPaneHotkey.matches(event) {
                advanceSection()
                return nil
            }

            if model.settings.activateSelectionHotkey.matches(event) {
                activateSelectedItem()
                return nil
            }

            if model.settings.editSelectionHotkey.matches(event) {
                editSelectedItem()
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
        toggleExpanded(selectedItemID)
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

private struct ClipboardAccordionCard: View {
    let item: ClipboardItem
    let isExpanded: Bool
    let isSelected: Bool
    let onToggleExpanded: () -> Void
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
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(item.title)
                            .font(.headline)
                            .lineLimit(1)
                        if item.awaitingAIResponse {
                            badge("Waiting")
                        } else if item.aiResponse != nil {
                            badge("AI")
                        }
                        if item.isKept {
                            badge("Saved")
                        }
                    }
                    Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                actionButton(systemName: "arrowshape.turn.up.right", helpText: "Insert clip", action: onInsert)
                actionButton(systemName: "doc.on.doc", helpText: "Copy clip", action: onCopy)
                actionButton(systemName: item.isKept ? "pin.slash" : "pin", helpText: item.isKept ? "Move to Recent" : "Save clip", action: onKeepToggle)
                actionButton(systemName: "sparkles", helpText: "Summarize with AI", action: onSummarize)
                actionButton(systemName: "bolt.fill", helpText: "Create quick action", action: onCreateAction)
                actionButton(systemName: "square.and.arrow.down", helpText: "Save to Quick Note", action: onSaveToQuickNote)
                actionButton(systemName: "pencil", helpText: "Edit clip", action: onEdit)
                actionButton(systemName: "trash", helpText: "Delete clip", role: .destructive, action: onDelete)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(item.content)
                    .font(.body.monospaced())
                    .lineLimit(isExpanded ? nil : 3)
                    .textSelection(.enabled)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onToggleExpanded)

                HStack {
                    Button(isExpanded ? "Collapse" : "Expand") {
                        onToggleExpanded()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)

                    Spacer()

                    Text(item.updatedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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
            }
        }
        .padding()
        .frame(minWidth: 520, minHeight: 360)
        .glassBackground()
    }
}
