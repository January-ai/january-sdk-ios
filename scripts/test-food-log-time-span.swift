import Foundation

enum AppFormatting {
    static func apiDayString(from date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

@main
struct FoodLogTimeSpanTests {
    static func main() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        calendar.firstWeekday = 1
        calendar.minimumDaysInFirstWeek = 1

        let referenceDate = calendar.date(from: DateComponents(
            year: 2026,
            month: 8,
            day: 25,
            hour: 12
        ))!

        expect(
            .today,
            referenceDate: referenceDate,
            calendar: calendar,
            start: "2026-08-25",
            end: "2026-08-25"
        )
        expect(
            .currentWeek,
            referenceDate: referenceDate,
            calendar: calendar,
            start: "2026-08-23",
            end: "2026-08-29"
        )
        expect(
            .lastMonth,
            referenceDate: referenceDate,
            calendar: calendar,
            start: "2026-07-01",
            end: "2026-07-31"
        )
    }

    private static func expect(
        _ span: FoodLogTimeSpan,
        referenceDate: Date,
        calendar: Calendar,
        start: String,
        end: String
    ) {
        let query = span
            .dateRange(containing: referenceDate, calendar: calendar)
            .apiQuery(calendar: calendar)
        precondition(query == FoodLogDateQuery(start: start, end: end))
    }
}
