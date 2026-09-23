import XCTest

/// Pure tests of the Tracking charts' date ranges, request chunking, aggregation, and unit
/// conversion. `TrackingChartData.swift` is compiled into this bundle; no app launch is needed.
final class TrackingChartDataTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: "America/Chicago")!
        return calendar
    }
    private let english = Locale(identifier: "en_US")

    private func day(_ value: String) -> Date { TrackingChartData.date(fromDay: value, calendar: calendar)! }
    /// Late evening local time, when the UTC date has already moved on.
    private var today: Date { calendar.date(bySettingHour: 23, minute: 30, second: 0, of: day("2026-09-22"))! }

    // MARK: The end user's timezone

    private func calendar(in identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func instant(_ value: String) -> Date { ISO8601DateFormatter().date(from: value)! }

    /// 03:30 UTC on 23 September is still the 22nd in New York and already 17:30 on the 23rd in
    /// Kiritimati (UTC+14); the day, the chart ranges, and a log's time follow the end user's zone.
    func testDaysFollowTheEndUsersTimezoneWhateverTheDevicesIs() {
        let now = instant("2026-09-23T03:30:00Z")
        let newYork = calendar(in: "America/New_York"), kiritimati = calendar(in: "Pacific/Kiritimati")

        XCTAssertEqual(TrackingChartData.dayString(now, calendar: newYork), "2026-09-22")
        XCTAssertEqual(TrackingChartData.dayString(now, calendar: kiritimati), "2026-09-23")
        XCTAssertEqual(TrackingChartData.requestSpans(for: .week, today: now, calendar: newYork),
                       [TrackingDaySpan(start: "2026-09-16", end: "2026-09-22")])
        XCTAssertEqual(TrackingChartData.requestSpans(for: .week, today: now, calendar: kiritimati),
                       [TrackingDaySpan(start: "2026-09-17", end: "2026-09-23")])
    }

    func testALogForAnEarlierDayIsDatedNoonOnTheEndUsersClock() {
        let now = instant("2026-09-23T03:30:00Z")
        let newYork = calendar(in: "America/New_York"), kiritimati = calendar(in: "Pacific/Kiritimati")

        // Today's log is dated now.
        XCTAssertEqual(TrackingChartData.entryTime(forDay: now, now: now, calendar: kiritimati), now)
        // The day before: noon on 22 September in UTC+14 is 22:00 UTC on the 21st, and noon on
        // 21 September in New York (UTC-4) is 16:00 UTC.
        let kiritimatiYesterday = kiritimati.date(byAdding: .day, value: -1, to: now)!
        XCTAssertEqual(TrackingChartData.entryTime(forDay: kiritimatiYesterday, now: now, calendar: kiritimati),
                       instant("2026-09-21T22:00:00Z"))
        let newYorkYesterday = newYork.date(byAdding: .day, value: -1, to: now)!
        XCTAssertEqual(TrackingChartData.entryTime(forDay: newYorkYesterday, now: now, calendar: newYork),
                       instant("2026-09-21T16:00:00Z"))
    }

    // MARK: Ranges and chunking

    func testWeekAndMonthEndTodayInOneRequest() {
        XCTAssertEqual(TrackingChartData.requestSpans(for: .week, today: today, calendar: calendar),
                       [TrackingDaySpan(start: "2026-09-16", end: "2026-09-22")])
        XCTAssertEqual(TrackingChartData.requestSpans(for: .month, today: today, calendar: calendar),
                       [TrackingDaySpan(start: "2026-08-24", end: "2026-09-22")])
    }

    func testYearCoversTwelveCalendarMonthsInSpansOfAtMostNinetyDays() {
        let spans = TrackingChartData.requestSpans(for: .year, today: today, calendar: calendar)
        XCTAssertEqual(spans, [
            TrackingDaySpan(start: "2025-10-01", end: "2025-12-29"),
            TrackingDaySpan(start: "2025-12-30", end: "2026-03-29"),
            TrackingDaySpan(start: "2026-03-30", end: "2026-06-27"),
            TrackingDaySpan(start: "2026-06-28", end: "2026-09-22"),
        ])
        for (previous, next) in zip(spans, spans.dropFirst()) {
            XCTAssertEqual(calendar.date(byAdding: .day, value: 1, to: day(previous.end)), day(next.start))
        }
        for span in spans {
            let days = calendar.dateComponents([.day], from: day(span.start), to: day(span.end)).day! + 1
            XCTAssertLessThanOrEqual(days, 90)
        }
    }

    func testChunksHandleExactMultiplesAndSingleDays() {
        XCTAssertEqual(TrackingChartData.chunks(from: day("2026-01-01"), to: day("2026-01-06"), maximumDays: 3, calendar: calendar), [
            TrackingDaySpan(start: "2026-01-01", end: "2026-01-03"),
            TrackingDaySpan(start: "2026-01-04", end: "2026-01-06"),
        ])
        XCTAssertEqual(TrackingChartData.chunks(from: day("2026-01-01"), to: day("2026-01-01"), maximumDays: 90, calendar: calendar),
                       [TrackingDaySpan(start: "2026-01-01", end: "2026-01-01")])
    }

    func testChunksCrossDaylightSavingTransitions() {
        let spans = TrackingChartData.chunks(from: day("2026-03-01"), to: day("2026-03-14"), maximumDays: 7, calendar: calendar)
        XCTAssertEqual(spans, [
            TrackingDaySpan(start: "2026-03-01", end: "2026-03-07"),
            TrackingDaySpan(start: "2026-03-08", end: "2026-03-14"),
        ])
    }

    func testMergeKeepsSpanOrderAndOneEntryPerDay() {
        let merged = TrackingChartData.merge([[("2026-01-02", 1.0), ("2026-01-01", 2.0)], [("2026-01-02", 3.0), ("2026-01-03", 4.0)]], key: \.0)
        XCTAssertEqual(merged.map(\.0), ["2026-01-01", "2026-01-02", "2026-01-03"])
        XCTAssertEqual(merged.map(\.1), [2, 3, 4])
    }

    // MARK: Aggregation

    func testDailyBarsFillMissingDaysWithZero() {
        let bars = TrackingChartData.waterBars(totals: ["2026-09-16": 8, "2026-09-22": 16, "2026-09-10": 99], range: .week, today: today, calendar: calendar)
        XCTAssertEqual(bars.count, 7)
        XCTAssertEqual(bars.map(\.key).first, "2026-09-16")
        XCTAssertEqual(bars.map(\.key).last, "2026-09-22")
        XCTAssertEqual(bars.map(\.value), [8, 0, 0, 0, 0, 0, 16])
        XCTAssertEqual(TrackingChartData.waterBars(totals: [:], range: .month, today: today, calendar: calendar).count, 30)
    }

    func testMonthlyBarsSumDailyTotalsPerCalendarMonth() {
        let totals = ["2025-10-01": 10.0, "2025-10-31": 5, "2026-02-28": 7.5, "2026-09-01": 1, "2026-09-22": 2, "2025-09-30": 100]
        let bars = TrackingChartData.waterBars(totals: totals, range: .year, today: today, calendar: calendar)
        XCTAssertEqual(bars.count, 12)
        XCTAssertEqual(bars.first?.key, "2025-10")
        XCTAssertEqual(bars.last?.key, "2026-09")
        XCTAssertEqual(bars.first?.value, 15)
        XCTAssertEqual(bars.first { $0.key == "2026-02" }?.value, 7.5)
        XCTAssertEqual(bars.last?.value, 3)
        XCTAssertEqual(bars.filter { $0.value == 0 }.count, 9)
    }

    // MARK: Units

    func testWeightConversionUsesTheExactPound() {
        XCTAssertEqual(TrackingChartData.convertWeight(1, from: "lb", to: "kg"), 0.45359237, accuracy: 1e-12)
        XCTAssertEqual(TrackingChartData.convertWeight(100, from: "kg", to: "lb"), 220.462262, accuracy: 1e-6)
        XCTAssertEqual(TrackingChartData.convertWeight(70, from: "kg", to: "kg"), 70)
    }

    func testSwitchingTheWaterUnitKeepsTheVolumeToLogWithinTheUnitsRange() {
        // 8 fl oz is below the 30 ml minimum; switching units converts it instead of keeping 8.
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(8, from: "fl_oz", to: "ml"), 237)
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(8, from: "fl_oz", to: "cup"), 1)
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(237, from: "ml", to: "fl_oz"), 8)
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(250, from: "ml", to: "cup"), 1.1)
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(1.5, from: "cup", to: "ml"), 355)
        // 250 typed in milliliters is logged as 8.5 fl oz after a switch, not as 250 fl oz.
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(250, from: "ml", to: "fl_oz"), 8.5)
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(12.5, from: "fl_oz", to: "fl_oz"), 12.5)
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(12.5, from: "fl_oz", to: "gallon"), 12.5)
    }

    func testConvertedWaterAmountsStayWithinTheNewUnitsRange() {
        // The smallest amounts round below the cup minimum (0.125) at the field's precision.
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(1, from: "fl_oz", to: "cup"), 0.2)
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(30, from: "ml", to: "cup"), 0.2)
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(0.125, from: "cup", to: "ml"), 30)
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(0.2, from: "cup", to: "fl_oz"), 1.6)
        // The largest ones stay at or below each maximum.
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(24_000, from: "ml", to: "fl_oz"), 811.5)
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(811.5, from: "fl_oz", to: "cup"), 101.4)
        XCTAssertEqual(TrackingChartData.convertVolumeEntry(101.4, from: "cup", to: "ml"), 23_990)
    }

    func testSwitchingTheWeightUnitConvertsTheWeightToLogToTenths() {
        XCTAssertEqual(TrackingChartData.convertWeightEntry(150, from: "lb", to: "kg"), 68)
        XCTAssertEqual(TrackingChartData.convertWeightEntry(72.5, from: "kg", to: "lb"), 159.8)
        XCTAssertEqual(TrackingChartData.convertWeightEntry(72.54, from: "kg", to: "kg"), 72.54)
        XCTAssertEqual(TrackingChartData.convertWeightEntry(70, from: "kg", to: "lb"), 154.3)
        XCTAssertEqual(TrackingChartData.convertWeightEntry(1, from: "lb", to: "kg"), 0.5)
    }

    func testSwitchingUnitsLeavesAnEmptyAmountEmpty() {
        XCTAssertNil(TrackingChartData.convertVolumeEntry(nil, from: "ml", to: "fl_oz"))
        XCTAssertNil(TrackingChartData.convertVolumeEntry(nil, from: "fl_oz", to: "cup"))
        XCTAssertNil(TrackingChartData.convertWeightEntry(nil, from: "lb", to: "kg"))
    }

    func testWeightPointsConvertMixedUnitsAndSortByDay() {
        let points = TrackingChartData.weightPoints([
            (day: "2026-09-21", value: 154, unit: "lb"),
            (day: "2026-09-20", value: 70.2, unit: "kg"),
        ], in: "kg", calendar: calendar)
        XCTAssertEqual(points.map(\.day), ["2026-09-20", "2026-09-21"])
        XCTAssertEqual(points[0].value, 70.2)
        XCTAssertEqual(points[1].value, 69.853, accuracy: 0.001)
    }

    // MARK: Summaries

    func testSummariesDescribeTheRange() {
        let points = TrackingChartData.weightPoints([
            (day: "2026-09-18", value: 70.2, unit: "kg"), (day: "2026-09-20", value: 70, unit: "kg"), (day: "2026-09-22", value: 69.8, unit: "kg"),
        ], in: "kg", calendar: calendar)
        XCTAssertEqual(TrackingChartData.weightSummary(points, range: .week, unit: "kg", locale: english),
                       "Weight, last 7 days: 3 entries, from 70.2 kg to 69.8 kg")
        XCTAssertEqual(TrackingChartData.weightSummary([], range: .month, unit: "kg", locale: english), "Weight, last 30 days: no entries")

        let bars = TrackingChartData.waterBars(totals: ["2026-09-21": 32, "2026-09-22": 16.5], range: .week, today: today, calendar: calendar)
        XCTAssertEqual(TrackingChartData.waterSummary(bars, range: .week, unit: "fl oz", locale: english),
                       "Water, last 7 days: 2 days logged, 48.5 fl oz in total")
        let yearly = TrackingChartData.waterBars(totals: ["2026-09-21": 2], range: .year, today: today, calendar: calendar)
        XCTAssertEqual(TrackingChartData.waterSummary(yearly, range: .year, unit: "cup", locale: english),
                       "Water, last 12 months: 1 month logged, 2 cup in total")
    }
}
