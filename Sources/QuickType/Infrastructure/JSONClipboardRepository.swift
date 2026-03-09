import Foundation

final class JSONClipboardRepository: ClipboardRepositoryProtocol {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL = AppPaths.clipboardItemsFile) {
        self.fileURL = fileURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadKeptClipboardItems() throws -> [ClipboardItem] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            try saveKeptClipboardItems([])
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([ClipboardItem].self, from: data)
    }

    func saveKeptClipboardItems(_ items: [ClipboardItem]) throws {
        let data = try encoder.encode(items)
        try data.write(to: fileURL, options: .atomic)
    }
}
