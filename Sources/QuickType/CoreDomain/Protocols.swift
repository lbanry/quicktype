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
    func start(with hotkey: HotkeyDefinition)
    func update(hotkey: HotkeyDefinition)
    func stop()
}

protocol RecoveryServiceProtocol {
    func scan(noteTargets: [NoteTarget]) -> [RecoveryIssue]
}
