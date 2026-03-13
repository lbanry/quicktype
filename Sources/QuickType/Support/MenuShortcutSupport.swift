import Carbon
import SwiftUI

struct MenuShortcut {
    let key: KeyEquivalent
    let modifiers: SwiftUI.EventModifiers
}

extension HotkeyDefinition {
    var menuShortcut: MenuShortcut? {
        guard isEnabled, let key = keyEquivalent else { return nil }
        return MenuShortcut(key: key, modifiers: eventModifiers)
    }

    func matches(_ event: NSEvent) -> Bool {
        guard isEnabled else { return false }
        return keyCode == UInt32(event.keyCode) && modifiers == carbonFlags(from: event.modifierFlags)
    }

    private var keyEquivalent: KeyEquivalent? {
        switch keyCode {
        case UInt32(kVK_ANSI_A): return "a"
        case UInt32(kVK_ANSI_B): return "b"
        case UInt32(kVK_ANSI_C): return "c"
        case UInt32(kVK_ANSI_D): return "d"
        case UInt32(kVK_ANSI_E): return "e"
        case UInt32(kVK_ANSI_F): return "f"
        case UInt32(kVK_ANSI_G): return "g"
        case UInt32(kVK_ANSI_H): return "h"
        case UInt32(kVK_ANSI_I): return "i"
        case UInt32(kVK_ANSI_J): return "j"
        case UInt32(kVK_ANSI_K): return "k"
        case UInt32(kVK_ANSI_L): return "l"
        case UInt32(kVK_ANSI_M): return "m"
        case UInt32(kVK_ANSI_N): return "n"
        case UInt32(kVK_ANSI_O): return "o"
        case UInt32(kVK_ANSI_P): return "p"
        case UInt32(kVK_ANSI_Q): return "q"
        case UInt32(kVK_ANSI_R): return "r"
        case UInt32(kVK_ANSI_S): return "s"
        case UInt32(kVK_ANSI_T): return "t"
        case UInt32(kVK_ANSI_U): return "u"
        case UInt32(kVK_ANSI_V): return "v"
        case UInt32(kVK_ANSI_W): return "w"
        case UInt32(kVK_ANSI_X): return "x"
        case UInt32(kVK_ANSI_Y): return "y"
        case UInt32(kVK_ANSI_Z): return "z"
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
        default: return nil
        }
    }

    private var eventModifiers: SwiftUI.EventModifiers {
        var result: SwiftUI.EventModifiers = []
        if modifiers & UInt32(cmdKey) != 0 { result.insert(.command) }
        if modifiers & UInt32(optionKey) != 0 { result.insert(.option) }
        if modifiers & UInt32(controlKey) != 0 { result.insert(.control) }
        if modifiers & UInt32(shiftKey) != 0 { result.insert(.shift) }
        return result
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
