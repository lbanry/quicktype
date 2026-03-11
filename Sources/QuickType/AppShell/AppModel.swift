import AppKit
import Carbon
import Combine
import Foundation
import SwiftUI

private enum PendingAIResponseTarget: Equatable {
    case clipboard(UUID)
    case link(UUID)
}

@MainActor
final class AppModel: ObservableObject {
    @Published var noteTargets: [NoteTarget] = []
    @Published var selectedNoteID: UUID?
    @Published var settings: AppSettings = .default
    @Published var captureText = ""
    @Published var captureDashboardTab: CaptureDashboardTab = .paste
    @Published var quickActions: [QuickAction] = []
    @Published var prompts: [SavedPrompt] = []
    @Published var isPromptPickerPresented = false
    @Published var savedLinks: [SavedLink] = []
    @Published var recentClipboardItems: [ClipboardItem] = []
    @Published var keptClipboardItems: [ClipboardItem] = []
    @Published var recoveryIssues: [RecoveryIssue] = []
    @Published var isHeaderKeyboardFocusActive = false
    @Published var lastStatusMessage = ""

    let noteRepository: NoteRepositoryProtocol
    let clipboardRepository: ClipboardRepositoryProtocol
    let quickActionRepository: QuickActionRepositoryProtocol
    let promptRepository: PromptRepositoryProtocol
    let linkRepository: LinkRepositoryProtocol
    let settingsStore: SettingsStoreProtocol
    let bookmarkService: BookmarkServiceProtocol
    let fileWriter: FileWriterProtocol
    let recoveryService: RecoveryServiceProtocol
    let hotkeyService: HotkeyServiceProtocol
    let selectionCaptureService: SelectionCaptureServiceProtocol
    let aiAutomationService: AIAutomationServiceProtocol
    let frontmostApplicationURLProvider: () -> URL?
    let obsidianClipExportService = ObsidianClipExportService()
    let formatter = EntryFormatter()
    private var workspaceObserver: NSObjectProtocol?
    private var lastExternalProcessID: pid_t?
    private var clipboardTimer: Timer?
    private var returnToAppAfterClipboardSelectionPID: pid_t?
    private var pendingAIResponseTargets: [PendingAIResponseTarget] = []
    private var pendingPromptSelection: SelectionCapture?
    private var lastPasteboardChangeCount = NSPasteboard.general.changeCount
    private var suppressedClipboardContent: String?
    private let maxRecentClipboardItems = 20

    init(
        noteRepository: NoteRepositoryProtocol,
        clipboardRepository: ClipboardRepositoryProtocol,
        quickActionRepository: QuickActionRepositoryProtocol,
        promptRepository: PromptRepositoryProtocol,
        linkRepository: LinkRepositoryProtocol,
        settingsStore: SettingsStoreProtocol,
        bookmarkService: BookmarkServiceProtocol,
        fileWriter: FileWriterProtocol,
        recoveryService: RecoveryServiceProtocol,
        hotkeyService: HotkeyServiceProtocol,
        selectionCaptureService: SelectionCaptureServiceProtocol,
        aiAutomationService: AIAutomationServiceProtocol,
        frontmostApplicationURLProvider: @escaping () -> URL?
    ) {
        self.noteRepository = noteRepository
        self.clipboardRepository = clipboardRepository
        self.quickActionRepository = quickActionRepository
        self.promptRepository = promptRepository
        self.linkRepository = linkRepository
        self.settingsStore = settingsStore
        self.bookmarkService = bookmarkService
        self.fileWriter = fileWriter
        self.recoveryService = recoveryService
        self.hotkeyService = hotkeyService
        self.selectionCaptureService = selectionCaptureService
        self.aiAutomationService = aiAutomationService
        self.frontmostApplicationURLProvider = frontmostApplicationURLProvider
    }

    var selectedNote: NoteTarget? {
        noteTargets.first(where: { $0.id == selectedNoteID })
    }

