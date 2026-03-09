import AppKit
import Carbon
import SwiftUI

struct HotkeyRecorderView: NSViewRepresentable {
    @Binding var hotkey: HotkeyDefinition

    static func describe(_ hotkey: HotkeyDefinition) -> String {
        let key = keyCodeToString(hotkey.keyCode)
        let mods = modifiersDescription(hotkey.modifiers)
        return mods.isEmpty ? key : "\(mods)+\(key)"
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(hotkey: $hotkey)
    }

    func makeNSView(context: Context) -> NSButton {
        let button = NSButton(title: keyDescription(for: hotkey), target: context.coordinator, action: #selector(Coordinator.startRecording))
        button.bezelStyle = .rounded
        context.coordinator.button = button
        return button
    }

    func updateNSView(_ nsView: NSButton, context: Context) {
        nsView.title = context.coordinator.isRecording ? "Press keys..." : keyDescription(for: hotkey)
    }

    private func keyDescription(for hotkey: HotkeyDefinition) -> String {
        Self.describe(hotkey)
    }

    private static func modifiersDescription(_ flags: UInt32) -> String {
        var parts: [String] = []
        if flags & UInt32(cmdKey) != 0 { parts.append("Cmd") }
        if flags & UInt32(optionKey) != 0 { parts.append("Option") }
        if flags & UInt32(controlKey) != 0 { parts.append("Ctrl") }
        if flags & UInt32(shiftKey) != 0 { parts.append("Shift") }
        return parts.joined(separator: "+")
    }

    private static func keyCodeToString(_ keyCode: UInt32) -> String {
        switch keyCode {
        case UInt32(kVK_ANSI_A): return "A"
        case UInt32(kVK_ANSI_B): return "B"
        case UInt32(kVK_ANSI_C): return "C"
        case UInt32(kVK_ANSI_D): return "D"
        case UInt32(kVK_ANSI_E): return "E"
        case UInt32(kVK_ANSI_F): return "F"
        case UInt32(kVK_ANSI_G): return "G"
        case UInt32(kVK_ANSI_H): return "H"
        case UInt32(kVK_ANSI_I): return "I"
        case UInt32(kVK_ANSI_J): return "J"
        case UInt32(kVK_ANSI_K): return "K"
        case UInt32(kVK_ANSI_L): return "L"
        case UInt32(kVK_ANSI_M): return "M"
        case UInt32(kVK_ANSI_N): return "N"
        case UInt32(kVK_ANSI_O): return "O"
        case UInt32(kVK_ANSI_P): return "P"
        case UInt32(kVK_ANSI_Q): return "Q"
        case UInt32(kVK_ANSI_R): return "R"
        case UInt32(kVK_ANSI_S): return "S"
        case UInt32(kVK_ANSI_T): return "T"
        case UInt32(kVK_ANSI_U): return "U"
        case UInt32(kVK_ANSI_V): return "V"
        case UInt32(kVK_ANSI_W): return "W"
        case UInt32(kVK_ANSI_X): return "X"
        case UInt32(kVK_ANSI_Y): return "Y"
        case UInt32(kVK_ANSI_Z): return "Z"
        case UInt32(kVK_ANSI_0): return "0"
        case UInt32(kVK_ANSI_1): return "1"
        case UInt32(kVK_ANSI_2): return "2"
        case UInt32(kVK_ANSI_3): return "3"
        case UInt32(kVK_ANSI_4): return "4"
        case UInt32(kVK_ANSI_5): return "5"
        case UInt32(kVK_ANSI_6): return "6"
        case UInt32(kVK_ANSI_7): return "7"
        case UInt32(kVK_ANSI_8): return "8"
        case UInt32(kVK_ANSI_9): return "9"
        default: return "Key(\(keyCode))"
        }
    }

    @MainActor
    final class Coordinator: NSObject {
        @Binding var hotkey: HotkeyDefinition
        weak var button: NSButton?
        var monitor: Any?
        var isRecording = false

        init(hotkey: Binding<HotkeyDefinition>) {
            _hotkey = hotkey
        }

        @objc func startRecording() {
            if monitor != nil { return }
            isRecording = true
            button?.title = "Press keys..."

            monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
                guard let self else { return event }
                let flags = event.modifierFlags
                let carbonFlags = self.carbonFlags(from: flags)
                guard carbonFlags != 0 else {
                    self.stopRecording()
                    return nil
                }
                self.hotkey = HotkeyDefinition(keyCode: UInt32(event.keyCode), modifiers: carbonFlags)
                self.stopRecording()
                return nil
            }
        }

        private func stopRecording() {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
            self.monitor = nil
            self.isRecording = false
            button?.title = "Updated"
        }

        private func carbonFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
            var result: UInt32 = 0
            if flags.contains(.command) { result |= UInt32(cmdKey) }
            if flags.contains(.option) { result |= UInt32(optionKey) }
            if flags.contains(.control) { result |= UInt32(controlKey) }
            if flags.contains(.shift) { result |= UInt32(shiftKey) }
            return result
        }
    }
}
