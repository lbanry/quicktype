import Foundation

enum FileWriterError: Error, LocalizedError {
    case unableToRead
    case unableToWrite

    var errorDescription: String? {
        switch self {
        case .unableToRead: "Unable to read file contents."
        case .unableToWrite: "Unable to write file contents."
        }
    }
}

final class AtomicFileWriter: FileWriterProtocol {
    func write(entry: CaptureEntry, to note: NoteTarget, insertion: InsertionPosition, settings: AppSettings) throws -> WriteResult {
        let fileURL = note.fileURL
        let fileManager = FileManager.default
        var warnings: [String] = []

        if !fileManager.fileExists(atPath: fileURL.path) {
            try Data().write(to: fileURL, options: .atomic)
        }

        let originalData = (try? Data(contentsOf: fileURL)) ?? Data()
        let originalMTime = modificationDate(of: fileURL)
        let originalString = String(data: originalData, encoding: .utf8) ?? ""

        let backupCreated = try createBackupIfNeeded(noteID: note.id, originalData: originalData, settings: settings)

        let updatedString: String
        switch insertion {
        case .top:
            updatedString = entry.formattedText + originalString
        case .bottom:
            updatedString = originalString + entry.formattedText
        }

        guard let updatedData = updatedString.data(using: .utf8) else {
            throw FileWriterError.unableToWrite
        }

        let tempURL = fileURL.deletingLastPathComponent().appendingPathComponent(".quicktype-\(UUID().uuidString).tmp")
        do {
            try updatedData.write(to: tempURL, options: .atomic)
            if modificationDate(of: fileURL) != originalMTime {
                warnings.append("File changed during write. Merging with latest content.")
                let latestData = (try? Data(contentsOf: fileURL)) ?? Data()
                let merged = mergeWithLatest(
                    latestData: latestData,
                    entry: entry,
                    insertion: insertion
                )
                try merged.write(to: tempURL, options: .atomic)
            }
            _ = try fileManager.replaceItemAt(fileURL, withItemAt: tempURL)
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                _ = try? handle.synchronize()
                try? handle.close()
            }
        } catch {
            warnings.append("Atomic replace failed, falling back to direct write.")
            do {
                try updatedData.write(to: fileURL, options: .atomic)
            } catch {
                throw FileWriterError.unableToWrite
            }
        }

        let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path)
        let newSize = (attrs?[.size] as? NSNumber)?.intValue ?? updatedData.count

        return WriteResult(
            bytesWritten: updatedData.count - originalData.count,
            newFileSize: newSize,
            backupCreated: backupCreated,
            warnings: warnings
        )
    }

    private func mergeWithLatest(latestData: Data, entry: CaptureEntry, insertion: InsertionPosition) -> Data {
        let latestString = String(data: latestData, encoding: .utf8) ?? ""
        let merged: String
        switch insertion {
        case .top:
            merged = entry.formattedText + latestString
        case .bottom:
            merged = latestString + entry.formattedText
        }
        return merged.data(using: .utf8) ?? latestData
    }

    private func modificationDate(of url: URL) -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attrs?[.modificationDate] as? Date
    }

    private func createBackupIfNeeded(noteID: UUID, originalData: Data, settings: AppSettings) throws -> Bool {
        guard !originalData.isEmpty else { return false }

        let backupDir = AppPaths.backupsDirectory.appendingPathComponent(noteID.uuidString, isDirectory: true)
        if !FileManager.default.fileExists(atPath: backupDir.path) {
            try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let backupURL = backupDir.appendingPathComponent("backup-\(formatter.string(from: Date())).txt")
        try originalData.write(to: backupURL, options: .atomic)

        try pruneBackups(in: backupDir, retention: settings.backupRetentionCount)
        return true
    }

    private func pruneBackups(in directory: URL, retention: Int) throws {
        let urls = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles])
        let sorted = try urls.sorted { lhs, rhs in
            let la = try lhs.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast
            let ra = try rhs.resourceValues(forKeys: [.creationDateKey]).creationDate ?? .distantPast
            return la > ra
        }

        guard sorted.count > retention else { return }
        for url in sorted.dropFirst(retention) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}
