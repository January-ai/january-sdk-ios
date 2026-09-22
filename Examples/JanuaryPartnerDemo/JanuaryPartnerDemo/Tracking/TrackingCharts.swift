import Charts
import January
import SwiftUI

/// Week, Month, and Year as real buttons with a selected state, so each range has its own
/// accessibility identifier (`<prefix>-range-week`, …).
struct TrackingChartRangePicker: View {
    let identifierPrefix: String
    let label: String
    @Binding var selection: TrackingChartRange

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TrackingChartRange.allCases, id: \.self) { range in
                let isSelected = range == selection
                Button { selection = range } label: {
                    Text(range.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? AppPalette.ink : AppPalette.muted)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(AppPalette.surface)
                                    .shadow(color: AppPalette.ink.opacity(0.08), radius: 2, y: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                .accessibilityIdentifier("\(identifierPrefix)-range-\(range.rawValue)")
            }
        }
        .padding(4)
        .background(AppPalette.control, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

// MARK: - Weight

/// A line of the user's daily weight over the selected range, in the card's unit.
struct WeightTrendChart: View {
    let client: JanuaryClient
    let context: PartnerUserContext
    let unit: WeightUnit
    let calendar: Calendar
    /// Bumped by the Tracking screen after a new weight is logged.
    let revision: Int

    @State private var range = TrackingChartRange.week
    @State private var loaded: (range: TrackingChartRange, items: [DailyWeight])?
    @State private var error: Error?

    private struct LoadKey: Hashable { let context: PartnerUserContext; let range: TrackingChartRange; let revision: Int }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TrackingChartRangePicker(identifierPrefix: "weight-chart", label: "Weight chart range", selection: $range)
            if let error {
                ErrorNotice(
                    error: error,
                    retry: { Task { await load() } },
                    identifier: "weight-chart-error",
                    retryIdentifier: "weight-chart-retry"
                )
            } else if let loaded, loaded.range == range {
                let points = TrackingChartData.weightPoints(
                    loaded.items.map { (day: $0.date, value: $0.weight.value, unit: $0.weight.unit.rawValue) },
                    in: unit.rawValue,
                    calendar: calendar
                )
                if points.isEmpty {
                    TrackingChartEmpty(message: "No weight logged in this range", symbol: "scalemass")
                        .accessibilityIdentifier("weight-chart-empty")
                } else {
                    chart(points)
                }
            } else {
                TrackingChartLoading(message: "Loading weight trend…")
                    .accessibilityIdentifier("weight-chart-loading")
            }
        }
        .task(id: LoadKey(context: context, range: range, revision: revision)) { await load() }
    }

    private func chart(_ points: [TrackingWeightPoint]) -> some View {
        let values = points.map(\.value)
        let low = values.min() ?? 0, high = values.max() ?? 0
        let interval = TrackingChartData.interval(for: range, today: .now, calendar: calendar)
        // Marks sit in the middle of their day, so the domain runs to the end of today.
        let domainEnd = calendar.date(byAdding: .day, value: 1, to: interval.end) ?? interval.end
        let padding = max(0.5, (high - low) * 0.2)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                TrackingChartStat(title: "Latest", value: "\(TrackingChartData.number(points.last?.value ?? 0)) \(unit.rawValue)")
                Spacer(minLength: 12)
                TrackingChartStat(
                    title: "Low – high",
                    value: "\(TrackingChartData.number(low))–\(TrackingChartData.number(high)) \(unit.rawValue)",
                    alignment: .trailing
                )
            }
            Chart(points) { point in
                LineMark(x: .value("Day", point.date, unit: .day), y: .value("Weight", point.value))
                    .foregroundStyle(AppPalette.green)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                    .interpolationMethod(.monotone)
                if points.count <= 31 {
                    PointMark(x: .value("Day", point.date, unit: .day), y: .value("Weight", point.value))
                        .foregroundStyle(AppPalette.green)
                        .symbolSize(28)
                }
            }
            .chartXScale(domain: interval.start...domainEnd)
            .chartYScale(domain: (low - padding).rounded(.down)...(high + padding).rounded(.up))
            .chartXAxis { TrackingChartAxis.xMarks(for: range, calendar: calendar) }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
            .frame(height: 180)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TrackingChartData.weightSummary(points, range: range, unit: unit.rawValue))
        .accessibilityIdentifier("weight-chart")
    }

    @MainActor private func load() async {
        let range = range
        error = nil
        do {
            var pages: [[DailyWeight]] = []
            for span in TrackingChartData.requestSpans(for: range, today: .now, calendar: calendar) {
                pages.append(try await client.weightLogs.list(.init(start: span.start, end: span.end, user: context)).items)
            }
            guard !Task.isCancelled else { return }
            loaded = (range, TrackingChartData.merge(pages, key: \.date))
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error
        }
    }
}

// MARK: - Water

/// Bars of the user's water: one per day for Week and Month, one per calendar month for Year.
struct WaterTrendChart: View {
    let client: JanuaryClient
    let context: PartnerUserContext
    let unit: VolumeUnit
    let unitTitle: String
    let calendar: Calendar
    /// Bumped by the Tracking screen after water is logged or deleted.
    let revision: Int

