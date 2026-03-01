import Foundation

final class JSONSettingsStore: SettingsStoreProtocol {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL = AppPaths.settingsFile) {
        self.fileURL = fileURL
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func loadSettings() throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            try saveSettings(.default)
            return .default
        }
        let data = try Data(contentsOf: fileURL)
        var settings = try decoder.decode(AppSettings.self, from: data)
        if settings.schemaVersion < AppSettings.currentSchemaVersion {
            settings = migrate(settings)
            try saveSettings(settings)
        }
        return settings
    }

    func saveSettings(_ settings: AppSettings) throws {
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }

    private func migrate(_ old: AppSettings) -> AppSettings {
        var migrated = old
        migrated.schemaVersion = AppSettings.currentSchemaVersion
        if migrated.backupRetentionCount <= 0 {
            migrated.backupRetentionCount = AppSettings.default.backupRetentionCount
        }
        return migrated
    }
}
