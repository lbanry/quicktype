#if canImport(XCTest)
import XCTest
@testable import QuickType

final class LinkRepositoryTests: XCTestCase {
    func testLinkRepositoryRoundTripsLinks() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("links.json")
        let repository = JSONLinkRepository(fileURL: url)

        let links = [
            SavedLink(
                id: UUID(),
                title: "Example",
                url: "https://example.com",
                folderPath: "Research/AI",
                summary: "Summary",
                notes: "Notes",
                createdAt: Date(),
                updatedAt: Date(),
                aiPrompt: nil,
                aiRequestDate: nil,
                aiResponseDate: nil,
                awaitingAIResponse: false
            )
        ]

        try repository.saveLinks(links)
        let loaded = try repository.loadLinks()

        XCTAssertEqual(loaded, links)
    }
}
#endif
