import AppKit
import SwiftUI

struct QuickActionsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingAction: QuickActionDraft?
    @State private var selectedActionID: UUID?
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Actions")
                    .font(.title3.bold())
                Spacer()
                Text("\(model.quickActions.count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(.thinMaterial, in: Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.22), lineWidth: 1)
                    )
                Button("New Action") {
                    editingAction = QuickActionDraft.new
                }
                .glassControl()
            }

            if model.quickActions.isEmpty {
                Text("Create reusable actions for text snippets, AI prompts, and saved clips.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
            } else {
                ForEach(model.quickActions) { action in
                    QuickActionCard(
                        action: action,
                        clipTitle: clipTitle(for: action.clipboardItemID),
                        isSelected: selectedActionID == action.id,
                        onRun: { model.runQuickAction(action.id) },
                        onDuplicate: { model.duplicateQuickAction(action.id) },
                        onEdit: { editingAction = QuickActionDraft(action: action) },
                        onDelete: { model.deleteQuickAction(action.id) }
                    )
                }
            }
        }
        .sheet(item: $editingAction) { draft in
            QuickActionEditor(draft: draft)
                .environmentObject(model)
        }
        .onAppear {
            syncSelection()
            installKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onChange(of: model.quickActions) { _ in
            syncSelection()
        }
    }

    private func clipTitle(for itemID: UUID?) -> String? {
        guard let itemID else { return nil }
        return model.keptClipboardItems.first(where: { $0.id == itemID })?.title
            ?? model.recentClipboardItems.first(where: { $0.id == itemID })?.title
    }

    private func syncSelection() {
        if let selectedActionID, model.quickActions.contains(where: { $0.id == selectedActionID }) {
            return
        }
        selectedActionID = model.quickActions.first?.id
    }

    private func installKeyboardMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard editingAction == nil else { return event }
            guard !model.isHeaderKeyboardFocusActive else { return event }

            if event.modifierFlags.contains(.command),
               Int(event.keyCode) == 51 {
                deleteSelectedAction()
                return nil
            }

            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "c" {
                copySelectedAction()
                return nil
            }

            guard event.modifierFlags.intersection([.command, .option, .control]).isEmpty else {
                return event
            }

            switch Int(event.keyCode) {
            case 48, 125:
                moveSelection(delta: 1)
                return nil
            case 49:
                runSelectedAction()
                return nil
            case 36, 76:
                editSelectedAction()
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
        guard !model.quickActions.isEmpty else { return }
        let currentIndex = model.quickActions.firstIndex(where: { $0.id == selectedActionID }) ?? 0
        let nextIndex = min(max(currentIndex + delta, 0), model.quickActions.count - 1)
        selectedActionID = model.quickActions[nextIndex].id
    }

    private func runSelectedAction() {
        guard let selectedActionID else { return }
        model.runQuickAction(selectedActionID)
    }

    private func editSelectedAction() {
        guard let selectedActionID,
              let action = model.quickActions.first(where: { $0.id == selectedActionID }) else { return }
        editingAction = QuickActionDraft(action: action)
    }

    private func copySelectedAction() {
        guard let selectedActionID else { return }
        model.copyQuickAction(selectedActionID)
    }

    private func deleteSelectedAction() {
        guard let selectedActionID else { return }
        model.deleteQuickAction(selectedActionID)
    }
}

private struct QuickActionCard: View {
    let action: QuickAction
    let clipTitle: String?
    let isSelected: Bool
    let onRun: () -> Void
    let onDuplicate: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(action.title)
                        .font(.headline)
                    Text(action.kind.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if let hotkey = action.hotkey {
                    Text(HotkeyRecorderView.describe(hotkey))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                }
                actionButton(systemName: "play.fill", helpText: "Run action", action: onRun)
                actionButton(systemName: "doc.on.doc", helpText: "Duplicate action", action: onDuplicate)
                actionButton(systemName: "pencil", helpText: "Edit action", action: onEdit)
                actionButton(systemName: "trash", helpText: "Delete action", role: .destructive, action: onDelete)
            }

