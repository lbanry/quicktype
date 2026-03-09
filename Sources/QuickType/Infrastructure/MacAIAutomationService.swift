import AppKit
import Carbon
import Foundation

@MainActor
final class MacAIAutomationService: AIAutomationServiceProtocol {
    func submit(prompt: String, appURL: URL, autoSubmit: Bool) throws {
        guard FileManager.default.fileExists(atPath: appURL.path) else {
            throw NSError(domain: "QuickType", code: 3001, userInfo: [NSLocalizedDescriptionKey: "Configured AI app was not found."])
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(prompt, forType: .string)

        if let runningApp = runningApplication(for: appURL) {
            runningApp.activate(options: [.activateIgnoringOtherApps])
            schedulePaste(autoSubmit: autoSubmit)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: configuration) { app, error in
            if let error {
                Logger.error("Open AI app failed: \(error.localizedDescription)")
                return
            }

            Task { @MainActor in
                app?.activate(options: [.activateIgnoringOtherApps])
                self.schedulePaste(autoSubmit: autoSubmit)
            }
        }
    }

    private func runningApplication(for appURL: URL) -> NSRunningApplication? {
        if let bundleIdentifier = Bundle(url: appURL)?.bundleIdentifier,
           let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first {
            return runningApp
        }

        return NSWorkspace.shared.runningApplications.first { runningApp in
            runningApp.bundleURL?.standardizedFileURL == appURL.standardizedFileURL
        }
    }

    private func schedulePaste(autoSubmit: Bool) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.postKeystroke(keyCode: CGKeyCode(kVK_ANSI_V), modifiers: .maskCommand)
            if autoSubmit {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.postKeystroke(keyCode: CGKeyCode(kVK_Return), modifiers: [])
                }
            }
        }
    }

    private func postKeystroke(keyCode: CGKeyCode, modifiers: CGEventFlags) {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return
        }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        keyDown?.flags = modifiers
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyUp?.flags = modifiers
        keyUp?.post(tap: .cghidEventTap)
    }
}
