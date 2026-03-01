import Foundation

final class JSONNoteRepository: NoteRepositoryProtocol {
    private let indexURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(indexURL: URL = AppPaths.notesIndexFile) {
        self.indexURL = indexURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadNoteTargets() throws -> [NoteTarget] {
        guard FileManager.default.fileExists(atPath: indexURL.path) else {
            try saveNoteTargets([])
            return []
        }
        let data = try Data(contentsOf: indexURL)
        return try decoder.decode([NoteTarget].self, from: data)
    }

    func saveNoteTargets(_ targets: [NoteTarget]) throws {
        let data = try encoder.encode(targets)
        try data.write(to: indexURL, options: .atomic)
    }
}
