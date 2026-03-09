#if canImport(XCTest)
import XCTest
@testable import QuickType

final class SettingsStoreTests: XCTestCase {
    func testMigrationUpdatesSchemaVersionBackupRetentionAndAISettings() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let url = tempDir.appendingPathComponent("settings.json")
        var old = AppSettings.default
        old.schemaVersion = 0
        old.backupRetentionCount = 0

        let encoder = JSONEncoder()
        try encoder.encode(old).write(to: url)

        let store = JSONSettingsStore(fileURL: url)
        let migrated = try store.loadSettings()

        XCTAssertEqual(migrated.schemaVersion, AppSettings.currentSchemaVersion)
        XCTAssertEqual(migrated.backupRetentionCount, AppSettings.default.backupRetentionCount)
        XCTAssertEqual(migrated.aiPromptTemplate, AppSettings.default.aiPromptTemplate)
        XCTAssertEqual(migrated.aiAppPath, "")
        XCTAssertTrue(migrated.aiAutoSubmit)
    }
}
#endif
