import AppKit
import Carbon

final class GlobalHotkeyService: HotkeyServiceProtocol {
    var onHotkeyPressed: (() -> Void)?
    var onClipHotkeyPressed: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var clipHotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var quickActionRefs: [UInt32: EventHotKeyRef] = [:]
    private var quickActionHandlers: [UInt32: () -> Void] = [:]

    deinit {
        stop()
    }

    func start(with hotkey: HotkeyDefinition, clipHotkey: HotkeyDefinition) {
        installHandlerIfNeeded()
        registerHotKey(hotkey, id: 1, ref: &hotKeyRef)
        registerHotKey(clipHotkey, id: 2, ref: &clipHotKeyRef)
    }

    func update(hotkey: HotkeyDefinition) {
        unregisterHotKey(ref: &hotKeyRef)
        registerHotKey(hotkey, id: 1, ref: &hotKeyRef)
    }

    func update(clipHotkey: HotkeyDefinition) {
        unregisterHotKey(ref: &clipHotKeyRef)
        registerHotKey(clipHotkey, id: 2, ref: &clipHotKeyRef)
    }

    func stop() {
        unregisterHotKey(ref: &hotKeyRef)
        unregisterHotKey(ref: &clipHotKeyRef)
        clearQuickActionHotkeys()
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }

    func setQuickActionHotkeys(_ actions: [QuickAction], handler: @escaping (UUID) -> Void) {
        clearQuickActionHotkeys()
        installHandlerIfNeeded()

        var nextID: UInt32 = 100
        for action in actions {
            guard let hotkey = action.hotkey else { continue }
            var ref: EventHotKeyRef?
            registerHotKey(hotkey, id: nextID, ref: &ref)
            if let ref {
                quickActionRefs[nextID] = ref
                quickActionHandlers[nextID] = { handler(action.id) }
                nextID += 1
            }
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData else { return noErr }
            let service = Unmanaged<GlobalHotkeyService>.fromOpaque(userData).takeUnretainedValue()

            var hkID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
            if hkID.id == 1 {
                service.onHotkeyPressed?()
            } else if hkID.id == 2 {
                service.onClipHotkeyPressed?()
            } else if let handler = service.quickActionHandlers[hkID.id] {
                handler()
            }
            return noErr
        }

        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandlerRef
        )
    }

    private func registerHotKey(_ hotkey: HotkeyDefinition, id: UInt32, ref: inout EventHotKeyRef?) {
        let hotKeyID = EventHotKeyID(signature: OSType(0x51545950), id: id)
        RegisterEventHotKey(
            hotkey.keyCode,
            hotkey.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
    }

    private func unregisterHotKey(ref: inout EventHotKeyRef?) {
        if let hotKeyRef = ref {
            UnregisterEventHotKey(hotKeyRef)
            ref = nil
        }
    }

    private func clearQuickActionHotkeys() {
        for (_, hotKeyRef) in quickActionRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        quickActionRefs.removeAll()
        quickActionHandlers.removeAll()
    }
}
