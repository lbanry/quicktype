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

enum ObsidianRequestedAction: String, Codable {
    case save
    case summarizeThenSave = "summarize_then_save"
}

struct ObsidianTargetHint: Codable {
    var vaultName: String?
    var folderPath: String?
    var noteTitle: String?
}

struct ObsidianClipAttachment: Codable {
    var name: String
    var mimeType: String
    var sourcePath: String?
    var bytes: String?
    var sha256: String?
}

struct ObsidianClipPayloadV1: Codable {
    var version: Int
    var clipId: String
    var capturedAt: String
    var sourceAppName: String
    var sourceBundleId: String
    var sourceWindowTitle: String?
    var sourceUrl: String?
    var contentText: String
    var attachments: [ObsidianClipAttachment]
    var requestedAction: ObsidianRequestedAction
    var targetHint: ObsidianTargetHint?
}

struct HotkeyDefinition: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = HotkeyDefinition(
        keyCode: UInt32(kVK_ANSI_T),
        modifiers: UInt32(cmdKey) | UInt32(optionKey)
    )

    static let clipDefault = HotkeyDefinition(
        keyCode: UInt32(kVK_ANSI_C),
        modifiers: UInt32(cmdKey) | UInt32(shiftKey)
    )
}

enum QuickActionKind: String, Codable, CaseIterable, Identifiable {
    case typeText
    case copyText
    case promptSelection
    case pasteSavedClip

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .typeText: "Type Text"
        case .copyText: "Copy Text"
        case .promptSelection: "Prompt From Selection"
        case .pasteSavedClip: "Paste Saved Clip"
        }
    }
}

enum CaptureDashboardTab: String, Identifiable {
    case actions
    case paste
    case links
    case prompts

    var id: String { rawValue }
}

struct QuickAction: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var kind: QuickActionKind
    var text: String
    var clipboardItemID: UUID?
    var hotkey: HotkeyDefinition?
    var createdAt: Date
    var updatedAt: Date
}

struct SavedPrompt: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var body: String
    var createdAt: Date
    var updatedAt: Date
}

struct SavedLink: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var url: String
    var folderPath: String
    var summary: String?
    var notes: String?
    var createdAt: Date
    var updatedAt: Date
    var aiPrompt: String?
    var aiRequestDate: Date?
    var aiResponseDate: Date?
    var awaitingAIResponse: Bool
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

struct SelectionCapture {
    var text: String
    var sourceAppName: String
    var sourceBundleID: String
    var sourceWindowTitle: String?
    var sourceURL: String?
    var capturedAt: Date
}

