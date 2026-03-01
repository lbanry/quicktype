import Foundation

final class RecoveryService: RecoveryServiceProtocol {
    private let bookmarkService: BookmarkServiceProtocol

    init(bookmarkService: BookmarkServiceProtocol) {
        self.bookmarkService = bookmarkService
    }

    func scan(noteTargets: [NoteTarget]) -> [RecoveryIssue] {
        noteTargets.compactMap { note in
            if !FileManager.default.fileExists(atPath: note.filePath) {
                return RecoveryIssue(
                    id: UUID(),
                    noteID: note.id,
                    issueType: .fileMissing,
                    detectedAt: Date(),
                    remediationOptions: ["Locate file", "Remove note target"]
                )
            }

            if let bookmark = note.bookmarkData {
                do {
                    let resolved = try bookmarkService.resolveBookmark(bookmark)
                    if resolved.isStale {
                        return RecoveryIssue(
                            id: UUID(),
                            noteID: note.id,
                            issueType: .bookmarkStale,
                            detectedAt: Date(),
                            remediationOptions: ["Refresh bookmark"]
                        )
                    }
                } catch {
                    return RecoveryIssue(
                        id: UUID(),
                        noteID: note.id,
                        issueType: .fileUnreadable,
                        detectedAt: Date(),
                        remediationOptions: ["Relink file", "Remove note target"]
                    )
                }
            }

            return nil
        }
    }
}
