import Foundation

/// The Tracking charts' time ranges. Every range ends today in the user's timezone.
enum TrackingChartRange: String, CaseIterable, Hashable, Sendable {
    case week, month, year

    var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        }
    }

    /// How the range reads in a chart summary, e.g. "last 7 days".
    var summaryTitle: String {
        switch self {
        case .week: "last 7 days"
        case .month: "last 30 days"
        case .year: "last 12 months"
        }
    }
}

/// An inclusive span of local calendar days, as `yyyy-MM-dd` strings for a list request.
struct TrackingDaySpan: Hashable, Sendable {
    let start: String
    let end: String
}

/// One point on the weight line: a day and its weight in the chart's unit.
struct TrackingWeightPoint: Identifiable, Hashable, Sendable {
    let day: String
    let date: Date
    let value: Double
    var id: String { day }
}

/// One water bar: a day (Week and Month) or a calendar month (Year) and its total.
struct TrackingWaterBar: Identifiable, Hashable, Sendable {
    /// `yyyy-MM-dd` for a day, `yyyy-MM` for a month.
    let key: String
    let date: Date
    let value: Double
    var id: String { key }
}

/// Date ranges, request chunking, aggregation, and unit conversion behind the Tracking charts.
/// Pure and deterministic: every function takes the calendar (with the user's timezone) it
/// works in, so tests can pin dates.
enum TrackingChartData {
    static let kilogramsPerPound = 0.45359237
    /// The list endpoints return at most 100 days; Year is split into spans no longer than this.
    static let maximumDaysPerRequest = 90

    // MARK: Ranges