    @State private var range = TrackingChartRange.week
    @State private var loaded: (range: TrackingChartRange, unit: VolumeUnit, items: [DailyWaterTotal])?
    @State private var error: Error?

    private struct LoadKey: Hashable { let context: PartnerUserContext; let range: TrackingChartRange; let unit: VolumeUnit; let revision: Int }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TrackingChartRangePicker(identifierPrefix: "water-chart", label: "Water chart range", selection: $range)
            if let error {
                ErrorNotice(
                    error: error,
                    retry: { Task { await load() } },
                    identifier: "water-chart-error",
                    retryIdentifier: "water-chart-retry"
                )
            } else if let loaded, loaded.range == range, loaded.unit == unit {
                let bars = TrackingChartData.waterBars(
                    totals: Dictionary(loaded.items.map { ($0.date, $0.total.value) }, uniquingKeysWith: { _, last in last }),
                    range: range,
                    today: .now,
                    calendar: calendar
                )
                if bars.allSatisfy({ $0.value <= 0 }) {
                    TrackingChartEmpty(message: "No water logged in this range", symbol: "drop")
                        .accessibilityIdentifier("water-chart-empty")
                } else {
                    chart(bars)
                }
            } else {
                TrackingChartLoading(message: "Loading water history…")
                    .accessibilityIdentifier("water-chart-loading")
            }
        }
        .task(id: LoadKey(context: context, range: range, unit: unit, revision: revision)) { await load() }
    }

    private func chart(_ bars: [TrackingWaterBar]) -> some View {
        let total = bars.reduce(0) { $0 + $1.value }
        let logged = max(bars.filter { $0.value > 0 }.count, 1)
        let barUnit: Calendar.Component = range == .year ? .month : .day
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                TrackingChartStat(title: "Total", value: "\(TrackingChartData.number(total)) \(unitTitle)")
                Spacer(minLength: 12)
                TrackingChartStat(
                    title: range == .year ? "Avg per logged month" : "Avg per logged day",
                    value: "\(TrackingChartData.number(total / Double(logged))) \(unitTitle)",
                    alignment: .trailing
                )
            }
            Chart(bars) { bar in
                BarMark(x: .value("Period", bar.date, unit: barUnit), y: .value("Water", bar.value))
                    .foregroundStyle(TrackingChartAxis.water)
                    .clipShape(RoundedRectangle(cornerRadius: range == .month ? 2 : 4, style: .continuous))
            }
            .chartXAxis { TrackingChartAxis.xMarks(for: range, calendar: calendar) }
            .chartYAxis { AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) }
            .frame(height: 180)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(TrackingChartData.waterSummary(bars, range: range, unit: unitTitle))
        .accessibilityIdentifier("water-chart")
    }

    @MainActor private func load() async {
        let range = range, unit = unit
        error = nil
        do {
            var pages: [[DailyWaterTotal]] = []
            for span in TrackingChartData.requestSpans(for: range, today: .now, calendar: calendar) {
                pages.append(try await client.waterLogs.list(.init(start: span.start, end: span.end, unit: unit, user: context)).items)
            }
            guard !Task.isCancelled else { return }
            loaded = (range, unit, TrackingChartData.merge(pages, key: \.date))
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error
        }
    }
}

// MARK: - Shared pieces

private enum TrackingChartAxis {
    static let water = Color(red: 74 / 255, green: 124 / 255, blue: 158 / 255)

    /// Sparse date labels: every weekday for Week, weekly for Month, every other month for Year.
    @AxisContentBuilder
    static func xMarks(for range: TrackingChartRange, calendar: Calendar) -> some AxisContent {
        switch range {
        case .week:
            AxisMarks(values: .stride(by: .day)) { _ in
                AxisValueLabel(format: style(.dateTime.weekday(.abbreviated), calendar), centered: true)
            }
        case .month:
            AxisMarks(values: .stride(by: .day, count: 7)) { _ in
                AxisGridLine()
                AxisValueLabel(format: style(.dateTime.month(.abbreviated).day(), calendar))
            }
        case .year:
            AxisMarks(values: .stride(by: .month, count: 2)) { _ in
                AxisGridLine()
                AxisValueLabel(format: style(.dateTime.month(.abbreviated), calendar))
            }
        }
    }

    private static func style(_ base: Date.FormatStyle, _ calendar: Calendar) -> Date.FormatStyle {
        var style = base
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return style
    }
}

private struct TrackingChartStat: View {
    let title: String
    let value: String
    var alignment: HorizontalAlignment = .leading

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppPalette.muted)
            Text(value)
                .font(AppTypography.bodyStrong.monospacedDigit())
                .foregroundStyle(AppPalette.ink)
        }
    }
}

private struct TrackingChartEmpty: View {
    let message: String
    let symbol: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(AppPalette.green)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.body)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .background(AppPalette.control, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct TrackingChartLoading: View {
    let message: String

    var body: some View {
        HStack(spacing: 12) {
            LoadingSpinner(color: AppPalette.green)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .accessibilityElement(children: .combine)
    }
}
