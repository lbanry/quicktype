import Foundation

enum AppPaths {
    static let bundleID = "dev.quicktype.app"

    static var appSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("QuickType", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static var settingsFile: URL {
        appSupportDirectory.appendingPathComponent("settings.json")
    }

    static var notesIndexFile: URL {
        appSupportDirectory.appendingPathComponent("notes_index.json")
    }

    static var clipboardItemsFile: URL {
        appSupportDirectory.appendingPathComponent("clipboard_items.json")
    }

    static var quickActionsFile: URL {
        appSupportDirectory.appendingPathComponent("quick_actions.json")
    }

    static var promptsFile: URL {
        appSupportDirectory.appendingPathComponent("prompts.json")
    }

    static var linksFile: URL {
        appSupportDirectory.appendingPathComponent("links.json")
    }

    static var backupsDirectory: URL {
        let dir = appSupportDirectory.appendingPathComponent("Backups", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static var logsFile: URL {
        appSupportDirectory.appendingPathComponent("quicktype.log")
    }

    static var clipsDirectory: URL {
        let dir = appSupportDirectory.appendingPathComponent("Clips", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static var obsidianPayloadsDirectory: URL {
        let dir = appSupportDirectory.appendingPathComponent("ObsidianPayloads", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }
}
