import Foundation

final class JSONLinkRepository: LinkRepositoryProtocol {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL = AppPaths.linksFile) {
        self.fileURL = fileURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadLinks() throws -> [SavedLink] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            try saveLinks([])
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([SavedLink].self, from: data)
    }

    func saveLinks(_ links: [SavedLink]) throws {
        let data = try encoder.encode(links)
        try data.write(to: fileURL, options: .atomic)
    }
}
