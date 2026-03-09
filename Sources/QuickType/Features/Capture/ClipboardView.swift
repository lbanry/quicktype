import AppKit
import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingItem: ClipboardItem?
    @State private var keyMonitor: Any?

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
            installKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
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
            guard editingItem == nil,
                  event.modifierFlags.intersection([.command, .option, .control]).isEmpty,
                  let characters = event.charactersIgnoringModifiers,
                  let index = shortcutIndex(for: characters) else {
                return event
            }

            model.insertKeptClipboardItem(atShortcutIndex: index)
            return nil
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
}

private struct ClipboardItemCard: View {
    let item: ClipboardItem
    let shortcutLabel: String?
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
