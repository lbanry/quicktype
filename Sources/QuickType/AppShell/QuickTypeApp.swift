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
            settingsStore: JSONSettingsStore(),
            bookmarkService: bookmarkService,
            fileWriter: AtomicFileWriter(),
            recoveryService: RecoveryService(bookmarkService: bookmarkService),
            hotkeyService: GlobalHotkeyService()
        )
        _model = StateObject(wrappedValue: model)
    }

    var body: some Scene {
        WindowGroup("Capture") {
            Group {
                if model.noteTargets.isEmpty {
                    OnboardingView()
                } else {
                    CaptureView()
                }
            }
            .environmentObject(model)
            .frame(minWidth: 520, minHeight: 360)
            .onAppear {
                model.bootstrap {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "capture")
                }
            }
            .onOpenURL { url in
                model.handleIncomingURL(url)
            }
        }
        .defaultSize(width: 620, height: 420)
        .windowResizability(.contentSize)
        .commands {
            CommandMenu("QuickType") {
                Button("Open Capture") {
                    NSApp.activate(ignoringOtherApps: true)
                    openWindow(id: "capture")
                }
                .keyboardShortcut("t", modifiers: [.command, .option])

                Button("Open Settings") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
        }

        MenuBarExtra("QuickType", systemImage: "note.text") {
            Button("Open Capture") {
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: "capture")
            }
            Button("Open Settings") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
