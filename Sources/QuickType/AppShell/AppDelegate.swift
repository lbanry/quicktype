import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var captureWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func registerCaptureWindow(_ window: NSWindow?) {
        captureWindow = window
    }

    @discardableResult
    func focusCaptureWindow() -> Bool {
        guard let captureWindow else { return false }
        if captureWindow.isMiniaturized {
            captureWindow.deminiaturize(nil)
        }
        captureWindow.makeKeyAndOrderFront(nil)
        captureWindow.orderFrontRegardless()
        return true
    }
}
