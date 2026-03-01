import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var editorFocused: Bool
    @State private var showCommandPalette = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Picker("Target", selection: Binding(
                    get: { model.selectedNoteID },
                    set: { model.selectedNoteID = $0 }
                )) {
                    ForEach(model.noteTargets) { note in
                        Text(note.displayName).tag(Optional(note.id))
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Button("Cmd+K") {
                    showCommandPalette = true
                }
                .help("Command palette")
            }

            TextEditor(text: $model.captureText)
                .font(.body.monospaced())
                .focused($editorFocused)
                .frame(minHeight: 200)

            HStack {
                Text(model.lastStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                Button("Save") {
                    model.saveCapture()
                    if model.settings.submitBehavior == .dismissWindow {
                        dismiss()
                    }
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.noteTargets.isEmpty)
            }
        }
        .padding()
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
                .environmentObject(model)
        }
        .onAppear {
            editorFocused = true
        }
    }
}

struct CommandPaletteView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var search = ""

    private var actions: [(String, () -> Void)] {
        [
            ("Create Note Target", { model.createNoteTarget() }),
            ("Import Note Target", { model.importNoteTarget() }),
            ("Open Selected Note", { model.openSelectedInExternalApp() }),
            ("Reveal in Finder", { model.revealSelectedNoteInFinder() }),
            ("Refresh Recovery Scan", { model.refreshRecoveryIssues() }),
            ("Open Settings", { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) })
        ]
    }

    var body: some View {
        VStack(alignment: .leading) {
            TextField("Search actions", text: $search)
                .textFieldStyle(.roundedBorder)

            List(filteredActions.indices, id: \.self) { index in
                Button(filteredActions[index].0) {
                    filteredActions[index].1()
                    dismiss()
                }
                .buttonStyle(.plain)
            }
            .frame(width: 420, height: 260)
        }
        .padding()
    }

    private var filteredActions: [(String, () -> Void)] {
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return actions
        }
        return actions.filter { $0.0.localizedCaseInsensitiveContains(search) }
    }
}