            Text(detailText)
                .font(.body.monospaced())
                .lineLimit(4)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .glassCard()
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.white.opacity(0.4) : .clear, lineWidth: 2)
        )
    }

    private var detailText: String {
        switch action.kind {
        case .pasteSavedClip:
            return clipTitle.map { "Saved clip: \($0)" } ?? "Saved clip is missing."
        default:
            return action.text.isEmpty ? "No content." : action.text
        }
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

private struct QuickActionEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel

    @State private var title: String
    @State private var kind: QuickActionKind
    @State private var text: String
    @State private var clipboardItemID: UUID?
    @State private var hasHotkey: Bool
    @State private var hotkey: HotkeyDefinition

    let draft: QuickActionDraft

    init(draft: QuickActionDraft) {
        self.draft = draft
        _title = State(initialValue: draft.title)
        _kind = State(initialValue: draft.kind)
        _text = State(initialValue: draft.text)
        _clipboardItemID = State(initialValue: draft.clipboardItemID)
        _hasHotkey = State(initialValue: draft.hotkey != nil)
        _hotkey = State(initialValue: draft.hotkey ?? .default)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(draft.actionID == nil ? "New Quick Action" : "Edit Quick Action")
                .font(.title3.bold())

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("Behavior", selection: $kind) {
                ForEach(QuickActionKind.allCases) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }

            if kind == .pasteSavedClip {
                Picker("Saved Clip", selection: $clipboardItemID) {
                    Text("Select a clip").tag(Optional<UUID>.none)
                    ForEach(model.keptClipboardItems + model.recentClipboardItems) { item in
                        Text(item.title).tag(Optional<UUID>(item.id))
                    }
                }
                .pickerStyle(.menu)
            } else {
                TextEditor(text: $text)
                    .font(.body.monospaced())
                    .frame(minHeight: 180)
                    .glassCard()
            }

            Toggle("Assign shortcut", isOn: $hasHotkey)
            if hasHotkey {
                HotkeyRecorderView(hotkey: $hotkey)
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    save()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!isValid)
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 420)
        .glassBackground()
    }

    private var isValid: Bool {
        switch kind {
        case .pasteSavedClip:
            clipboardItemID != nil
        default:
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func save() {
        let resolvedHotkey = hasHotkey ? hotkey : nil
        if let id = draft.actionID {
            model.updateQuickAction(
                id,
                title: title,
                kind: kind,
                text: text,
                clipboardItemID: clipboardItemID,
                hotkey: resolvedHotkey
            )
        } else {
            model.addQuickAction(
                title: title,
                kind: kind,
                text: text,
                clipboardItemID: clipboardItemID,
                hotkey: resolvedHotkey
            )
        }
        dismiss()
    }
}

private struct QuickActionDraft: Identifiable {
    var id: UUID
    var actionID: UUID?
    var title: String
    var kind: QuickActionKind
    var text: String
    var clipboardItemID: UUID?
    var hotkey: HotkeyDefinition?

    static let new = QuickActionDraft(
        id: UUID(),
        actionID: nil,
        title: "",
        kind: .typeText,
        text: "",
        clipboardItemID: nil,
        hotkey: nil
    )

    init(
        id: UUID,
        actionID: UUID?,
        title: String,
        kind: QuickActionKind,
        text: String,
        clipboardItemID: UUID?,
        hotkey: HotkeyDefinition?
    ) {
        self.id = id
        self.actionID = actionID
        self.title = title
        self.kind = kind
        self.text = text
        self.clipboardItemID = clipboardItemID
        self.hotkey = hotkey
    }

    init(action: QuickAction) {
        self.init(
            id: action.id,
            actionID: action.id,
            title: action.title,
            kind: action.kind,
            text: action.text,
            clipboardItemID: action.clipboardItemID,
            hotkey: action.hotkey
        )
    }
}
