#if canImport(XCTest)
import XCTest
@testable import QuickType

final class AtomicFileWriterTests: XCTestCase {
    func testAppendWritesAtBottom() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("note.md")
        try "old\n".data(using: .utf8)!.write(to: file)

        let note = NoteTarget(
            id: UUID(),
            displayName: "note.md",
            filePath: file.path,
            bookmarkData: nil,
            format: .markdown,
            externalAppPath: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let writer = AtomicFileWriter()
        let entry = CaptureEntry(rawText: "new", createdAt: Date(), formattedText: "[ts] new\n")
        _ = try writer.write(entry: entry, to: note, insertion: .bottom, settings: .default)

        let output = try String(contentsOf: file)
        XCTAssertEqual(output, "old\n[ts] new\n")
    }

    func testPrependWritesAtTop() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }

        let file = dir.appendingPathComponent("note.txt")
        try "old\n".data(using: .utf8)!.write(to: file)

        let note = NoteTarget(
            id: UUID(),
            displayName: "note.txt",
            filePath: file.path,
            bookmarkData: nil,
            format: .plainText,
            externalAppPath: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let writer = AtomicFileWriter()
        let entry = CaptureEntry(rawText: "new", createdAt: Date(), formattedText: "[ts] new\n")
        _ = try writer.write(entry: entry, to: note, insertion: .top, settings: .default)

        let output = try String(contentsOf: file)
        XCTAssertEqual(output, "[ts] new\nold\n")
    }
}
#endif
