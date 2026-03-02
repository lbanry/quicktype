import Foundation

protocol NoteRepositoryProtocol {
    func loadNoteTargets() throws -> [NoteTarget]
    func saveNoteTargets(_ targets: [NoteTarget]) throws
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
    func stop()
}

protocol RecoveryServiceProtocol {
    func scan(noteTargets: [NoteTarget]) -> [RecoveryIssue]
}

protocol SelectionCaptureServiceProtocol {
    func captureCurrentSelection(preferredProcessID: pid_t?) throws -> SelectionCapture
}
