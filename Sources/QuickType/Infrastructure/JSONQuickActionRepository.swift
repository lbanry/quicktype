import Foundation

final class JSONQuickActionRepository: QuickActionRepositoryProtocol {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL = AppPaths.quickActionsFile) {
        self.fileURL = fileURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadQuickActions() throws -> [QuickAction] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            try saveQuickActions([])
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([QuickAction].self, from: data)
    }

    func saveQuickActions(_ actions: [QuickAction]) throws {
        let data = try encoder.encode(actions)
        try data.write(to: fileURL, options: .atomic)
    }
}