    /// First and last day of `range`, ending on `today`: 7 days for Week, 30 days for Month, and
    /// the current calendar month plus the 11 before it for Year.
    static func interval(for range: TrackingChartRange, today: Date, calendar: Calendar) -> (start: Date, end: Date) {
        let end = calendar.startOfDay(for: today)
        switch range {
        case .week:
            return (calendar.date(byAdding: .day, value: -6, to: end) ?? end, end)
        case .month:
            return (calendar.date(byAdding: .day, value: -29, to: end) ?? end, end)
        case .year:
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: end)) ?? end
            return (calendar.date(byAdding: .month, value: -11, to: monthStart) ?? monthStart, end)
        }
    }

    /// The request spans for `range`: one span for Week and Month, consecutive spans of at most
    /// `maximumDaysPerRequest` days, oldest first, for Year.
    static func requestSpans(for range: TrackingChartRange, today: Date, calendar: Calendar) -> [TrackingDaySpan] {
        let (start, end) = interval(for: range, today: today, calendar: calendar)
        switch range {
        case .week, .month: return [TrackingDaySpan(start: dayString(start, calendar: calendar), end: dayString(end, calendar: calendar))]
        case .year: return chunks(from: start, to: end, maximumDays: maximumDaysPerRequest, calendar: calendar)
        }
    }

    /// Splits `start...end` into consecutive, non-overlapping spans of at most `maximumDays` days.
    static func chunks(from start: Date, to end: Date, maximumDays: Int, calendar: Calendar) -> [TrackingDaySpan] {
        precondition(maximumDays > 0)
        var spans: [TrackingDaySpan] = []
        var chunkStart = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while chunkStart <= last {
            let proposed = calendar.date(byAdding: .day, value: maximumDays - 1, to: chunkStart) ?? last
            let chunkEnd = min(proposed, last)
            spans.append(TrackingDaySpan(start: dayString(chunkStart, calendar: calendar), end: dayString(chunkEnd, calendar: calendar)))
            guard let next = calendar.date(byAdding: .day, value: 1, to: chunkEnd) else { break }
            chunkStart = next
        }
        return spans
    }

    /// Concatenates per-span results, oldest span first, keeping one entry per key (the later one
    /// wins) in ascending key order.
    static func merge<Item>(_ pages: [[Item]], key: (Item) -> String) -> [Item] {
        var byKey: [String: Item] = [:]
        for page in pages { for item in page { byKey[key(item)] = item } }
        return byKey.keys.sorted().compactMap { byKey[$0] }
    }

    // MARK: Aggregation

    /// One bar per day from `start` to `end`; days without a total are zero.
    static func dailyBars(totals: [String: Double], start: Date, end: Date, calendar: Calendar) -> [TrackingWaterBar] {
        var bars: [TrackingWaterBar] = []
        var day = calendar.startOfDay(for: start)
        let last = calendar.startOfDay(for: end)
        while day <= last {
            let key = dayString(day, calendar: calendar)
            bars.append(TrackingWaterBar(key: key, date: day, value: totals[key] ?? 0))
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return bars
    }

    /// One bar per calendar month from `start`'s month to `end`'s month, each the sum of that
    /// month's daily totals.
    static func monthlyBars(totals: [String: Double], start: Date, end: Date, calendar: Calendar) -> [TrackingWaterBar] {
        var sums: [String: Double] = [:]
        for (day, value) in totals { sums[String(day.prefix(7)), default: 0] += value }
        var bars: [TrackingWaterBar] = []
        var month = calendar.date(from: calendar.dateComponents([.year, .month], from: start)) ?? start
        while month <= end {
            let key = String(dayString(month, calendar: calendar).prefix(7))
            bars.append(TrackingWaterBar(key: key, date: month, value: sums[key] ?? 0))
            guard let next = calendar.date(byAdding: .month, value: 1, to: month) else { break }
            month = next
        }
        return bars
    }

    /// The bars for `range`: daily for Week and Month, monthly for Year. Totals outside the range
    /// are ignored.
    static func waterBars(totals: [String: Double], range: TrackingChartRange, today: Date, calendar: Calendar) -> [TrackingWaterBar] {
        let (start, end) = interval(for: range, today: today, calendar: calendar)
        let first = dayString(start, calendar: calendar), last = dayString(end, calendar: calendar)
        let inRange = totals.filter { first <= $0.key && $0.key <= last }
        switch range {
        case .week, .month: return dailyBars(totals: inRange, start: start, end: end, calendar: calendar)
        case .year: return monthlyBars(totals: inRange, start: start, end: end, calendar: calendar)
        }
    }

    /// When a log made for `day` is dated: now for today, and otherwise noon on that day on the
    /// end user's clock (`calendar` is in their timezone), so the API files it under that day.
    static func entryTime(forDay day: Date, now: Date = .now, calendar: Calendar) -> Date {
        guard !calendar.isDate(day, inSameDayAs: now) else { return now }
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day
    }

    // MARK: Units

    /// Converts a weight between `"kg"` and `"lb"` (the SDK's `WeightUnit` raw values).
    static func convertWeight(_ value: Double, from source: String, to target: String) -> Double {
        switch (source, target) {
        case ("lb", "kg"): value * kilogramsPerPound
        case ("kg", "lb"): value / kilogramsPerPound
        default: value
        }
    }

    /// Milliliters in one `"ml"`, `"fl_oz"` (US fluid ounce), or `"cup"` (US cup, 8 fluid ounces),
    /// the SDK's `VolumeUnit` raw values.
    static let millilitersPerVolumeUnit: [String: Double] = ["ml": 1, "fl_oz": 29.5735295625, "cup": 236.5882365]

    /// The amounts one water log accepts, per unit (the SDK validates the same ranges).
    static let volumeEntryRange: [String: ClosedRange<Double>] = ["fl_oz": 1...811.5, "ml": 30...24_000, "cup": 0.1...101.4]

    /// Converts an amount the user is about to log to another volume unit, rounded the way the
    /// amount field shows it (whole milliliters, tenths of a fluid ounce or cup), so the amount
    /// logged is the amount shown, and kept within the new unit's range: 0.1 cup is about 24 ml,
    /// below the 30 ml minimum, so it becomes 30. An empty amount stays empty.
    static func convertVolumeEntry(_ value: Double?, from source: String, to target: String) -> Double? {
        guard let value else { return nil }
        guard source != target,
              let sourceMilliliters = millilitersPerVolumeUnit[source],
              let targetMilliliters = millilitersPerVolumeUnit[target] else { return value }
        let step = target == "ml" ? 1.0 : 0.1
        let converted = ((value * sourceMilliliters / targetMilliliters) / step).rounded() * step
        guard let range = volumeEntryRange[target] else { return converted }
        // The small allowance keeps binary rounding in the division from moving a bound a step.
        let lowest = (range.lowerBound / step - 1e-9).rounded(.up) * step
        let highest = (range.upperBound / step + 1e-9).rounded(.down) * step
        return ((min(max(converted, lowest), highest)) * 10).rounded() / 10
    }

    /// Converts a weight the user is about to log between `"kg"` and `"lb"`, rounded to tenths as
    /// the weight field shows it. An empty weight stays empty.
    static func convertWeightEntry(_ value: Double?, from source: String, to target: String) -> Double? {
        guard let value else { return nil }
        guard source != target else { return value }
        return (convertWeight(value, from: source, to: target) * 10).rounded() / 10
    }

    /// Weight points in `unit`, oldest first, from `(day, value, unit)` entries.
    static func weightPoints(_ entries: [(day: String, value: Double, unit: String)], in unit: String, calendar: Calendar) -> [TrackingWeightPoint] {
        entries
            .compactMap { entry in
                date(fromDay: entry.day, calendar: calendar).map {
                    TrackingWeightPoint(day: entry.day, date: $0, value: convertWeight(entry.value, from: entry.unit, to: unit))
                }
            }
            .sorted { $0.day < $1.day }
    }

    // MARK: Summaries

    /// "Weight, last 7 days: 3 entries, from 70.2 kg to 69.8 kg".
    static func weightSummary(_ points: [TrackingWeightPoint], range: TrackingChartRange, unit: String, locale: Locale = .current) -> String {
        guard let first = points.first, let last = points.last else { return "Weight, \(range.summaryTitle): no entries" }
        let count = points.count == 1 ? "1 entry" : "\(points.count) entries"
        if points.count == 1 { return "Weight, \(range.summaryTitle): \(count), \(number(first.value, locale)) \(unit)" }
        return "Weight, \(range.summaryTitle): \(count), from \(number(first.value, locale)) \(unit) to \(number(last.value, locale)) \(unit)"
    }

    /// "Water, last 7 days: 5 days logged, 320 fl oz in total" (months for Year).
    static func waterSummary(_ bars: [TrackingWaterBar], range: TrackingChartRange, unit: String, locale: Locale = .current) -> String {
        let logged = bars.filter { $0.value > 0 }.count
        guard logged > 0 else { return "Water, \(range.summaryTitle): nothing logged" }
        let period = range == .year ? (logged == 1 ? "month" : "months") : (logged == 1 ? "day" : "days")
        let total = bars.reduce(0) { $0 + $1.value }
        return "Water, \(range.summaryTitle): \(logged) \(period) logged, \(number(total, locale)) \(unit) in total"
    }

    static func number(_ value: Double, _ locale: Locale = .current) -> String {
        value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
    }

    // MARK: Days

    static func dayString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func date(fromDay day: String, calendar: Calendar) -> Date? {
        let parts = day.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