struct ClipboardItem: Identifiable, Codable, Hashable {
    var id: UUID
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var isKept: Bool
    var aiPrompt: String?
    var aiResponse: String?
    var aiRequestDate: Date?
    var aiResponseDate: Date?
    var awaitingAIResponse: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case content
        case createdAt
        case updatedAt
        case isKept
        case aiPrompt
        case aiResponse
        case aiRequestDate
        case aiResponseDate
        case awaitingAIResponse
    }

    init(
        id: UUID,
        title: String,
        content: String,
        createdAt: Date,
        updatedAt: Date,
        isKept: Bool,
        aiPrompt: String? = nil,
        aiResponse: String? = nil,
        aiRequestDate: Date? = nil,
        aiResponseDate: Date? = nil,
        awaitingAIResponse: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.isKept = isKept
        self.aiPrompt = aiPrompt
        self.aiResponse = aiResponse
        self.aiRequestDate = aiRequestDate
        self.aiResponseDate = aiResponseDate
        self.awaitingAIResponse = awaitingAIResponse
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        isKept = try container.decode(Bool.self, forKey: .isKept)
        aiPrompt = try container.decodeIfPresent(String.self, forKey: .aiPrompt)
        aiResponse = try container.decodeIfPresent(String.self, forKey: .aiResponse)
        aiRequestDate = try container.decodeIfPresent(Date.self, forKey: .aiRequestDate)
        aiResponseDate = try container.decodeIfPresent(Date.self, forKey: .aiResponseDate)
        awaitingAIResponse = try container.decodeIfPresent(Bool.self, forKey: .awaitingAIResponse) ?? false
    }
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
    static let currentSchemaVersion = 5

    var schemaVersion: Int
    var hotkey: HotkeyDefinition
    var aiCaptureHotkey: HotkeyDefinition
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
    var obsidianIntegrationEnabled: Bool
    var obsidianDefaultFolderPath: String
    var obsidianDefaultSummarizeBeforeSave: Bool
    var obsidianTargetVaultName: String
    var aiAppPath: String
    var aiPromptTemplate: String
    var aiAutoSubmit: Bool
    var defaultPromptID: UUID?

    static let `default` = AppSettings(
        schemaVersion: AppSettings.currentSchemaVersion,
        hotkey: .default,
        aiCaptureHotkey: .clipDefault,
        insertionPosition: .bottom,
        timestampMode: .dateTime,
        customDateFormat: "yyyy-MM-dd HH:mm:ss",
        dateLocaleIdentifier: Locale.current.identifier,
        useUTC: false,
        submitBehavior: .dismissWindow,
        stayOnTopPolicy: .always,
        showMenuBarIcon: true,
        launchAtLogin: false,
        backupRetentionCount: 20,
        obsidianIntegrationEnabled: true,
        obsidianDefaultFolderPath: "",
        obsidianDefaultSummarizeBeforeSave: false,
        obsidianTargetVaultName: "",
        aiAppPath: "",
        aiPromptTemplate: "Summarize the following text concisely and preserve the key details:",
        aiAutoSubmit: true,
        defaultPromptID: nil
    )

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case hotkey
        case aiCaptureHotkey
        case insertionPosition
        case timestampMode
        case customDateFormat
        case dateLocaleIdentifier
        case useUTC
        case submitBehavior
        case stayOnTopPolicy
        case showMenuBarIcon
        case launchAtLogin
        case backupRetentionCount
        case obsidianIntegrationEnabled
        case obsidianDefaultFolderPath
        case obsidianDefaultSummarizeBeforeSave
        case obsidianTargetVaultName
        case aiAppPath
        case aiPromptTemplate
        case aiAutoSubmit
        case defaultPromptID
    }

    init(
        schemaVersion: Int,
        hotkey: HotkeyDefinition,
        aiCaptureHotkey: HotkeyDefinition,
        insertionPosition: InsertionPosition,
        timestampMode: TimestampMode,
        customDateFormat: String,
        dateLocaleIdentifier: String,
        useUTC: Bool,
        submitBehavior: SubmitBehavior,
        stayOnTopPolicy: StayOnTopPolicy,
        showMenuBarIcon: Bool,
        launchAtLogin: Bool,
        backupRetentionCount: Int,
        obsidianIntegrationEnabled: Bool,
        obsidianDefaultFolderPath: String,
        obsidianDefaultSummarizeBeforeSave: Bool,
        obsidianTargetVaultName: String,
        aiAppPath: String,
        aiPromptTemplate: String,
        aiAutoSubmit: Bool,
        defaultPromptID: UUID?
    ) {
        self.schemaVersion = schemaVersion
        self.hotkey = hotkey
        self.aiCaptureHotkey = aiCaptureHotkey
        self.insertionPosition = insertionPosition
        self.timestampMode = timestampMode
        self.customDateFormat = customDateFormat
        self.dateLocaleIdentifier = dateLocaleIdentifier
        self.useUTC = useUTC
        self.submitBehavior = submitBehavior
        self.stayOnTopPolicy = stayOnTopPolicy
        self.showMenuBarIcon = showMenuBarIcon
        self.launchAtLogin = launchAtLogin
        self.backupRetentionCount = backupRetentionCount
        self.obsidianIntegrationEnabled = obsidianIntegrationEnabled
        self.obsidianDefaultFolderPath = obsidianDefaultFolderPath
        self.obsidianDefaultSummarizeBeforeSave = obsidianDefaultSummarizeBeforeSave
        self.obsidianTargetVaultName = obsidianTargetVaultName
        self.aiAppPath = aiAppPath
        self.aiPromptTemplate = aiPromptTemplate
        self.aiAutoSubmit = aiAutoSubmit
        self.defaultPromptID = defaultPromptID
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        hotkey = try c.decodeIfPresent(HotkeyDefinition.self, forKey: .hotkey) ?? .default
        aiCaptureHotkey = try c.decodeIfPresent(HotkeyDefinition.self, forKey: .aiCaptureHotkey) ?? .clipDefault
        insertionPosition = try c.decodeIfPresent(InsertionPosition.self, forKey: .insertionPosition) ?? .bottom
        timestampMode = try c.decodeIfPresent(TimestampMode.self, forKey: .timestampMode) ?? .dateTime
        customDateFormat = try c.decodeIfPresent(String.self, forKey: .customDateFormat) ?? "yyyy-MM-dd HH:mm:ss"
        dateLocaleIdentifier = try c.decodeIfPresent(String.self, forKey: .dateLocaleIdentifier) ?? Locale.current.identifier
        useUTC = try c.decodeIfPresent(Bool.self, forKey: .useUTC) ?? false
        submitBehavior = try c.decodeIfPresent(SubmitBehavior.self, forKey: .submitBehavior) ?? .dismissWindow
        stayOnTopPolicy = try c.decodeIfPresent(StayOnTopPolicy.self, forKey: .stayOnTopPolicy) ?? .always
        showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        backupRetentionCount = try c.decodeIfPresent(Int.self, forKey: .backupRetentionCount) ?? 20
        obsidianIntegrationEnabled = try c.decodeIfPresent(Bool.self, forKey: .obsidianIntegrationEnabled) ?? true
        obsidianDefaultFolderPath = try c.decodeIfPresent(String.self, forKey: .obsidianDefaultFolderPath) ?? ""
        obsidianDefaultSummarizeBeforeSave = try c.decodeIfPresent(Bool.self, forKey: .obsidianDefaultSummarizeBeforeSave) ?? false
        obsidianTargetVaultName = try c.decodeIfPresent(String.self, forKey: .obsidianTargetVaultName) ?? ""
        aiAppPath = try c.decodeIfPresent(String.self, forKey: .aiAppPath) ?? ""
        aiPromptTemplate = try c.decodeIfPresent(String.self, forKey: .aiPromptTemplate) ?? AppSettings.default.aiPromptTemplate
        aiAutoSubmit = try c.decodeIfPresent(Bool.self, forKey: .aiAutoSubmit) ?? true
        defaultPromptID = try c.decodeIfPresent(UUID.self, forKey: .defaultPromptID)
    }
}
