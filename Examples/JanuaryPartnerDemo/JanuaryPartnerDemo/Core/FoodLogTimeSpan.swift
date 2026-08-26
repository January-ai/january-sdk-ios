import Foundation

enum FoodLogTimeSpan: String, CaseIterable, Identifiable {
    case today
    case currentWeek = "current_week"
    case lastMonth = "last_month"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: "Today"
        case .currentWeek: "This week"
        case .lastMonth: "Last month"
        }
    }

    func dateRange(
        containing referenceDate: Date = .now,
        calendar sourceCalendar: Calendar = .current
    ) -> FoodLogDateRange {
        var calendar = sourceCalendar
        calendar.firstWeekday = 1
        calendar.minimumDaysInFirstWeek = 1

        switch self {
        case .today:
            let day = calendar.startOfDay(for: referenceDate)
            return FoodLogDateRange(start: day, end: day)

        case .currentWeek:
            let start = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start
                ?? calendar.startOfDay(for: referenceDate)
            let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
            return FoodLogDateRange(start: start, end: end)

        case .lastMonth:
            let currentMonthStart = calendar.dateInterval(of: .month, for: referenceDate)?.start
                ?? calendar.startOfDay(for: referenceDate)
            let start = calendar.date(byAdding: .month, value: -1, to: currentMonthStart)
                ?? currentMonthStart
            let end = calendar.date(byAdding: .day, value: -1, to: currentMonthStart)
                ?? start
            return FoodLogDateRange(start: start, end: end)
        }
    }
}

struct FoodLogDateRange: Equatable {
    let start: Date
    let end: Date

    func apiQuery(calendar: Calendar) -> FoodLogDateQuery {
        FoodLogDateQuery(
            start: AppFormatting.apiDayString(from: start, calendar: calendar),
            end: AppFormatting.apiDayString(from: end, calendar: calendar)
        )
    }

    func displayText(calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale.current
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let startText = formatter.string(from: start)
        guard !calendar.isDate(start, inSameDayAs: end) else { return startText }
        return "\(startText) – \(formatter.string(from: end))"
    }
}

struct FoodLogDateQuery: Equatable {
    let start: String
    let end: String
}
