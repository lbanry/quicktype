#if canImport(XCTest)
import XCTest
@testable import QuickType

@MainActor
final class AppModelAITests: XCTestCase {
    func testSendSelectionToConfiguredAICreatesPendingClipAndSubmitsPrompt() throws {
        let aiService = MockAIAutomationService()
        let model = makeModel(aiService: aiService)
        model.settings = configuredAISettings()

        model.sendSelectionToConfiguredAI()

        XCTAssertEqual(aiService.submissions.count, 1)
        XCTAssertEqual(aiService.submissions[0].appURL.path, "/Applications/TestAI.app")
        XCTAssertTrue(aiService.submissions[0].autoSubmit)
        XCTAssertEqual(aiService.submissions[0].prompt, "Summarize this clearly.\n\nSelected text")
        XCTAssertEqual(model.recentClipboardItems.count, 1)
        XCTAssertTrue(model.recentClipboardItems[0].awaitingAIResponse)
        XCTAssertEqual(model.recentClipboardItems[0].aiPrompt, "Summarize this clearly.\n\nSelected text")
    }

    func testCopiedResponseAppendsToPendingClip() throws {
        let aiService = MockAIAutomationService()
        let model = makeModel(aiService: aiService)
        model.settings = configuredAISettings()

        model.sendSelectionToConfiguredAI()
        model.handleCopiedText("Short summary")

        XCTAssertEqual(model.recentClipboardItems.count, 1)
        XCTAssertFalse(model.recentClipboardItems[0].awaitingAIResponse)
        XCTAssertEqual(
            model.recentClipboardItems[0].content,
            "Selected text\n\nAI Response\nShort summary"
        )
        XCTAssertEqual(model.recentClipboardItems[0].aiResponse, "Short summary")
    }

    func testSummarizeExistingClipboardItemReusesClip() throws {
        let aiService = MockAIAutomationService()
        let model = makeModel(aiService: aiService)
        model.settings = configuredAISettings()
        model.recentClipboardItems = [
            ClipboardItem(
                id: UUID(),
                title: "Clip",
                content: "Existing clip text",
                createdAt: Date(),
                updatedAt: Date(),
                isKept: false
            )
        ]

        let itemID = try XCTUnwrap(model.recentClipboardItems.first?.id)
        model.summarizeClipboardItemWithAI(itemID)

        XCTAssertEqual(aiService.submissions.count, 1)
        XCTAssertEqual(aiService.submissions[0].prompt, "Summarize this clearly.\n\nExisting clip text")
        XCTAssertTrue(model.recentClipboardItems[0].awaitingAIResponse)
        XCTAssertEqual(model.recentClipboardItems[0].aiPrompt, "Summarize this clearly.\n\nExisting clip text")
    }

    func testCopiedResponseAfterSummarizingExistingClipDoesNotCreateNewClip() throws {
        let aiService = MockAIAutomationService()
        let model = makeModel(aiService: aiService)
        model.settings = configuredAISettings()
        model.recentClipboardItems = [
            ClipboardItem(
                id: UUID(),
                title: "Clip",
                content: "Existing clip text",
                createdAt: Date(),
                updatedAt: Date(),
                isKept: false
            )
        ]

        let itemID = try XCTUnwrap(model.recentClipboardItems.first?.id)
        model.summarizeClipboardItemWithAI(itemID)
        model.handleCopiedText("Summarized output")

        XCTAssertEqual(model.recentClipboardItems.count, 1)
        XCTAssertEqual(model.recentClipboardItems[0].id, itemID)
        XCTAssertEqual(
            model.recentClipboardItems[0].content,
            "Existing clip text\n\nAI Response\nSummarized output"
        )
        XCTAssertEqual(model.recentClipboardItems[0].aiResponse, "Summarized output")
        XCTAssertFalse(model.recentClipboardItems[0].awaitingAIResponse)
    }

    func testMultiplePendingAIRequestsAppendResponsesInOrder() throws {
        let aiService = MockAIAutomationService()
        let model = makeModel(aiService: aiService)
        model.settings = configuredAISettings()

        model.sendSelectionToConfiguredAI()
        model.sendSelectionToConfiguredAI()

        XCTAssertEqual(model.recentClipboardItems.count, 2)
        let firstRequestID = model.recentClipboardItems[1].id
        let secondRequestID = model.recentClipboardItems[0].id

        model.handleCopiedText("First response")
        XCTAssertEqual(model.recentClipboardItems.first(where: { $0.id == firstRequestID })?.aiResponse, "First response")
        XCTAssertNil(model.recentClipboardItems.first(where: { $0.id == secondRequestID })?.aiResponse)

        model.handleCopiedText("Second response")
        XCTAssertEqual(model.recentClipboardItems.first(where: { $0.id == secondRequestID })?.aiResponse, "Second response")
    }

