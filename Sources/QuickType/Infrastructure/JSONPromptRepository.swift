import Foundation

final class JSONPromptRepository: PromptRepositoryProtocol {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL = AppPaths.promptsFile) {
        self.fileURL = fileURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadPrompts() throws -> [SavedPrompt] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            try savePrompts([])
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([SavedPrompt].self, from: data)
    }

    func savePrompts(_ prompts: [SavedPrompt]) throws {
        let data = try encoder.encode(prompts)
        try data.write(to: fileURL, options: .atomic)
    }
}
