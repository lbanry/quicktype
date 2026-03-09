#if canImport(XCTest)
import XCTest
@testable import QuickType

final class QuickActionRepositoryTests: XCTestCase {
    func testQuickActionRepositoryRoundTripsActions() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let url = dir.appendingPathComponent("quick_actions.json")
        let repository = JSONQuickActionRepository(fileURL: url)

        let actions = [
            QuickAction(
                id: UUID(),
                title: "Paste Greeting",
                kind: .typeText,
                text: "Hello world",
                clipboardItemID: nil,
                hotkey: HotkeyDefinition.default,
                createdAt: Date(),
                updatedAt: Date()
            ),
            QuickAction(
                id: UUID(),
                title: "Paste Saved Clip",
                kind: .pasteSavedClip,
                text: "",
                clipboardItemID: UUID(),
                hotkey: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]

        try repository.saveQuickActions(actions)
        let loaded = try repository.loadQuickActions()

        XCTAssertEqual(loaded, actions)
    }
}
#endif
