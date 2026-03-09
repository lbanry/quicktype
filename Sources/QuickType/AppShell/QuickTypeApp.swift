import AppKit
import SwiftUI

@main
struct QuickTypeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow

    @StateObject private var model: AppModel

    init() {
        let bookmarkService = BookmarkService()
        let model = AppModel(
            noteRepository: JSONNoteRepository(),
            clipboardRepository: JSONClipboardRepository(),
            quickActionRepository: JSONQuickActionRepository(),
            promptRepository: JSONPromptRepository(),
            linkRepository: JSONLinkRepository(),
            settingsStore: JSONSettingsStore(),
            bookmarkService: bookmarkService,
            fileWriter: AtomicFileWriter(),
            recoveryService: RecoveryService(bookmarkService: bookmarkService),
            hotkeyService: GlobalHotkeyService(),
            selectionCaptureService: SelectionCaptureService(),
            aiAutomationService: MacAIAutomationService(),
            frontmostApplicationURLProvider: { NSWorkspace.shared.frontmostApplication?.bundleURL }
        )
        _model = StateObject(wrappedValue: model)
    }

    private func openOrFocusCaptureWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if !appDelegate.focusCaptureWindow() {
            openWindow(id: "capture")
        }
    }

    var body: some Scene {
        WindowGroup("Capture", id: "capture") {
            Group {
                if model.noteTargets.isEmpty {
                    OnboardingView()
                } else {
                    CaptureView()
                }
            }
            .environmentObject(model)
            .frame(minWidth: 520, minHeight: 360)
            .background(
                WindowAccessor { window in
                    appDelegate.registerCaptureWindow(window)
                }
            )
            .onAppear {
                model.bootstrap {
                    openOrFocusCaptureWindow()
                }
            }
            .onOpenURL { url in
                model.handleIncomingURL(url)
            }
        }
        .defaultSize(width: 620, height: 420)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandMenu("QuickType") {
                Button("Open Capture") {
                    openOrFocusCaptureWindow()
                }
                .keyboardShortcut("t", modifiers: [.command, .option])

                Button("Send Selection to AI") {
                    model.sendSelectionToConfiguredAI()
                }
                .keyboardShortcut("c", modifiers: [.command, .option, .shift])

                Button("Save Selection to Obsidian") {
                    model.saveHighlightedTextToObsidian(summarizeFirst: false)
                }
                .keyboardShortcut("o", modifiers: [.command, .option, .shift])

                Button("Choose Obsidian Folder and Save") {
                    model.chooseObsidianFolderAndSaveHighlightedText(summarizeFirst: false)
                }

                Button("Summarize and Save to Obsidian") {
                    model.saveHighlightedTextToObsidian(summarizeFirst: true)
                }

                Button("Open Settings") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "settings-window")
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }

        WindowGroup("Settings", id: "settings-window") {
            SettingsView()
                .environmentObject(model)
        }
        .windowResizability(.contentSize)

        MenuBarExtra("QuickType", systemImage: "note.text") {
            Button("Open Capture") {
                openOrFocusCaptureWindow()
            }
            Button("Open Settings") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "settings-window")
            }
            Button("Send Selection to AI") {
                model.sendSelectionToConfiguredAI()
            }
            Button("Save Selection to Obsidian") {
                model.saveHighlightedTextToObsidian(summarizeFirst: false)
            }
            Button("Choose Obsidian Folder and Save") {
                model.chooseObsidianFolderAndSaveHighlightedText(summarizeFirst: false)
            }
            Button("Summarize and Save to Obsidian") {
                model.saveHighlightedTextToObsidian(summarizeFirst: true)
            }
            Divider()
            if let selected = model.selectedNote {
                Text(selected.displayName)
                    .font(.footnote)
                Button("Open Selected Note") {
                    model.openSelectedInExternalApp()
                }
            }
            Divider()
            Button("Quit") { NSApp.terminate(nil) }
        }
    }
}
