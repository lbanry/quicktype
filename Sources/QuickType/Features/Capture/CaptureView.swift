import SwiftUI

struct CaptureView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @FocusState private var editorFocused: Bool
    @State private var showCommandPalette = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 14)

            Divider()
                .overlay(Color.white.opacity(0.12))

            Group {
                switch model.captureDashboardTab {
                case .actions:
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            captureComposer
                            QuickActionsView()
                        }
                        .padding()
                    }
                case .paste:
                    ClipboardView()
                case .links:
                    LinksView()
                case .prompts:
                    PromptLibraryView()
                        .padding()
                }
            }
        }
        .glassBackground()
        .sheet(isPresented: $showCommandPalette) {
            CommandPaletteView()
                .environmentObject(model)
        }
        .sheet(isPresented: $model.isPromptPickerPresented) {
            PromptPickerView()
                .environmentObject(model)
        }
        .onAppear {
            editorFocused = true
        }
    }

    @ViewBuilder
    private var headerBar: some View {
        HStack(spacing: 12) {
            Color.clear
                .frame(width: 72, height: 28)

            Spacer()

            Text("QuickType - Capture")
                .font(.title3.weight(.semibold))

            Spacer()

            HStack(spacing: 10) {
                tabButton(systemName: "square.grid.2x2.fill", tab: .actions, helpText: "Actions")
                utilityButton(systemName: "gearshape", helpText: "Settings") {
                    openWindow(id: "settings-window")
                }
                tabButton(systemName: "sparkles", tab: .prompts, helpText: "Prompts")
                tabButton(systemName: "link", tab: .links, helpText: "Links")
                tabButton(systemName: "doc.on.clipboard", tab: .paste, helpText: "Paste")
            }
            .frame(width: 186, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var captureComposer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick Note")
                    .font(.title3.bold())

                Spacer()

                Picker("Target", selection: Binding(
                    get: { model.selectedNoteID },
                    set: { model.selectedNoteID = $0 }
                )) {
                    ForEach(model.noteTargets) { note in
                        Text(note.displayName).tag(Optional(note.id))
                    }
                }
                .pickerStyle(.menu)

                Button("Cmd+K") {
                    showCommandPalette = true
                }
                .glassControl()
                .help("Command palette")
            }

            if model.noteTargets.isEmpty {
                Text("Create or import a note target from the command palette before saving quick notes.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard()
            } else {
                TextEditor(text: $model.captureText)
                    .font(.body.monospaced())
                    .focused($editorFocused)
                    .frame(minHeight: 140)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .glassCard()
            }

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
                .glassControl()
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(model.noteTargets.isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .glassCard()
    }

    @ViewBuilder
    private func tabButton(systemName: String, tab: CaptureDashboardTab, helpText: String) -> some View {
        Button {
            model.captureDashboardTab = tab
        } label: {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(
                    model.captureDashboardTab == tab ? .regularMaterial : .thinMaterial,
                    in: Circle()
                )
                .overlay(
                    Circle()
                        .stroke(
                            model.captureDashboardTab == tab ? Color.white.opacity(0.32) : Color.white.opacity(0.18),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(GlassIconButtonStyle())
        .help(helpText)
    }

    @ViewBuilder
    private func utilityButton(systemName: String, helpText: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 28, height: 28)
                .background(.thinMaterial, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                )
        }
        .buttonStyle(GlassIconButtonStyle())
        .help(helpText)
    }
}

struct CommandPaletteView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openWindow) private var openWindow
    @State private var search = ""

    private var actions: [(String, () -> Void)] {
        let quickActionItems = model.quickActions.map { action in
            ("Run: \(action.title)", { model.runQuickAction(action.id) })
        }

        return [
            ("Create Note Target", { model.createNoteTarget() }),
            ("Import Note Target", { model.importNoteTarget() }),
            ("Open Selected Note", { model.openSelectedInExternalApp() }),
            ("Reveal in Finder", { model.revealSelectedNoteInFinder() }),
            ("Send Selection to AI", { model.sendSelectionToConfiguredAI() }),
            ("Copy Selection to New Note", { model.copyHighlightedTextToNewNote() }),
            ("Save Selection to Obsidian", { model.saveHighlightedTextToObsidian(summarizeFirst: false) }),
            ("Choose Obsidian Folder and Save", { model.chooseObsidianFolderAndSaveHighlightedText(summarizeFirst: false) }),
            ("Summarize and Save to Obsidian", { model.saveHighlightedTextToObsidian(summarizeFirst: true) }),
            ("Refresh Recovery Scan", { model.refreshRecoveryIssues() }),
            ("Open Settings", { openWindow(id: "settings-window") })
        ] + quickActionItems
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
        .glassBackground()
    }

    private var filteredActions: [(String, () -> Void)] {
        if search.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return actions
        }
        return actions.filter { $0.0.localizedCaseInsensitiveContains(search) }
    }
}
