import Foundation
import Carbon

enum NoteFormat: String, Codable, CaseIterable, Identifiable {
    case plainText
    case markdown

    var id: String { rawValue }
    var fileExtension: String {
        switch self {
        case .plainText: "txt"
        case .markdown: "md"
        }
    }
}

enum InsertionPosition: String, Codable, CaseIterable, Identifiable {
    case top
    case bottom

    var id: String { rawValue }
}

enum TimestampMode: String, Codable, CaseIterable, Identifiable {
    case dateTime
    case dateOnly
    case timeOnly
    case custom

    var id: String { rawValue }
}

enum SubmitBehavior: String, Codable, CaseIterable, Identifiable {
    case dismissWindow
    case keepWindowVisible

    var id: String { rawValue }
}

enum StayOnTopPolicy: String, Codable, CaseIterable, Identifiable {
    case always
    case onlyWhenActive

    var id: String { rawValue }
}

struct HotkeyDefinition: Codable, Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = HotkeyDefinition(
        keyCode: UInt32(kVK_ANSI_T),
        modifiers: UInt32(cmdKey) | UInt32(optionKey)
    )
}

struct NoteTarget: Identifiable, Codable, Hashable {
    var id: UUID
    var displayName: String
    var filePath: String
    var bookmarkData: Data?
    var format: NoteFormat
    var externalAppPath: String?
    var createdAt: Date
    var updatedAt: Date

    var fileURL: URL { URL(fileURLWithPath: filePath) }
    var externalAppURL: URL? { externalAppPath.map { URL(fileURLWithPath: $0) } }
}

struct CaptureEntry {
    var rawText: String
    var createdAt: Date
    var formattedText: String
}

struct WriteResult {
    var bytesWritten: Int
    var newFileSize: Int
    var backupCreated: Bool
    var warnings: [String]
}

enum RecoveryIssueType: String, Codable {
    case fileMissing
    case bookmarkStale
    case fileUnreadable
}

struct RecoveryIssue: Identifiable, Codable {
    var id: UUID
    var noteID: UUID
    var issueType: RecoveryIssueType
    var detectedAt: Date
    var remediationOptions: [String]
}

struct AppSettings: Codable, Equatable {
    static let currentSchemaVersion = 1

    var schemaVersion: Int
    var hotkey: HotkeyDefinition
    var insertionPosition: InsertionPosition
    var timestampMode: TimestampMode
    var customDateFormat: String
    var dateLocaleIdentifier: String
    var useUTC: Bool
    var submitBehavior: SubmitBehavior
    var stayOnTopPolicy: StayOnTopPolicy
    var showMenuBarIcon: Bool
    var launchAtLogin: Bool
    var backupRetentionCount: Int

    static let `default` = AppSettings(
        schemaVersion: AppSettings.currentSchemaVersion,
        hotkey: .default,
        insertionPosition: .bottom,
        timestampMode: .dateTime,
        customDateFormat: "yyyy-MM-dd HH:mm:ss",
        dateLocaleIdentifier: Locale.current.identifier,
        useUTC: false,
        submitBehavior: .dismissWindow,
        stayOnTopPolicy: .always,
        showMenuBarIcon: true,
        launchAtLogin: false,
        backupRetentionCount: 20
    )
}
