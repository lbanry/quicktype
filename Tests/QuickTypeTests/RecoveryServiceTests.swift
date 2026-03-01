#if canImport(XCTest)
import XCTest
@testable import QuickType

final class RecoveryServiceTests: XCTestCase {
    func testMissingFileIsReported() throws {
        let bookmark = StubBookmarkService()
        let service = RecoveryService(bookmarkService: bookmark)

        let note = NoteTarget(
            id: UUID(),
            displayName: "missing.txt",
            filePath: "/tmp/quicktype-does-not-exist-\(UUID().uuidString)",
            bookmarkData: nil,
            format: .plainText,
            externalAppPath: nil,
            createdAt: Date(),
            updatedAt: Date()
        )

        let issues = service.scan(noteTargets: [note])
        XCTAssertEqual(issues.count, 1)
        XCTAssertEqual(issues.first?.issueType, .fileMissing)
    }
}

private final class StubBookmarkService: BookmarkServiceProtocol {
    func makeBookmark(for fileURL: URL) throws -> Data { Data() }
    func resolveBookmark(_ data: Data) throws -> (url: URL, isStale: Bool) { (URL(fileURLWithPath: "/tmp"), false) }
}
#endif
