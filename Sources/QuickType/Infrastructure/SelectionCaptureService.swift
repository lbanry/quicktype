import AppKit
import ApplicationServices
import Carbon
import Foundation

enum SelectionCaptureError: LocalizedError {
    case noFrontmostApplication
    case accessibilityPermissionRequired
    case noSelectedText

    var errorDescription: String? {
        switch self {
        case .noFrontmostApplication:
            return "No frontmost application was detected."
        case .accessibilityPermissionRequired:
            return "Accessibility permission is required. Enable QuickType in System Settings > Privacy & Security > Accessibility."
        case .noSelectedText:
            return "No highlighted text was captured. Ensure text is selected and accessibility permissions are granted."
        }
    }
}

final class SelectionCaptureService: SelectionCaptureServiceProtocol {
    func captureCurrentSelection(preferredProcessID: pid_t?) throws -> SelectionCapture {
        guard let targetApp = resolveTargetApplication(preferredProcessID: preferredProcessID) else {
            throw SelectionCaptureError.noFrontmostApplication
        }

        let appName = targetApp.localizedName ?? "Unknown App"
        let bundleID = targetApp.bundleIdentifier ?? "unknown.bundle"
        let windowTitle = focusedWindowTitle(for: targetApp.processIdentifier)
        let pageURL = sourceURL(for: bundleID)

        guard AXIsProcessTrusted() else {
            throw SelectionCaptureError.accessibilityPermissionRequired
        }

        if let selected = selectedTextViaAccessibility(pid: targetApp.processIdentifier) {
            return SelectionCapture(
                text: selected,
                sourceAppName: appName,
                sourceBundleID: bundleID,
                sourceWindowTitle: windowTitle,
                sourceURL: pageURL,
                capturedAt: Date()
            )
        }

        let pasteboard = NSPasteboard.general
        let initialChangeCount = pasteboard.changeCount

        targetApp.activate(options: [.activateIgnoringOtherApps])
        usleep(120_000)
        triggerCopyShortcut()

        let timeout = Date().addingTimeInterval(0.8)
        while Date() < timeout {
            if pasteboard.changeCount != initialChangeCount {
                break
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.03))
        }

        guard pasteboard.changeCount != initialChangeCount,
              let copied = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !copied.isEmpty else {
            throw SelectionCaptureError.noSelectedText
        }

        return SelectionCapture(
            text: copied,
            sourceAppName: appName,
            sourceBundleID: bundleID,
            sourceWindowTitle: windowTitle,
            sourceURL: pageURL,
            capturedAt: Date()
        )
    }

    private func resolveTargetApplication(preferredProcessID: pid_t?) -> NSRunningApplication? {
        if let preferredProcessID,
           let preferredApp = NSRunningApplication(processIdentifier: preferredProcessID),
           !preferredApp.isTerminated {
            return preferredApp
        }

        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.bundleIdentifier != Bundle.main.bundleIdentifier {
            return frontmost
        }
        return nil
    }

    private func triggerCopyShortcut() {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: CGKeyCode(kVK_ANSI_C), keyDown: false) else {
            return
        }

        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func focusedWindowTitle(for pid: pid_t) -> String? {
        let appRef = AXUIElementCreateApplication(pid)
        var focusedWindow: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        guard focusedResult == .success, let windowRef = focusedWindow else {
            return nil
        }
        let window = unsafeDowncast(windowRef, to: AXUIElement.self)

        var titleRef: CFTypeRef?
        let titleResult = AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
        guard titleResult == .success else {
            return nil
        }

        return titleRef as? String
    }

    private func selectedTextViaAccessibility(pid: pid_t) -> String? {
        let appRef = AXUIElementCreateApplication(pid)
        var focusedElementRef: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(appRef, kAXFocusedUIElementAttribute as CFString, &focusedElementRef)
        guard focusedResult == .success, let focusedElementRef else {
            return nil
        }

        let focusedElement = unsafeDowncast(focusedElementRef, to: AXUIElement.self)
        var selectedTextRef: CFTypeRef?
        let selectionResult = AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedTextRef)
        guard selectionResult == .success, let selectedText = selectedTextRef as? String else {
            return nil
        }

        let trimmed = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func sourceURL(for bundleID: String) -> String? {
        switch bundleID {
        case "com.apple.Safari":
            return runAppleScript("tell application \"Safari\" to return URL of front document")
        case "com.google.Chrome":
            return runAppleScript("tell application \"Google Chrome\" to return URL of active tab of front window")
        case "company.thebrowser.Browser":
            return runAppleScript("tell application \"Arc\" to return URL of active tab of front window")
        case "com.brave.Browser":
            return runAppleScript("tell application \"Brave Browser\" to return URL of active tab of front window")
        case "com.microsoft.edgemac":
            return runAppleScript("tell application \"Microsoft Edge\" to return URL of active tab of front window")
        default:
            return nil
        }
    }

    private func runAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else {
            return nil
        }
        var errorInfo: NSDictionary?
        let output = script.executeAndReturnError(&errorInfo)
        if errorInfo != nil {
            return nil
        }
        let value = output.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == true ? nil : value
    }
}
