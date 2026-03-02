import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var noteTargets: [NoteTarget] = []
    @Published var selectedNoteID: UUID?
    @Published var settings: AppSettings = .default
    @Published var captureText = ""
    @Published var recoveryIssues: [RecoveryIssue] = []
    @Published var lastStatusMessage = ""

    let noteRepository: NoteRepositoryProtocol
    let settingsStore: SettingsStoreProtocol
    let bookmarkService: BookmarkServiceProtocol
    let fileWriter: FileWriterProtocol
    let recoveryService: RecoveryServiceProtocol
    let hotkeyService: HotkeyServiceProtocol
    let selectionCaptureService: SelectionCaptureServiceProtocol
    let obsidianClipExportService = ObsidianClipExportService()
    let formatter = EntryFormatter()
    private var workspaceObserver: NSObjectProtocol?
    private var lastExternalProcessID: pid_t?

    init(
        noteRepository: NoteRepositoryProtocol,
        settingsStore: SettingsStoreProtocol,
        bookmarkService: BookmarkServiceProtocol,
        fileWriter: FileWriterProtocol,
        recoveryService: RecoveryServiceProtocol,
        hotkeyService: HotkeyServiceProtocol,
        selectionCaptureService: SelectionCaptureServiceProtocol
    ) {
        self.noteRepository = noteRepository
        self.settingsStore = settingsStore
        self.bookmarkService = bookmarkService
        self.fileWriter = fileWriter
        self.recoveryService = recoveryService
        self.hotkeyService = hotkeyService
        self.selectionCaptureService = selectionCaptureService
    }

    var selectedNote: NoteTarget? {
        noteTargets.first(where: { $0.id == selectedNoteID })
    }

    func bootstrap(openCaptureWindow: @escaping () -> Void) {
        do {
            settings = try settingsStore.loadSettings()
            noteTargets = try noteRepository.loadNoteTargets()
            selectedNoteID = noteTargets.first?.id
            recoveryIssues = recoveryService.scan(noteTargets: noteTargets)
            hotkeyService.onHotkeyPressed = openCaptureWindow
            hotkeyService.onClipHotkeyPressed = { [weak self] in
                Task { @MainActor [weak self] in
                    self?.copyHighlightedTextToNewNote()
                }
            }
            hotkeyService.start(with: settings.hotkey, clipHotkey: .clipDefault)
            startTrackingActiveApplications()
        } catch {
            Logger.error("Failed bootstrap: \(error.localizedDescription)")
            lastStatusMessage = "Failed to load state: \(error.localizedDescription)"
        }
    }

    func persist() {
        do {
            try noteRepository.saveNoteTargets(noteTargets)
            try settingsStore.saveSettings(settings)
        } catch {
            Logger.error("Persist failed: \(error.localizedDescription)")
            lastStatusMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    func saveCapture() {
        guard let note = selectedNote else {
            lastStatusMessage = "Select or create a note target first."
            return
        }
        let trimmed = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            lastStatusMessage = "Capture is empty."
            return
        }

        let entry = formatter.format(rawText: trimmed, settings: settings)
        do {
            let result = try fileWriter.write(entry: entry, to: note, insertion: settings.insertionPosition, settings: settings)
            if let idx = noteTargets.firstIndex(where: { $0.id == note.id }) {
                noteTargets[idx].updatedAt = Date()
            }
            persist()
            recoveryIssues = recoveryService.scan(noteTargets: noteTargets)
            captureText = ""
            lastStatusMessage = "Saved (\(result.bytesWritten) bytes)."
        } catch {
            Logger.error("Save capture failed: \(error.localizedDescription)")
            lastStatusMessage = "Save failed: \(error.localizedDescription)"
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
        RecoveryIssues: \(recoveryIssues.count)
        Settings: \(settings)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(diagnostics, forType: .string)
        lastStatusMessage = "Diagnostics copied."
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

    func saveHighlightedTextToObsidian(summarizeFirst: Bool) {
        guard settings.obsidianIntegrationEnabled else {
            lastStatusMessage = "Obsidian integration is disabled in Settings."
            return
        }

        do {
            let selection = try selectionCaptureService.captureCurrentSelection(preferredProcessID: lastExternalProcessID)
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
                    folderPath: settings.obsidianDefaultFolderPath.isEmpty ? nil : settings.obsidianDefaultFolderPath
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

    private func resolveObsidianAction(summarizeFirst: Bool) -> ObsidianRequestedAction {
        if summarizeFirst || settings.obsidianDefaultSummarizeBeforeSave {
            return .summarizeThenSave
        }
        return .save
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

}