    private func makeModel(aiService: MockAIAutomationService) -> AppModel {
        AppModel(
            noteRepository: MockNoteRepository(),
            clipboardRepository: MockClipboardRepository(),
            quickActionRepository: MockQuickActionRepository(),
            promptRepository: MockPromptRepository(),
            linkRepository: MockLinkRepository(),
            settingsStore: MockSettingsStore(),
            bookmarkService: MockBookmarkService(),
            fileWriter: MockFileWriter(),
            recoveryService: MockRecoveryService(),
            hotkeyService: MockHotkeyService(),
            selectionCaptureService: MockSelectionCaptureService(),
            aiAutomationService: aiService,
            frontmostApplicationURLProvider: { URL(fileURLWithPath: "/Applications/TestAI.app") }
        )
    }

    private func configuredAISettings() -> AppSettings {
        var settings = AppSettings.default
        settings.submitBehavior = .keepWindowVisible
        settings.aiAppPath = "/Applications/TestAI.app"
        settings.aiPromptTemplate = "Summarize this clearly."
        settings.aiAutoSubmit = true
        return settings
    }
}

private struct MockNoteRepository: NoteRepositoryProtocol {
    func loadNoteTargets() throws -> [NoteTarget] { [] }
    func saveNoteTargets(_ targets: [NoteTarget]) throws {}
}

private struct MockClipboardRepository: ClipboardRepositoryProtocol {
    func loadKeptClipboardItems() throws -> [ClipboardItem] { [] }
    func saveKeptClipboardItems(_ items: [ClipboardItem]) throws {}
}

private struct MockQuickActionRepository: QuickActionRepositoryProtocol {
    func loadQuickActions() throws -> [QuickAction] { [] }
    func saveQuickActions(_ actions: [QuickAction]) throws {}
}

private struct MockPromptRepository: PromptRepositoryProtocol {
    func loadPrompts() throws -> [SavedPrompt] { [] }
    func savePrompts(_ prompts: [SavedPrompt]) throws {}
}

private struct MockLinkRepository: LinkRepositoryProtocol {
    func loadLinks() throws -> [SavedLink] { [] }
    func saveLinks(_ links: [SavedLink]) throws {}
}

private struct MockSettingsStore: SettingsStoreProtocol {
    func loadSettings() throws -> AppSettings { .default }
    func saveSettings(_ settings: AppSettings) throws {}
}

private struct MockBookmarkService: BookmarkServiceProtocol {
    func makeBookmark(for fileURL: URL) throws -> Data { Data() }
    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) {
        (URL(fileURLWithPath: "/tmp"), false)
    }
}

private struct MockFileWriter: FileWriterProtocol {
    func write(entry: CaptureEntry, to note: NoteTarget, insertion: InsertionPosition, settings: AppSettings) throws -> WriteResult {
        WriteResult(bytesWritten: 0, newFileSize: 0, backupCreated: false, warnings: [])
    }
}

private struct MockRecoveryService: RecoveryServiceProtocol {
    func scan(noteTargets: [NoteTarget]) -> [RecoveryIssue] { [] }
}

private final class MockHotkeyService: HotkeyServiceProtocol {
    var onHotkeyPressed: (() -> Void)?
    var onClipHotkeyPressed: (() -> Void)?
    func start(with hotkey: HotkeyDefinition, clipHotkey: HotkeyDefinition) {}
    func update(hotkey: HotkeyDefinition) {}
    func update(clipHotkey: HotkeyDefinition) {}
    func setQuickActionHotkeys(_ actions: [QuickAction], handler: @escaping (UUID) -> Void) {}
    func stop() {}
}

private struct MockSelectionCaptureService: SelectionCaptureServiceProtocol {
    func captureCurrentSelection(preferredProcessID: pid_t?) throws -> SelectionCapture {
        SelectionCapture(
            text: "Selected text",
            sourceAppName: "Test Source",
            sourceBundleID: "dev.quicktype.tests",
            sourceWindowTitle: nil,
            sourceURL: nil,
            capturedAt: Date(timeIntervalSince1970: 100)
        )
    }
}

private final class MockAIAutomationService: AIAutomationServiceProtocol {
    struct Submission {
        var prompt: String
        var appURL: URL
        var autoSubmit: Bool
    }

    private(set) var submissions: [Submission] = []

    func submit(prompt: String, appURL: URL, autoSubmit: Bool) throws {
        submissions.append(Submission(prompt: prompt, appURL: appURL, autoSubmit: autoSubmit))
    }
}
#endif
