import Foundation

protocol NoteRepositoryProtocol {
    func loadNoteTargets() throws -> [NoteTarget]
    func saveNoteTargets(_ targets: [NoteTarget]) throws
}

protocol ClipboardRepositoryProtocol {
    func loadKeptClipboardItems() throws -> [ClipboardItem]
    func saveKeptClipboardItems(_ items: [ClipboardItem]) throws
}

protocol QuickActionRepositoryProtocol {
    func loadQuickActions() throws -> [QuickAction]
    func saveQuickActions(_ actions: [QuickAction]) throws
}

protocol PromptRepositoryProtocol {
    func loadPrompts() throws -> [SavedPrompt]
    func savePrompts(_ prompts: [SavedPrompt]) throws
}

protocol LinkRepositoryProtocol {
    func loadLinks() throws -> [SavedLink]
    func saveLinks(_ links: [SavedLink]) throws
}

protocol BookmarkServiceProtocol {
    func makeBookmark(for fileURL: URL) throws -> Data
    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool)
}

protocol FileWriterProtocol {
    func write(
        entry: CaptureEntry,
        to note: NoteTarget,
        insertion: InsertionPosition,
        settings: AppSettings
    ) throws -> WriteResult
}

protocol SettingsStoreProtocol {
    func loadSettings() throws -> AppSettings
    func saveSettings(_ settings: AppSettings) throws
}

protocol HotkeyServiceProtocol: AnyObject {
    var onHotkeyPressed: (() -> Void)? { get set }
    var onClipHotkeyPressed: (() -> Void)? { get set }
    func start(with hotkey: HotkeyDefinition, clipHotkey: HotkeyDefinition)
    func update(hotkey: HotkeyDefinition)
    func update(clipHotkey: HotkeyDefinition)
    func setQuickActionHotkeys(_ actions: [QuickAction], handler: @escaping (UUID) -> Void)
    func stop()
}

protocol RecoveryServiceProtocol {
    func scan(noteTargets: [NoteTarget]) -> [RecoveryIssue]
}

protocol SelectionCaptureServiceProtocol {
    func captureCurrentSelection(preferredProcessID: pid_t?) throws -> SelectionCapture
}

protocol AIAutomationServiceProtocol {
    @MainActor
    func submit(prompt: String, appURL: URL, autoSubmit: Bool) throws
}
