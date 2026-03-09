import SwiftUI

struct PromptLibraryView: View {
    @EnvironmentObject private var model: AppModel
    @State private var editingPrompt: PromptDraft?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Prompt Library")
                    .font(.title3.bold())
                Spacer()
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
                List {
                    ForEach(model.prompts) { prompt in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Text(prompt.title)
                                        .font(.headline)
                                    if model.settings.defaultPromptID == prompt.id {
                                        Text("Default")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(.thinMaterial, in: Capsule())
                                    }
                                }
                                Text(prompt.body)
                                    .font(.body.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                            Spacer()
                            iconButton(systemName: "star.fill", helpText: "Set default") {
                                model.setDefaultPrompt(prompt.id)
                            }
                            iconButton(systemName: "pencil", helpText: "Edit prompt") {
                                editingPrompt = PromptDraft(prompt: prompt)
                            }
                            iconButton(systemName: "trash", helpText: "Delete prompt", role: .destructive) {
                                model.deletePrompt(prompt.id)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .scrollContentBackground(.hidden)
                .glassCard()
            }
        }
        .padding(8)
        .sheet(item: $editingPrompt) { draft in
            PromptEditor(draft: draft)
                .environmentObject(model)
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