    func bootstrap(openCaptureWindow: @escaping () -> Void) {
        do {
            settings = try settingsStore.loadSettings()
            noteTargets = try noteRepository.loadNoteTargets()
            keptClipboardItems = try clipboardRepository.loadKeptClipboardItems()
            quickActions = try quickActionRepository.loadQuickActions()
            prompts = try promptRepository.loadPrompts()
            savedLinks = try linkRepository.loadLinks()
            selectedNoteID = noteTargets.first?.id
            captureDashboardTab = .paste
            ensureDefaultPromptExists()
            recoveryIssues = recoveryService.scan(noteTargets: noteTargets)
            hotkeyService.onHotkeyPressed = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.prepareClipboardLaunch()
                    openCaptureWindow()
                }
            }
            hotkeyService.onClipHotkeyPressed = { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.beginAISelectionFlow() else { return }
                    openCaptureWindow()
                }
            }
            hotkeyService.start(with: settings.hotkey, clipHotkey: .clipDefault)
            hotkeyService.setQuickActionHotkeys(quickActions) { [weak self] actionID in
                Task { @MainActor [weak self] in
                    self?.runQuickAction(actionID)
                }
            }
            startTrackingActiveApplications()
            startClipboardMonitoring()
        } catch {
            Logger.error("Failed bootstrap: \(error.localizedDescription)")
            lastStatusMessage = "Failed to load state: \(error.localizedDescription)"
        }
    }

    func persist() {
        do {
            try noteRepository.saveNoteTargets(noteTargets)
            try clipboardRepository.saveKeptClipboardItems(keptClipboardItems)
            try quickActionRepository.saveQuickActions(quickActions)
            try promptRepository.savePrompts(prompts)
            try linkRepository.saveLinks(savedLinks)
            try settingsStore.saveSettings(settings)
            syncQuickActionHotkeys()
        } catch {
            Logger.error("Persist failed: \(error.localizedDescription)")
            lastStatusMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    func saveCapture() {
        let trimmed = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastStatusMessage = "Capture is empty."
            return
        }
        saveTextToSelectedNote(trimmed)
        if lastStatusMessage.hasPrefix("Saved") {
            captureText = ""
        }
    }

    func createNoteTarget() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText, .init(filenameExtension: "md")!]
        panel.nameFieldStringValue = "Quick Notes.md"
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let format: NoteFormat = url.pathExtension.lowercased() == "md" ? .markdown : .plainText
        let bookmark = try? bookmarkService.makeBookmark(for: url)

        if !FileManager.default.fileExists(atPath: url.path) {
            try? Data().write(to: url, options: .atomic)
        }

        let target = NoteTarget(
            id: UUID(),
            displayName: url.lastPathComponent,
            filePath: url.path,
            bookmarkData: bookmark,
            format: format,
            externalAppPath: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        noteTargets.append(target)
        selectedNoteID = target.id
        persist()
    }

    func importNoteTarget() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .init(filenameExtension: "md")!]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK, let url = panel.url else { return }

        if noteTargets.contains(where: { $0.filePath == url.path }) {
            lastStatusMessage = "This file is already linked."
            return
        }

        let format: NoteFormat = url.pathExtension.lowercased() == "md" ? .markdown : .plainText
        let bookmark = try? bookmarkService.makeBookmark(for: url)
        let target = NoteTarget(
            id: UUID(),
            displayName: url.lastPathComponent,
            filePath: url.path,
            bookmarkData: bookmark,
            format: format,
            externalAppPath: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        noteTargets.append(target)
        selectedNoteID = target.id
        persist()
    }

    func removeSelectedNote() {
        guard let selectedNoteID else { return }
        noteTargets.removeAll(where: { $0.id == selectedNoteID })
        self.selectedNoteID = noteTargets.first?.id
        persist()
    }

    func revealSelectedNoteInFinder() {
        guard let selectedNote else { return }
        NSWorkspace.shared.activateFileViewerSelecting([selectedNote.fileURL])
    }

    func openSelectedInExternalApp() {
        guard let selectedNote else { return }
        if let external = selectedNote.externalAppURL {
            NSWorkspace.shared.open([selectedNote.fileURL], withApplicationAt: external, configuration: .init()) { _, _ in }
        } else {
            NSWorkspace.shared.open(selectedNote.fileURL)
        }
    }

    func selectExternalAppForSelectedNote() {
        guard let selectedID = selectedNoteID, let idx = noteTargets.firstIndex(where: { $0.id == selectedID }) else { return }

        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        noteTargets[idx].externalAppPath = url.path
        noteTargets[idx].updatedAt = Date()
        persist()
    }

    func selectAIApplication() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        updateSettings { $0.aiAppPath = url.path }
        lastStatusMessage = "AI app selected."
    }

    func clearAIApplication() {
        updateSettings { $0.aiAppPath = "" }
        lastStatusMessage = "AI app cleared."
    }

    func selectObsidianFolderPath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        if !settings.obsidianDefaultFolderPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: settings.obsidianDefaultFolderPath)
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }

        updateSettings { $0.obsidianDefaultFolderPath = url.path }
        lastStatusMessage = "Obsidian folder selected."
    }

    func refreshRecoveryIssues() {
        recoveryIssues = recoveryService.scan(noteTargets: noteTargets)
    }

    func relinkNote(_ noteID: UUID) {
        guard let idx = noteTargets.firstIndex(where: { $0.id == noteID }) else { return }
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.plainText, .init(filenameExtension: "md")!]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        noteTargets[idx].filePath = url.path
        noteTargets[idx].bookmarkData = try? bookmarkService.makeBookmark(for: url)
        noteTargets[idx].updatedAt = Date()
        persist()
        refreshRecoveryIssues()
    }

    func updateSettings(_ update: (inout AppSettings) -> Void) {
        var updated = settings
        update(&updated)
        settings = updated
        persist()
        hotkeyService.update(hotkey: settings.hotkey)
        hotkeyService.update(clipHotkey: .clipDefault)
        if settings.launchAtLogin {
            LaunchAtLoginService.setEnabled(true)
        } else {
            LaunchAtLoginService.setEnabled(false)
        }
    }

    func exportSettings() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "quicktype-settings.json"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try JSONEncoder().encode(settings)
            try data.write(to: url, options: .atomic)
            lastStatusMessage = "Settings exported."
        } catch {
            lastStatusMessage = "Export failed: \(error.localizedDescription)"
        }
    }

    func addPrompt(title: String, body: String) {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty else {
            lastStatusMessage = "Prompt body cannot be empty."
            return
        }

        let now = Date()
        let prompt = SavedPrompt(
            id: UUID(),
            title: resolvedPromptTitle(title, body: trimmedBody),
            body: trimmedBody,
            createdAt: now,
            updatedAt: now
        )
        prompts.insert(prompt, at: 0)
        if settings.defaultPromptID == nil {
            settings.defaultPromptID = prompt.id
        }
        persist()
        lastStatusMessage = "Prompt added."
    }

    func updatePrompt(_ promptID: UUID, title: String, body: String) {
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBody.isEmpty,
              let index = prompts.firstIndex(where: { $0.id == promptID }) else {
            lastStatusMessage = "Prompt body cannot be empty."
            return
        }

        prompts[index].title = resolvedPromptTitle(title, body: trimmedBody)
        prompts[index].body = trimmedBody
        prompts[index].updatedAt = Date()
        persist()
        lastStatusMessage = "Prompt updated."
    }

    func deletePrompt(_ promptID: UUID) {
        guard let index = prompts.firstIndex(where: { $0.id == promptID }) else { return }
        prompts.remove(at: index)
        if settings.defaultPromptID == promptID {
            settings.defaultPromptID = prompts.first?.id
        }
        persist()
        lastStatusMessage = "Prompt deleted."
    }

    func setDefaultPrompt(_ promptID: UUID) {
        guard prompts.contains(where: { $0.id == promptID }) else { return }
        updateSettings { $0.defaultPromptID = promptID }
        lastStatusMessage = "Default prompt updated."
    }

    func copyPrompt(_ promptID: UUID) {
        guard let prompt = prompts.first(where: { $0.id == promptID }) else { return }
        copyTextToPasteboard(prompt.body)
        lastStatusMessage = "Prompt copied."
    }

    func deleteAllAppMetadata() {
        do {
            if FileManager.default.fileExists(atPath: AppPaths.settingsFile.path) {
                try FileManager.default.removeItem(at: AppPaths.settingsFile)
            }
            if FileManager.default.fileExists(atPath: AppPaths.notesIndexFile.path) {
                try FileManager.default.removeItem(at: AppPaths.notesIndexFile)
            }
            noteTargets = []
            selectedNoteID = nil
            settings = .default
            persist()
            lastStatusMessage = "App metadata cleared."
        } catch {
            lastStatusMessage = "Failed to clear metadata: \(error.localizedDescription)"
        }
    }

    func copyDiagnostics() {
        let diagnostics = """
        QuickType Diagnostics
        Date: \(ISO8601DateFormatter().string(from: Date()))
        NoteTargets: \(noteTargets.count)
        QuickActions: \(quickActions.count)
        RecentClipboardItems: \(recentClipboardItems.count)
        KeptClipboardItems: \(keptClipboardItems.count)
        RecoveryIssues: \(recoveryIssues.count)
        Settings: \(settings)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)
        lastStatusMessage = "Diagnostics copied."
    }

    func addQuickAction(
        title: String,
        kind: QuickActionKind,
        text: String,
        clipboardItemID: UUID?,
        hotkey: HotkeyDefinition?
    ) {
        let now = Date()
        let action = QuickAction(
            id: UUID(),
            title: resolvedQuickActionTitle(title, kind: kind, text: text, clipboardItemID: clipboardItemID),
            kind: kind,
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            clipboardItemID: clipboardItemID,
            hotkey: hotkey,
            createdAt: now,
            updatedAt: now
        )
        quickActions.insert(action, at: 0)
        persist()
        lastStatusMessage = "Quick action added."
    }

    func updateQuickAction(
        _ actionID: UUID,
        title: String,
        kind: QuickActionKind,
        text: String,
        clipboardItemID: UUID?,
        hotkey: HotkeyDefinition?
    ) {
        guard let index = quickActions.firstIndex(where: { $0.id == actionID }) else { return }
        quickActions[index].title = resolvedQuickActionTitle(title, kind: kind, text: text, clipboardItemID: clipboardItemID)
        quickActions[index].kind = kind
        quickActions[index].text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        quickActions[index].clipboardItemID = clipboardItemID
        quickActions[index].hotkey = hotkey
        quickActions[index].updatedAt = Date()
        persist()
        lastStatusMessage = "Quick action updated."
    }

    func deleteQuickAction(_ actionID: UUID) {
        guard let index = quickActions.firstIndex(where: { $0.id == actionID }) else { return }
        quickActions.remove(at: index)
        persist()
        lastStatusMessage = "Quick action deleted."
    }

    func duplicateQuickAction(_ actionID: UUID) {
        guard let action = quickActions.first(where: { $0.id == actionID }) else { return }
        var copy = action
        let now = Date()
        copy.id = UUID()
        copy.title = "\(action.title) Copy"
        copy.hotkey = nil
        copy.createdAt = now
        copy.updatedAt = now
        quickActions.insert(copy, at: 0)
        persist()
        lastStatusMessage = "Quick action duplicated."
    }

    func createQuickActionFromClipboardItem(_ itemID: UUID) {
        if recentClipboardItems.contains(where: { $0.id == itemID }) {
            keepClipboardItem(itemID)
        }
        guard let item = clipboardItem(with: itemID) else { return }
        addQuickAction(
            title: item.title,
            kind: .pasteSavedClip,
            text: "",
            clipboardItemID: item.id,
            hotkey: nil
        )
    }

    func runQuickAction(_ actionID: UUID) {
        guard let action = quickActions.first(where: { $0.id == actionID }) else { return }

        do {
            let output = try quickActionOutput(for: action)
            switch action.kind {
            case .typeText, .pasteSavedClip:
                pasteTextToOriginatingApplication(output)
                lastStatusMessage = "Ran quick action."
            case .copyText, .promptSelection:
                copyTextToPasteboard(output)
                lastStatusMessage = "Quick action copied to clipboard."
            }
        } catch {
            Logger.error("Quick action failed: \(error.localizedDescription)")
            lastStatusMessage = error.localizedDescription
        }
    }

    func copyQuickAction(_ actionID: UUID) {
        guard let action = quickActions.first(where: { $0.id == actionID }) else { return }

        do {
            let output = try quickActionOutput(for: action)
            copyTextToPasteboard(output)
            lastStatusMessage = "Quick action copied to clipboard."
        } catch {
            Logger.error("Copy quick action failed: \(error.localizedDescription)")
            lastStatusMessage = error.localizedDescription
        }
    }

    func copyClipboardItem(_ itemID: UUID) {
        guard let item = clipboardItem(with: itemID) else { return }
        copyTextToPasteboard(item.content)
        lastStatusMessage = "Copied clipboard item."
    }

    func insertClipboardItem(_ itemID: UUID) {
        guard let item = clipboardItem(with: itemID) else { return }
        guard returnToAppAfterClipboardSelectionPID != nil else {
            copyTextToPasteboard(item.content)
            lastStatusMessage = "Copied clipboard item. Open QuickType with the global shortcut to insert it."
            return
        }
        pasteTextToOriginatingApplication(item.content)
        lastStatusMessage = "Inserted clipboard item."
    }

    func insertKeptClipboardItem(atShortcutIndex index: Int) {
        guard keptClipboardItems.indices.contains(index) else { return }
        insertClipboardItem(keptClipboardItems[index].id)
    }

    func summarizeClipboardItemWithAI(_ itemID: UUID) {
        guard !settings.aiAppPath.isEmpty else {
            lastStatusMessage = "Choose an AI app in Settings first."
            return
        }

        let promptTemplate = resolvedDefaultPromptBody().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptTemplate.isEmpty else {
            lastStatusMessage = "Add an AI prompt template in Settings first."
            return
        }

        guard let item = clipboardItem(with: itemID) else { return }
        let sourceText = item.aiResponse == nil ? item.content : originalClipboardContent(from: item.content)
        let prompt = composedAIPrompt(template: promptTemplate, selection: sourceText)

        do {
            markClipboardItemAwaitingAIResponse(itemID, prompt: prompt)
            try aiAutomationService.submit(
                prompt: prompt,
                appURL: URL(fileURLWithPath: settings.aiAppPath),
                autoSubmit: settings.aiAutoSubmit
            )
            lastStatusMessage = "Sent clip to AI app. Copy the response to append it to the clip."
            if settings.submitBehavior == .dismissWindow {
                NSApp.hide(nil)
            }
        } catch {
            clearAwaitingAIResponse(for: itemID)
            Logger.error("Summarize clipboard item failed: \(error.localizedDescription)")
            lastStatusMessage = error.localizedDescription
        }
    }

    func keepClipboardItem(_ itemID: UUID) {
        guard let index = recentClipboardItems.firstIndex(where: { $0.id == itemID }) else { return }
        var item = recentClipboardItems.remove(at: index)
        item.isKept = true
        item.updatedAt = Date()
        keptClipboardItems.insert(item, at: 0)
        persist()
        lastStatusMessage = "Kept clipboard item."
    }

    func unkeepClipboardItem(_ itemID: UUID) {
        guard let index = keptClipboardItems.firstIndex(where: { $0.id == itemID }) else { return }
        var item = keptClipboardItems.remove(at: index)
        item.isKept = false
        item.updatedAt = Date()
        recentClipboardItems.insert(item, at: 0)
        trimRecentClipboardItems()
        persist()
        lastStatusMessage = "Moved item back to recent clipboard."
    }

    func updateClipboardItem(_ itemID: UUID, title: String, content: String) {
        let resolvedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultClipboardTitle(for: content)
            : title.trimmingCharacters(in: .whitespacesAndNewlines)

        if let index = keptClipboardItems.firstIndex(where: { $0.id == itemID }) {
            keptClipboardItems[index].title = resolvedTitle
            keptClipboardItems[index].content = content
            keptClipboardItems[index].updatedAt = Date()
            persist()
            lastStatusMessage = "Updated kept clipboard item."
            return
        }

        if let index = recentClipboardItems.firstIndex(where: { $0.id == itemID }) {
            recentClipboardItems[index].title = resolvedTitle
            recentClipboardItems[index].content = content
            recentClipboardItems[index].updatedAt = Date()
            lastStatusMessage = "Updated recent clipboard item."
        }
    }

    func updateSavedLink(_ linkID: UUID, title: String, folderPath: String, notes: String?) {
        guard let index = savedLinks.firstIndex(where: { $0.id == linkID }) else { return }
        savedLinks[index].title = title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? savedLinks[index].title
            : title.trimmingCharacters(in: .whitespacesAndNewlines)
        savedLinks[index].folderPath = normalizedFolderPath(folderPath)
        savedLinks[index].notes = notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        savedLinks[index].updatedAt = Date()
        persist()
        lastStatusMessage = "Updated link."
    }

    func openSavedLink(_ linkID: UUID) {
        guard let link = savedLinks.first(where: { $0.id == linkID }),
              let url = URL(string: link.url) else { return }
        NSWorkspace.shared.open(url)
    }

    func copySavedLink(_ linkID: UUID) {
        guard let link = savedLinks.first(where: { $0.id == linkID }) else { return }
        copyTextToPasteboard(link.url)
        lastStatusMessage = "Link copied."
    }

    func deleteSavedLink(_ linkID: UUID) {
        savedLinks.removeAll { $0.id == linkID }
        pendingAIResponseTargets.removeAll { target in
            if case .link(linkID) = target { return true }
            return false
        }
        persist()
        lastStatusMessage = "Deleted link."
    }

    func summarizeSavedLinkWithAI(_ linkID: UUID) {
        guard !settings.aiAppPath.isEmpty else {
            lastStatusMessage = "Choose an AI app in Settings first."
            return
        }
        guard let index = savedLinks.firstIndex(where: { $0.id == linkID }) else { return }
        let prompt = composedAIPrompt(template: resolvedDefaultPromptBody(), selection: linkPromptContent(savedLinks[index]))
        let now = Date()
        savedLinks[index].aiPrompt = prompt
        savedLinks[index].aiRequestDate = now
        savedLinks[index].aiResponseDate = nil
        savedLinks[index].awaitingAIResponse = true
        enqueuePendingAIResponseTarget(.link(linkID))
        copyTextToPasteboard(prompt)

        do {
            try aiAutomationService.submit(
                prompt: prompt,
                appURL: URL(fileURLWithPath: settings.aiAppPath),
                autoSubmit: settings.aiAutoSubmit
            )
            persist()
            lastStatusMessage = "Sent link to AI app. Copy the response to append it to the saved link."
            if settings.submitBehavior == .dismissWindow {
                NSApp.hide(nil)
            }
        } catch {
            savedLinks[index].awaitingAIResponse = false
            pendingAIResponseTargets.removeAll { $0 == .link(linkID) }
            Logger.error("Summarize saved link failed: \(error.localizedDescription)")
            lastStatusMessage = error.localizedDescription
        }
    }

    func deleteClipboardItem(_ itemID: UUID) {
        pendingAIResponseTargets.removeAll { $0 == .clipboard(itemID) }
        if let index = keptClipboardItems.firstIndex(where: { $0.id == itemID }) {
            keptClipboardItems.remove(at: index)
            quickActions.removeAll { $0.clipboardItemID == itemID }
            persist()
            lastStatusMessage = "Deleted kept clipboard item."
            return
        }

        if let index = recentClipboardItems.firstIndex(where: { $0.id == itemID }) {
            recentClipboardItems.remove(at: index)
            if quickActions.contains(where: { $0.clipboardItemID == itemID }) {
                quickActions.removeAll { $0.clipboardItemID == itemID }
                persist()
            }
            lastStatusMessage = "Deleted recent clipboard item."
        }
    }

    func clearRecentClipboardItems() {
        guard !recentClipboardItems.isEmpty else { return }
        let recentIDs = Set(recentClipboardItems.map(\.id))
        recentClipboardItems.removeAll()
        pendingAIResponseTargets.removeAll { target in
            if case .clipboard(let itemID) = target {
                return recentIDs.contains(itemID)
            }
            return false
        }
        quickActions.removeAll { action in
            guard let clipboardItemID = action.clipboardItemID else { return false }
            return recentIDs.contains(clipboardItemID)
        }
        persist()
        lastStatusMessage = "Cleared recent clipboard items."
    }

    func saveClipboardItemToQuickNote(_ itemID: UUID) {
        guard let item = clipboardItem(with: itemID) else { return }
        let trimmed = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastStatusMessage = "Clipboard item is empty."
            return
        }
        saveTextToSelectedNote(trimmed)
    }

    func handleIncomingURL(_ url: URL) {
        guard url.scheme?.lowercased() == "quicktype" else { return }
        guard url.host?.lowercased() == "capture" else { return }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let targetID = components?.queryItems?.first(where: { $0.name == "target" })?.value
        let text = components?.queryItems?.first(where: { $0.name == "text" })?.value

        if let targetID, let uuid = UUID(uuidString: targetID), noteTargets.contains(where: { $0.id == uuid }) {
            selectedNoteID = uuid
        }

        if let text, !text.isEmpty {
            captureText = text.removingPercentEncoding ?? text
        }
    }

    func restoreLatestBackupForSelectedNote() {
        guard let selected = selectedNote else { return }
        let backupDir = AppPaths.backupsDirectory.appendingPathComponent(selected.id.uuidString, isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: backupDir,
            includingPropertiesForKeys: [.creationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            lastStatusMessage = "No backups found."
            return
        }

        let sorted = files.sorted { lhs, rhs in
            let la = (try? lhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            let ra = (try? rhs.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            return la > ra
        }

        guard let latest = sorted.first else {
            lastStatusMessage = "No backups found."
            return
        }

        do {
            let data = try Data(contentsOf: latest)
            try data.write(to: selected.fileURL, options: .atomic)
            lastStatusMessage = "Restored latest backup."
            refreshRecoveryIssues()
        } catch {
            lastStatusMessage = "Backup restore failed: \(error.localizedDescription)"
        }
    }

    func copyHighlightedTextToNewNote() {
        do {
            let selection = try selectionCaptureService.captureCurrentSelection(preferredProcessID: lastExternalProcessID)
            let fileURL = try createLocalClipNote(from: selection)
            let bookmark = try? bookmarkService.makeBookmark(for: fileURL)
            let now = selection.capturedAt
            let target = NoteTarget(
                id: UUID(),
                displayName: fileURL.lastPathComponent,
                filePath: fileURL.path,
                bookmarkData: bookmark,
                format: .markdown,
                externalAppPath: nil,
                createdAt: now,
                updatedAt: now
            )

            noteTargets.insert(target, at: 0)
            selectedNoteID = target.id
            persist()
            lastStatusMessage = "Created clip note from highlighted text."
        } catch {
            Logger.error("Copy highlighted text failed: \(error.localizedDescription)")
            lastStatusMessage = error.localizedDescription
        }
    }

    @discardableResult
    func beginAISelectionFlow() -> Bool {
        guard !settings.aiAppPath.isEmpty else {
            lastStatusMessage = "Choose an AI app in Settings first."
            return false
        }

        do {
            pendingPromptSelection = try selectionCaptureService.captureCurrentSelection(preferredProcessID: lastExternalProcessID)
            isPromptPickerPresented = true
            captureDashboardTab = .paste
            return true
        } catch {
            Logger.error("Begin AI prompt selection failed: \(error.localizedDescription)")
            lastStatusMessage = error.localizedDescription
            return false
        }
    }

    func submitPendingSelectionWithDefaultPrompt() {
        submitPendingSelection(using: defaultPrompt)
    }

    func submitPendingSelection(with promptID: UUID) {
        submitPendingSelection(using: prompts.first(where: { $0.id == promptID }))
    }

    func dismissPromptPicker() {
        isPromptPickerPresented = false
        pendingPromptSelection = nil
    }

    func sendSelectionToConfiguredAI() {
        var pendingItemID: UUID?
        do {
            guard !settings.aiAppPath.isEmpty else {
                lastStatusMessage = "Choose an AI app in Settings first."
                return
            }

            let selection = try selectionCaptureService.captureCurrentSelection(preferredProcessID: lastExternalProcessID)
            let prompt = composedAIPrompt(template: resolvedDefaultPromptBody(), selection: selection.text)
            let item = createPendingAIClipboardItem(from: selection, prompt: prompt)
            pendingItemID = item.id

            try aiAutomationService.submit(
                prompt: prompt,
                appURL: URL(fileURLWithPath: settings.aiAppPath),
                autoSubmit: settings.aiAutoSubmit
            )

            lastStatusMessage = "Sent selection to AI app. Copy the response to append it to the clip."
            if settings.submitBehavior == .dismissWindow {
                NSApp.hide(nil)
            }
        } catch {
            if let pendingItemID,
               let pendingIndex = recentClipboardItems.firstIndex(where: { $0.id == pendingItemID }) {
                recentClipboardItems.remove(at: pendingIndex)
            }
            Logger.error("Send selection to AI failed: \(error.localizedDescription)")
            lastStatusMessage = error.localizedDescription
        }
    }

    func saveHighlightedTextToObsidian(summarizeFirst: Bool, folderOverride: String? = nil) {
        guard settings.obsidianIntegrationEnabled else {
            lastStatusMessage = "Obsidian integration is disabled in Settings."
            return
        }

        do {
            let selection = try selectionCaptureService.captureCurrentSelection(preferredProcessID: lastExternalProcessID)
            guard let destination = requestObsidianDestination(for: selection, folderOverride: folderOverride) else {
                return
            }
            let attachments = currentPasteboardAttachments()
            let payload = ObsidianClipPayloadV1(
                version: 1,
                clipId: UUID().uuidString,
                capturedAt: ISO8601DateFormatter().string(from: selection.capturedAt),
                sourceAppName: selection.sourceAppName,
                sourceBundleId: selection.sourceBundleID,
                sourceWindowTitle: selection.sourceWindowTitle,
                sourceUrl: selection.sourceURL,
                contentText: selection.text,
                attachments: attachments,
                requestedAction: resolveObsidianAction(summarizeFirst: summarizeFirst),
                targetHint: ObsidianTargetHint(
                    vaultName: settings.obsidianTargetVaultName.isEmpty ? nil : settings.obsidianTargetVaultName,
                    folderPath: destination.folderPath,
                    noteTitle: destination.noteTitle
                )
            )

            let url = try obsidianClipExportService.buildObsidianURL(payload: payload)
            let opened = NSWorkspace.shared.open(url)
            if opened {
                lastStatusMessage = "Sent clip to Obsidian."
            } else {
                lastStatusMessage = "Unable to open Obsidian URI. Confirm Obsidian is installed."
            }
        } catch {
            Logger.error("Save highlighted text to Obsidian failed: \(error.localizedDescription)")
            lastStatusMessage = error.localizedDescription
        }
    }

    func chooseObsidianFolderAndSaveHighlightedText(summarizeFirst: Bool) {
        saveHighlightedTextToObsidian(summarizeFirst: summarizeFirst, folderOverride: settings.obsidianDefaultFolderPath)
    }

    private func createLocalClipNote(from selection: SelectionCapture) throws -> URL {
        let content = clipContent(from: selection)
        let nameFormatter = DateFormatter()
        nameFormatter.dateFormat = "yyyyMMdd-HHmmss"
        let filename = "Clip-\(nameFormatter.string(from: selection.capturedAt)).md"
        let fileURL = AppPaths.clipsDirectory.appendingPathComponent(filename)

        guard let data = content.data(using: .utf8) else {
            throw NSError(domain: "QuickType", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Unable to encode clip content as UTF-8."])
        }
        try data.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private func clipContent(from selection: SelectionCapture) -> String {
        let timestamp = ISO8601DateFormatter().string(from: selection.capturedAt)
        var lines: [String] = [
            "# Captured Clip",
            "",
            "- Captured: \(timestamp)",
            "- Source App: \(selection.sourceAppName) (\(selection.sourceBundleID))"
        ]
        if let title = selection.sourceWindowTitle, !title.isEmpty {
            lines.append("- Source Window: \(title)")
        }
        if let url = selection.sourceURL, !url.isEmpty {
            lines.append("- Source URL: \(url)")
        }
        lines.append("")
        lines.append("```")
        lines.append(selection.text)
        lines.append("```")
        lines.append("")
        return lines.joined(separator: "\n")
    }

    private func startTrackingActiveApplications() {
        let nc = NSWorkspace.shared.notificationCenter
        workspaceObserver = nc.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
                return
            }
            Task { @MainActor [weak self] in
                self?.updateLastExternalApplication(app)
            }
        }

        if let frontmost = NSWorkspace.shared.frontmostApplication {
            updateLastExternalApplication(frontmost)
        }
    }

    private func updateLastExternalApplication(_ app: NSRunningApplication) {
        guard app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return
        }
        lastExternalProcessID = app.processIdentifier
    }

    private func prepareClipboardLaunch() {
        captureDashboardTab = .paste
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            returnToAppAfterClipboardSelectionPID = frontmost.processIdentifier
            lastExternalProcessID = frontmost.processIdentifier
        }
    }

    private func startClipboardMonitoring() {
        clipboardTimer?.invalidate()
        lastPasteboardChangeCount = NSPasteboard.general.changeCount
        clipboardTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollClipboard()
            }
        }
    }

    private func pollClipboard() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastPasteboardChangeCount else { return }
        lastPasteboardChangeCount = pasteboard.changeCount

        guard let text = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !text.isEmpty else {
            return
        }

        handleCopiedText(text)
    }

    func handleCopiedText(_ text: String) {
        if suppressedClipboardContent == text {
            suppressedClipboardContent = nil
            return
        }

        if appendCopiedAIResponseIfNeeded(text) {
            return
        }

        let extractedLinks = extractCopiedLinks(from: text)
        if handleCopiedLinksIfNeeded(extractedLinks.urls) {
            if extractedLinks.remainingText.isEmpty {
                return
            }
        }

        let sanitizedText = extractedLinks.remainingText.isEmpty ? text : extractedLinks.remainingText
        if recentClipboardItems.first?.content == sanitizedText || keptClipboardItems.contains(where: { $0.content == sanitizedText }) {
            return
        }

        let item = ClipboardItem(
            id: UUID(),
            title: defaultClipboardTitle(for: sanitizedText),
            content: sanitizedText,
            createdAt: Date(),
            updatedAt: Date(),
            isKept: false
        )
        recentClipboardItems.insert(item, at: 0)
        trimRecentClipboardItems()
    }

    private func appendCopiedAIResponseIfNeeded(_ response: String) -> Bool {
        guard isConfiguredAIAppFrontmost(),
              let pendingTarget = pendingAIResponseTargets.first else {
            return false
        }

        switch pendingTarget {
        case .clipboard(let itemID):
            if let index = recentClipboardItems.firstIndex(where: { $0.id == itemID }) {
                applyAIResponse(response, toRecentItemAt: index)
                return true
            }

            if let index = keptClipboardItems.firstIndex(where: { $0.id == itemID }) {
                applyAIResponse(response, toKeptItemAt: index)
                return true
            }
        case .link(let linkID):
            if let index = savedLinks.firstIndex(where: { $0.id == linkID }) {
                applyAIResponse(response, toSavedLinkAt: index)
                return true
            }
        }

        pendingAIResponseTargets.removeAll { $0 == pendingTarget }
        return false
    }

    private func saveTextToSelectedNote(_ text: String) {
        guard let note = selectedNote else {
            lastStatusMessage = "Select or create a note target first."
            return
        }

        let entry = formatter.format(rawText: text, settings: settings)
        do {
            let result = try fileWriter.write(entry: entry, to: note, insertion: settings.insertionPosition, settings: settings)
            if let idx = noteTargets.firstIndex(where: { $0.id == note.id }) {
                noteTargets[idx].updatedAt = Date()
            }
            persist()
            recoveryIssues = recoveryService.scan(noteTargets: noteTargets)
            lastStatusMessage = "Saved (\(result.bytesWritten) bytes)."
        } catch {
            Logger.error("Save to selected note failed: \(error.localizedDescription)")
            lastStatusMessage = "Save failed: \(error.localizedDescription)"
        }
    }

    private func handleCopiedLinksIfNeeded(_ urls: [URL]) -> Bool {
        guard !urls.isEmpty else {
            return false
        }

        var addedCount = 0
        var matchedBrowserMetadata = currentBrowserMetadata()

        for url in urls {
            if let index = savedLinks.firstIndex(where: { $0.url == url.absoluteString }) {
                savedLinks[index].updatedAt = Date()
                continue
            }

            let now = Date()
            let title: String
            if matchedBrowserMetadata.url == url.absoluteString, let browserTitle = matchedBrowserMetadata.title {
                title = browserTitle
            } else {
                title = defaultLinkTitle(for: url)
                fetchPageTitle(for: url)
            }

            let link = SavedLink(
                id: UUID(),
                title: title,
                url: url.absoluteString,
                folderPath: "",
                summary: nil,
                notes: nil,
                createdAt: now,
                updatedAt: now,
                aiPrompt: nil,
                aiRequestDate: nil,
                aiResponseDate: nil,
                awaitingAIResponse: false
            )
            savedLinks.insert(link, at: 0)
            addedCount += 1

            if matchedBrowserMetadata.url == url.absoluteString {
                matchedBrowserMetadata = (nil, nil)
            }
        }

        guard addedCount > 0 else {
            lastStatusMessage = urls.count == 1 ? "Link already saved." : "Links already saved."
            persist()
            return true
        }

        captureDashboardTab = .links
        persist()
        lastStatusMessage = addedCount == 1 ? "Saved link." : "Saved \(addedCount) links."
        return true
    }

    private func trimRecentClipboardItems() {
        if recentClipboardItems.count > maxRecentClipboardItems {
            recentClipboardItems = Array(recentClipboardItems.prefix(maxRecentClipboardItems))
        }
    }

    private func defaultClipboardTitle(for content: String) -> String {
        let singleLine = content.replacingOccurrences(of: "\n", with: " ")
        let trimmed = singleLine.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = String(trimmed.prefix(40))
        return title.isEmpty ? "Untitled Clip" : title
    }

    private func clipboardItem(with itemID: UUID) -> ClipboardItem? {
        keptClipboardItems.first(where: { $0.id == itemID }) ??
        recentClipboardItems.first(where: { $0.id == itemID })
    }

    private func extractCopiedLinks(from text: String) -> (urls: [URL], remainingText: String) {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        var normalizedMatches: [(URL, Range<String.Index>)] = []

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let matches = detector.matches(in: text, options: [], range: nsRange)
            normalizedMatches.append(contentsOf: matches.compactMap { match -> (URL, Range<String.Index>)? in
                guard let url = match.url,
                      let normalizedURL = normalizedHTTPURL(from: url.absoluteString),
                      let range = Range(match.range, in: text) else {
                    return nil
                }
                return (normalizedURL, range)
            })
        }

        if let domainRegex = try? NSRegularExpression(
            pattern: #"(?i)\b(?:[a-z0-9-]+\.)+[a-z]{2,}(?:/[^\s<>()\[\]{}]*)?"#,
            options: []
        ) {
            let domainMatches = domainRegex.matches(in: text, options: [], range: nsRange)
            for match in domainMatches {
                guard let range = Range(match.range, in: text) else {
                    continue
                }

                if normalizedMatches.contains(where: { $0.1.overlaps(range) }) {
                    continue
                }

                let candidate = String(text[range])
                guard let normalizedURL = normalizedHTTPURL(from: candidate.hasPrefix("http") ? candidate : "https://\(candidate)") else {
                    continue
                }

                normalizedMatches.append((normalizedURL, range))
            }
        }

        guard !normalizedMatches.isEmpty else {
            return ([], text.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        var remainingText = text
        for (_, range) in normalizedMatches.reversed() {
            remainingText.removeSubrange(range)
        }

        remainingText = remainingText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\n\n\n", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var seen = Set<String>()
        let urls = normalizedMatches.compactMap { match -> URL? in
            let url = match.0
            let absoluteString = url.absoluteString
            guard seen.insert(absoluteString).inserted else {
                return nil
            }
            return url
        }

        return (urls, remainingText)
    }

    private func normalizedHTTPURL(from value: String) -> URL? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return nil
        }
        return url
    }

    private func defaultLinkTitle(for url: URL) -> String {
        if let host = url.host, !host.isEmpty {
            let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return path.isEmpty ? host : "\(host)/\(path)"
        }
        return url.absoluteString
    }

    private func normalizedFolderPath(_ value: String) -> String {
        value
            .split(separator: "/")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "/")
    }

    private func linkPromptContent(_ link: SavedLink) -> String {
        """
        Title: \(link.title)
        URL: \(link.url)
        """
    }

    private func currentBrowserMetadata() -> (title: String?, url: String?) {
        guard let frontmost = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontmost.bundleIdentifier else {
            return (nil, nil)
        }

        switch bundleID {
        case "com.apple.Safari":
            let url = runAppleScript("tell application \"Safari\" to return URL of front document")
            let title = runAppleScript("tell application \"Safari\" to return name of front document")
            return (title, url)
        case "com.google.Chrome":
            let url = runAppleScript("tell application \"Google Chrome\" to return URL of active tab of front window")
            let title = runAppleScript("tell application \"Google Chrome\" to return title of active tab of front window")
            return (title, url)
        case "company.thebrowser.Browser":
            let url = runAppleScript("tell application \"Arc\" to return URL of active tab of front window")
            let title = runAppleScript("tell application \"Arc\" to return title of active tab of front window")
            return (title, url)
        case "com.brave.Browser":
            let url = runAppleScript("tell application \"Brave Browser\" to return URL of active tab of front window")
            let title = runAppleScript("tell application \"Brave Browser\" to return title of active tab of front window")
            return (title, url)
        case "com.microsoft.edgemac":
            let url = runAppleScript("tell application \"Microsoft Edge\" to return URL of active tab of front window")
            let title = runAppleScript("tell application \"Microsoft Edge\" to return title of active tab of front window")
            return (title, url)
        default:
            return (nil, nil)
        }
    }

    private func fetchPageTitle(for url: URL) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        request.setValue("QuickType", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self, error == nil, let data,
                  let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1),
                  let title = Self.parsedHTMLTitle(from: html) else {
                return
            }

            Task { @MainActor [weak self] in
                self?.applyFetchedPageTitle(title, for: url.absoluteString)
            }
        }.resume()
    }

    nonisolated private static func parsedHTMLTitle(from html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: "<title[^>]*>(.*?)</title>", options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }

        let range = NSRange(html.startIndex..<html.endIndex, in: html)
        guard let match = regex.firstMatch(in: html, options: [], range: range),
              let titleRange = Range(match.range(at: 1), in: html) else {
            return nil
        }

        let title = html[titleRange]
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    private func applyFetchedPageTitle(_ title: String, for urlString: String) {
        guard let index = savedLinks.firstIndex(where: { $0.url == urlString }) else {
            return
        }

        let existingTitle = savedLinks[index].title
        if existingTitle != defaultLinkTitle(for: URL(string: urlString) ?? URL(fileURLWithPath: "/")) {
            return
        }

        savedLinks[index].title = title
        savedLinks[index].updatedAt = Date()
        persist()
    }

    private func runAppleScript(_ source: String) -> String? {
        guard let script = NSAppleScript(source: source) else {
            return nil
        }
        var errorInfo: NSDictionary?
        let output = script.executeAndReturnError(&errorInfo)
        if errorInfo != nil {
            return nil
        }
        let value = output.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == true ? nil : value
    }

    private var defaultPrompt: SavedPrompt? {
        if let defaultPromptID = settings.defaultPromptID,
           let prompt = prompts.first(where: { $0.id == defaultPromptID }) {
            return prompt
        }
        return prompts.first
    }

    private func resolvedDefaultPromptBody() -> String {
        if let defaultPrompt {
            return defaultPrompt.body
        }

        let legacyPrompt = settings.aiPromptTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        return legacyPrompt.isEmpty ? AppSettings.default.aiPromptTemplate : legacyPrompt
    }

    private func resolvedPromptTitle(_ title: String, body: String) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }
        return String(body.prefix(40))
    }

    private func ensureDefaultPromptExists() {
        if prompts.isEmpty {
            let now = Date()
            let prompt = SavedPrompt(
                id: UUID(),
                title: "Default Summary",
                body: resolvedDefaultPromptBody(),
                createdAt: now,
                updatedAt: now
            )
            prompts = [prompt]
            settings.defaultPromptID = prompt.id
            persist()
            return
        }

        if let defaultPromptID = settings.defaultPromptID,
           prompts.contains(where: { $0.id == defaultPromptID }) {
            return
        }

        settings.defaultPromptID = prompts.first?.id
        persist()
    }

    private func submitPendingSelection(using prompt: SavedPrompt?) {
        guard !settings.aiAppPath.isEmpty else {
            lastStatusMessage = "Choose an AI app in Settings first."
            return
        }

        guard let selection = pendingPromptSelection else {
            lastStatusMessage = "No captured selection is waiting for a prompt."
            isPromptPickerPresented = false
            return
        }

        let promptBody = prompt?.body ?? resolvedDefaultPromptBody()
        let trimmedPrompt = promptBody.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPrompt.isEmpty else {
            lastStatusMessage = "Add a prompt in Settings first."
            return
        }

        var pendingItemID: UUID?
        do {
            let promptText = composedAIPrompt(template: trimmedPrompt, selection: selection.text)
            let item = createPendingAIClipboardItem(from: selection, prompt: promptText)
            pendingItemID = item.id

            try aiAutomationService.submit(
                prompt: promptText,
                appURL: URL(fileURLWithPath: settings.aiAppPath),
                autoSubmit: settings.aiAutoSubmit
            )

            isPromptPickerPresented = false
            pendingPromptSelection = nil
            lastStatusMessage = "Sent selection to AI app. Copy the response to append it to the clip."
            if settings.submitBehavior == .dismissWindow {
                NSApp.hide(nil)
            }
        } catch {
            if let pendingItemID,
               let pendingIndex = recentClipboardItems.firstIndex(where: { $0.id == pendingItemID }) {
                recentClipboardItems.remove(at: pendingIndex)
            }
            Logger.error("Submit pending selection failed: \(error.localizedDescription)")
            lastStatusMessage = error.localizedDescription
        }
    }

    private func composedAIPrompt(template: String, selection: String) -> String {
        "\(template)\n\n\(selection.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    @discardableResult
    private func createPendingAIClipboardItem(from selection: SelectionCapture, prompt: String) -> ClipboardItem {
        let now = Date()
        let item = ClipboardItem(
            id: UUID(),
            title: defaultClipboardTitle(for: selection.text),
            content: selection.text,
            createdAt: now,
            updatedAt: now,
            isKept: false,
            aiPrompt: prompt,
            aiResponse: nil,
            aiRequestDate: now,
            aiResponseDate: nil,
            awaitingAIResponse: true
        )
        recentClipboardItems.insert(item, at: 0)
        enqueuePendingAIResponseTarget(.clipboard(item.id))
        trimRecentClipboardItems()
        copyTextToPasteboard(prompt)
        return item
    }

    private func clearPendingAIResponseState() {
        pendingAIResponseTargets.removeAll()
        for index in recentClipboardItems.indices where recentClipboardItems[index].awaitingAIResponse {
            recentClipboardItems[index].awaitingAIResponse = false
            recentClipboardItems[index].updatedAt = Date()
        }

        for index in keptClipboardItems.indices where keptClipboardItems[index].awaitingAIResponse {
            keptClipboardItems[index].awaitingAIResponse = false
            keptClipboardItems[index].updatedAt = Date()
        }

        for index in savedLinks.indices where savedLinks[index].awaitingAIResponse {
            savedLinks[index].awaitingAIResponse = false
            savedLinks[index].updatedAt = Date()
        }
    }

    private func clearAwaitingAIResponse(for itemID: UUID) {
        pendingAIResponseTargets.removeAll {
            switch $0 {
            case .clipboard(let queuedID), .link(let queuedID):
                return queuedID == itemID
            }
        }
        if let index = recentClipboardItems.firstIndex(where: { $0.id == itemID }) {
            recentClipboardItems[index].awaitingAIResponse = false
            recentClipboardItems[index].updatedAt = Date()
            return
        }

        if let index = keptClipboardItems.firstIndex(where: { $0.id == itemID }) {
            keptClipboardItems[index].awaitingAIResponse = false
            keptClipboardItems[index].updatedAt = Date()
            persist()
            return
        }

        if let index = savedLinks.firstIndex(where: { $0.id == itemID }) {
            savedLinks[index].awaitingAIResponse = false
            savedLinks[index].updatedAt = Date()
            persist()
        }
    }

    private func markClipboardItemAwaitingAIResponse(_ itemID: UUID, prompt: String) {
        let now = Date()

        if let index = recentClipboardItems.firstIndex(where: { $0.id == itemID }) {
            recentClipboardItems[index].aiPrompt = prompt
            recentClipboardItems[index].aiRequestDate = now
            recentClipboardItems[index].aiResponse = nil
            recentClipboardItems[index].aiResponseDate = nil
            recentClipboardItems[index].awaitingAIResponse = true
            recentClipboardItems[index].updatedAt = now
            enqueuePendingAIResponseTarget(.clipboard(itemID))
            copyTextToPasteboard(prompt)
            return
        }

        if let index = keptClipboardItems.firstIndex(where: { $0.id == itemID }) {
            keptClipboardItems[index].aiPrompt = prompt
            keptClipboardItems[index].aiRequestDate = now
            keptClipboardItems[index].aiResponse = nil
            keptClipboardItems[index].aiResponseDate = nil
            keptClipboardItems[index].awaitingAIResponse = true
            keptClipboardItems[index].updatedAt = now
            enqueuePendingAIResponseTarget(.clipboard(itemID))
            copyTextToPasteboard(prompt)
            persist()
        }
    }

    private func applyAIResponse(_ response: String, toRecentItemAt index: Int) {
        let now = Date()
        recentClipboardItems[index].content = mergedClipboardContent(
            original: recentClipboardItems[index].content,
            response: response
        )
        recentClipboardItems[index].aiResponse = response
        recentClipboardItems[index].aiResponseDate = now
        recentClipboardItems[index].awaitingAIResponse = false
        recentClipboardItems[index].updatedAt = now
        pendingAIResponseTargets.removeAll { $0 == .clipboard(recentClipboardItems[index].id) }
        lastStatusMessage = "Appended AI response to clip."
    }

    private func applyAIResponse(_ response: String, toKeptItemAt index: Int) {
        let now = Date()
        keptClipboardItems[index].content = mergedClipboardContent(
            original: keptClipboardItems[index].content,
            response: response
        )
        keptClipboardItems[index].aiResponse = response
        keptClipboardItems[index].aiResponseDate = now
        keptClipboardItems[index].awaitingAIResponse = false
        keptClipboardItems[index].updatedAt = now
        pendingAIResponseTargets.removeAll { $0 == .clipboard(keptClipboardItems[index].id) }
        persist()
        lastStatusMessage = "Appended AI response to kept clip."
    }

    private func applyAIResponse(_ response: String, toSavedLinkAt index: Int) {
        let now = Date()
        savedLinks[index].summary = response
        savedLinks[index].aiResponseDate = now
        savedLinks[index].awaitingAIResponse = false
        savedLinks[index].updatedAt = now
        pendingAIResponseTargets.removeAll { $0 == .link(savedLinks[index].id) }
        persist()
        lastStatusMessage = "Added AI summary to link."
    }

    private func mergedClipboardContent(original: String, response: String) -> String {
        """
        \(original)

        AI Response
        \(response)
        """
    }

    private func originalClipboardContent(from content: String) -> String {
        let marker = "\n\nAI Response\n"
        if let range = content.range(of: marker) {
            return String(content[..<range.lowerBound])
        }
        return content
    }

    private func enqueuePendingAIResponseTarget(_ target: PendingAIResponseTarget) {
        pendingAIResponseTargets.removeAll { $0 == target }
        pendingAIResponseTargets.append(target)
    }

    private func isConfiguredAIAppFrontmost() -> Bool {
        guard !settings.aiAppPath.isEmpty,
              let frontmostURL = frontmostApplicationURLProvider()?.standardizedFileURL else {
            return false
        }

        let configuredURL = URL(fileURLWithPath: settings.aiAppPath).standardizedFileURL
        if frontmostURL == configuredURL {
            return true
        }

        if let configuredBundleIdentifier = Bundle(url: configuredURL)?.bundleIdentifier,
           let frontmostBundleIdentifier = Bundle(url: frontmostURL)?.bundleIdentifier {
            return frontmostBundleIdentifier == configuredBundleIdentifier
        }

        return false
    }

    private func resolveObsidianAction(summarizeFirst: Bool) -> ObsidianRequestedAction {
        if summarizeFirst || settings.obsidianDefaultSummarizeBeforeSave {
            return .summarizeThenSave
        }
        return .save
    }

    private func resolvedObsidianFolderPath(folderOverride: String?) -> String? {
        if let folderOverride,
           !folderOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return folderOverride
        }

        return settings.obsidianDefaultFolderPath.isEmpty ? nil : settings.obsidianDefaultFolderPath
    }

    private func requestObsidianDestination(
        for selection: SelectionCapture,
        folderOverride: String?
    ) -> (folderPath: String?, noteTitle: String?)? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.canSelectHiddenExtension = false
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = defaultObsidianNoteTitle(for: selection)

        if let directory = resolvedObsidianFolderPath(folderOverride: folderOverride),
           !directory.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: directory)
        }

        let response = panel.runModal()
        guard response == .OK, let url = panel.url else {
            return nil
        }

        let folderPath = url.deletingLastPathComponent().path
        let title = url.deletingPathExtension().lastPathComponent
        return (
            folderPath: folderPath.isEmpty ? nil : folderPath,
            noteTitle: title.isEmpty ? nil : title
        )
    }

    private func defaultObsidianNoteTitle(for selection: SelectionCapture) -> String {
        let base = selection.sourceWindowTitle?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? selection.sourceWindowTitle!
            : defaultClipboardTitle(for: selection.text)
        let sanitized = base
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        return sanitized.hasSuffix(".md") ? sanitized : "\(sanitized).md"
    }

    private func currentPasteboardAttachments() -> [ObsidianClipAttachment] {
        let pasteboard = NSPasteboard.general
        guard let items = pasteboard.pasteboardItems else {
            return []
        }

        var attachments: [ObsidianClipAttachment] = []
        for item in items {
            guard let path = item.string(forType: .fileURL),
                  let url = URL(string: path),
                  url.isFileURL else {
                continue
            }

            let ext = url.pathExtension.lowercased()
            let mime: String
            switch ext {
            case "png": mime = "image/png"
            case "jpg", "jpeg": mime = "image/jpeg"
            case "gif": mime = "image/gif"
            case "webp": mime = "image/webp"
            case "pdf": mime = "application/pdf"
            default: continue
            }

            attachments.append(
                ObsidianClipAttachment(
                    name: url.lastPathComponent,
                    mimeType: mime,
                    sourcePath: url.path,
                    bytes: nil,
                    sha256: nil
                )
            )
        }
        return attachments
    }

    private func syncQuickActionHotkeys() {
        hotkeyService.setQuickActionHotkeys(quickActions) { [weak self] actionID in
            Task { @MainActor [weak self] in
                self?.runQuickAction(actionID)
            }
        }
    }

    private func resolvedQuickActionTitle(
        _ title: String,
        kind: QuickActionKind,
        text: String,
        clipboardItemID: UUID?
    ) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return trimmed
        }

        switch kind {
        case .pasteSavedClip:
            if let clipboardItemID,
               let item = clipboardItem(with: clipboardItemID) {
                return item.title
            }
            return "Paste Saved Clip"
        default:
            let fallback = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return fallback.isEmpty ? kind.displayName : String(fallback.prefix(40))
        }
    }

    private func quickActionOutput(for action: QuickAction) throws -> String {
        switch action.kind {
        case .typeText, .copyText:
            let text = action.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                throw NSError(domain: "QuickType", code: 2001, userInfo: [NSLocalizedDescriptionKey: "Quick action text is empty."])
            }
            return text
        case .promptSelection:
            let prompt = action.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty else {
                throw NSError(domain: "QuickType", code: 2002, userInfo: [NSLocalizedDescriptionKey: "Prompt text is empty."])
            }
            let selection = try selectionCaptureService.captureCurrentSelection(preferredProcessID: lastExternalProcessID)
            return "\(prompt)\n\n\(selection.text)"
        case .pasteSavedClip:
            guard let clipboardItemID = action.clipboardItemID,
                  let item = clipboardItem(with: clipboardItemID) else {
                throw NSError(domain: "QuickType", code: 2003, userInfo: [NSLocalizedDescriptionKey: "Saved clip is missing."])
            }
            return item.content
        }
    }

    private func copyTextToPasteboard(_ text: String) {
        suppressedClipboardContent = text
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        lastPasteboardChangeCount = NSPasteboard.general.changeCount
    }

    private func pasteTextToOriginatingApplication(_ text: String) {
        copyTextToPasteboard(text)

        let targetApplication = returnToAppAfterClipboardSelectionPID.flatMap { NSRunningApplication(processIdentifier: $0) }
        if let targetApplication {
            targetApplication.activate(options: [.activateIgnoringOtherApps])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            self?.pasteIntoFocusedApplication()
            if targetApplication != nil {
                NSApp.hide(nil)
            }
            self?.returnToAppAfterClipboardSelectionPID = nil
        }
    }

    private func pasteIntoFocusedApplication() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            return
        }

        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        keyDown?.flags = CGEventFlags.maskCommand
        keyDown?.post(tap: CGEventTapLocation.cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        keyUp?.flags = CGEventFlags.maskCommand
        keyUp?.post(tap: CGEventTapLocation.cghidEventTap)
    }

}
