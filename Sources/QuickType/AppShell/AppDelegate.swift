import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    weak var captureWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        let bundledIconURL = Bundle.module.url(forResource: "QT", withExtension: "png")
        let fallbackIconURL = URL(fileURLWithPath: "/Users/lincolnbanry/Documents/QT.png")
        if let image = bundledIconURL.flatMap(NSImage.init(contentsOf:))
            ?? NSImage(contentsOf: fallbackIconURL) {
            NSApp.applicationIconImage = image
        }
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
