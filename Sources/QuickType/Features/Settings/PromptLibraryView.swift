import AppKit
import SwiftUI

struct PromptLibraryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingPrompt: PromptDraft?
    @State private var selectedPromptID: UUID?
    @State private var keyMonitor: Any?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Prompts")
                        .font(.title3.bold())
                        .help("Use Up/Down to move, Space to set default, Return to edit, Cmd+C to copy, Cmd+Delete to delete.")
                    Spacer()
                    Text("\(model.prompts.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.thinMaterial, in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.22), lineWidth: 1)
                        )
                    iconButton(systemName: "plus", helpText: "New prompt") {
                        editingPrompt = PromptDraft.new
                    }
                }

                if model.prompts.isEmpty {
                    Text("Add prompts here. `Shift+Cmd+C` will show them and Enter will use the default prompt.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard()
                } else {
                    ForEach(model.prompts) { prompt in
                        PromptCard(
                            prompt: prompt,
                            isDefault: model.settings.defaultPromptID == prompt.id,
                            isSelected: selectedPromptID == prompt.id,
                            onCopy: { model.copyPrompt(prompt.id) },
                            onSetDefault: { model.setDefaultPrompt(prompt.id) },
                            onEdit: { editingPrompt = PromptDraft(prompt: prompt) },
                            onDelete: { model.deletePrompt(prompt.id) }
                        )
                    }
                }
            }
            .padding(8)
        }
        .sheet(item: $editingPrompt) { draft in
            PromptEditor(draft: draft)
                .environmentObject(model)
        }
        .onAppear {
            syncSelection()
            installKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onChange(of: model.prompts) { _ in
            syncSelection()
        }
    }

    @ViewBuilder
    private func iconButton(
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

    private func syncSelection() {
        if let selectedPromptID, model.prompts.contains(where: { $0.id == selectedPromptID }) {
            return
        }
        selectedPromptID = model.prompts.first?.id
    }

    private func installKeyboardMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard editingPrompt == nil else { return event }
            guard !model.isHeaderKeyboardFocusActive else { return event }

            if event.modifierFlags.contains(.command),
               Int(event.keyCode) == 51 {
                deleteSelectedPrompt()
                return nil
            }

            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers?.lowercased() == "c" {
                copySelectedPrompt()
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
                setDefaultPrompt()
                return nil
            case 36, 76:
                editSelectedPrompt()
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
        guard !model.prompts.isEmpty else { return }
        let currentIndex = model.prompts.firstIndex(where: { $0.id == selectedPromptID }) ?? 0
        let nextIndex = min(max(currentIndex + delta, 0), model.prompts.count - 1)
        selectedPromptID = model.prompts[nextIndex].id
    }

    private func setDefaultPrompt() {
        guard let selectedPromptID else { return }
        model.setDefaultPrompt(selectedPromptID)
    }

    private func editSelectedPrompt() {
        guard let selectedPromptID,
              let prompt = model.prompts.first(where: { $0.id == selectedPromptID }) else { return }
        editingPrompt = PromptDraft(prompt: prompt)
    }

    private func copySelectedPrompt() {
        guard let selectedPromptID else { return }
        model.copyPrompt(selectedPromptID)
    }

    private func deleteSelectedPrompt() {
        guard let selectedPromptID else { return }
        model.deletePrompt(selectedPromptID)
    }
}

private struct PromptCard: View {
    let prompt: SavedPrompt
    let isDefault: Bool
    let isSelected: Bool
    let onCopy: () -> Void
    let onSetDefault: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(prompt.title)
                            .font(.headline)
                            .lineLimit(1)
                        if isDefault {
                            Text("Default")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.thinMaterial, in: Capsule())
                        }
                    }
                    Text(prompt.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                actionButton(systemName: "doc.on.doc", helpText: "Copy prompt", action: onCopy)
                actionButton(systemName: "star.fill", helpText: "Set default", action: onSetDefault)
                actionButton(systemName: "pencil", helpText: "Edit prompt", action: onEdit)
                actionButton(systemName: "trash", helpText: "Delete prompt", role: .destructive, action: onDelete)
            }

            Text(prompt.body)
                .font(.body.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(4)
                .textSelection(.enabled)

            HStack {
                Spacer()
                Text(prompt.updatedAt.formatted(date: .abbreviated, time: .shortened))
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
        .help("Prompt: Space set default, Return edit, Cmd+C copy, Cmd+Delete delete")
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

private struct PromptEditor: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var model: AppModel

    @State private var title: String
    @State private var bodyText: String
    let draft: PromptDraft

    init(draft: PromptDraft) {
        self.draft = draft
        _title = State(initialValue: draft.title)
        _bodyText = State(initialValue: draft.body)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(draft.promptID == nil ? "New Prompt" : "Edit Prompt")
                .font(.title3.bold())

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextEditor(text: $bodyText)
                .font(.body.monospaced())
                .frame(minHeight: 220)
                .glassCard()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    if let promptID = draft.promptID {
                        model.updatePrompt(promptID, title: title, body: bodyText)
                    } else {
                        model.addPrompt(title: title, body: bodyText)
                    }
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding()
        .frame(minWidth: 560, minHeight: 380)
        .glassBackground()
    }
}

private struct PromptDraft: Identifiable {
    let id: UUID
    let promptID: UUID?
    let title: String
    let body: String

    static let new = PromptDraft(id: UUID(), promptID: nil, title: "", body: "")

    init(id: UUID, promptID: UUID?, title: String, body: String) {
        self.id = id
        self.promptID = promptID
        self.title = title
        self.body = body
    }

    init(prompt: SavedPrompt) {
        self.init(id: prompt.id, promptID: prompt.id, title: prompt.title, body: prompt.body)
    }
}
