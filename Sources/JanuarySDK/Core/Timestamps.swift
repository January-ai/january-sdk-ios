import Foundation

/// ISO-8601 handling shared by the logging resources: requests accept any
/// offset with or without fractional seconds; responses are formatted in UTC
/// with milliseconds, as the API returns them.
internal enum ISO8601Timestamp {
    static func parse(_ value: String?, field: String) throws -> Date? {
        guard let value else { return nil }
        let standard = ISO8601DateFormatter()
        if let date = standard.date(from: value) { return date }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }

        throw JanuaryError(category: .validation, message: "\(field) must be an ISO-8601 date-time.")
    }

    static func format(_ value: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: value)
    }
}
