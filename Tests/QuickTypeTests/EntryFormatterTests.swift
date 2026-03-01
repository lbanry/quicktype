#if canImport(XCTest)
import XCTest
@testable import QuickType

final class EntryFormatterTests: XCTestCase {
    func testCustomTimestampFormatUsesUTCWhenEnabled() {
        let formatter = EntryFormatter()
        var settings = AppSettings.default
        settings.timestampMode = .custom
        settings.customDateFormat = "yyyy-MM-dd HH:mm"
        settings.useUTC = true
        settings.dateLocaleIdentifier = "en_US_POSIX"

        let fixedDate = Date(timeIntervalSince1970: 0)
        let entry = formatter.format(rawText: "hello", date: fixedDate, settings: settings)

        XCTAssertEqual(entry.formattedText, "[1970-01-01 00:00] hello\n")
    }
}
#endif
