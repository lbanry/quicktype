import Foundation

struct EntryFormatter {
    func format(rawText: String, date: Date = Date(), settings: AppSettings) -> CaptureEntry {
        let stamp = timestamp(for: date, settings: settings)
        let line = "[\(stamp)] \(rawText.trimmingCharacters(in: .whitespacesAndNewlines))\n"
        return CaptureEntry(rawText: rawText, createdAt: date, formattedText: line)
    }

    private func timestamp(for date: Date, settings: AppSettings) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: settings.dateLocaleIdentifier)
        if settings.useUTC {
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
        }

        switch settings.timestampMode {
        case .dateTime:
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
        case .dateOnly:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        case .timeOnly:
            formatter.dateStyle = .none
            formatter.timeStyle = .medium
        case .custom:
            formatter.dateFormat = settings.customDateFormat
        }

        return formatter.string(from: date)
    }
}
