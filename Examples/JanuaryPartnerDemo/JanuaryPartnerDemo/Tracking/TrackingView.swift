import January
import SwiftUI

/// One day of the selected user's logs: food logs with the day's nutrient totals, the day's
/// water total, and the day's weight, each logged through its SDK resource, plus week, month,
/// and year charts of water and weight that end today.
struct TrackingView: View {
    let client: JanuaryClient
    let settingsAction: () -> Void

    @EnvironmentObject private var userSession: UserSession
    @State private var day = Date.now
    @State private var logs: [FoodLog] = []
    @State private var summary: FoodLogSummary?
    @State private var isLoading = false
    @State private var error: Error?

    @State private var waterValue = 8.0
    @State private var waterUnit = VolumeUnit.fluidOunces
    @State private var waterTotal: Volume?
    /// The water log created last on this screen, with the user, timezone, and day it was logged
    /// for (`loadTaskID`); "Delete last" is offered only while those stay the same.
    @State private var lastWaterLog: (log: WaterLog, key: String)?
    @State private var waterError: Error?
    @State private var isLoggingWater = false
    @State private var isLoadingWater = false

    @State private var weightValue = 150.0
    @State private var weightUnit = WeightUnit.pounds
    @State private var dayWeight: Weight?
    @State private var weightError: Error?
    @State private var isLoggingWeight = false

    /// Bumped after water or a weight is logged so the trend charts reload.
    @State private var waterChartRevision = 0
    @State private var weightChartRevision = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenShell {
                    // A plain VStack: one day's content is short, and the chart cards' heights
                    // change as they load, which a LazyVStack can keep re-measuring.
                    VStack(alignment: .leading, spacing: 16) {
                        WorkflowGuideCard(
                            title: "Track one day at a time",
                            message: "Each day gathers the user’s meals with their nutrient totals, the water they drank, and their latest weight. A food log is one meal with one or more foods.",
                            steps: [
                                "Identify the user who owns the logs",
                                "Pick a day, then log meals, water, or a weight",
                                "Review the day’s totals and the water and weight trends"
                            ],
                            symbol: "book.closed"
                        )

                        SectionLabel("User identity")
                        FoodLogUserCard(
                            userID: userID?.rawValue,
                            timezone: userSession.timezone,
                            onSave: { userSession.endUserID = $0 },
                            onSettings: settingsAction
                        )

                        if let context {
                            SectionLabel("Day")
                            dayPicker

                            SectionLabel("Water")
                            waterCard(context)
                            SectionLabel("Weight")
                            weightCard(context)

                            SectionLabel("Meals")
                            PrimaryButton(
                                title: "Refresh this day",
                                isLoading: isLoading && logs.isEmpty,
                                isDisabled: isLoading
                            ) {
                                Task { await load() }
                            }
                            .accessibilityIdentifier("tracking-refresh")

                            if isLoading, logs.isEmpty {
                                HStack(spacing: 12) {
                                    LoadingSpinner(color: AppPalette.green)
                                    Text("Loading food logs…")
                                        .font(.headline)
                                        .foregroundStyle(AppPalette.muted)
                                }
                                .padding()
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("tracking-loading")
                            }
                            if let error {
                                ErrorNotice(
                                    error: error,
                                    retry: { Task { await load() } },
                                    identifier: "tracking-food-logs-error",
                                    retryIdentifier: "tracking-food-logs-retry"
                                )
                            }

                            if let summary, summary.totals.logsCount > 0 {
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Day totals · \(summary.totals.logsCount) log\(summary.totals.logsCount == 1 ? "" : "s")")
                                        .font(AppTypography.bodyStrong)
                                    MacroGrid(
                                        calories: summary.totals.nutrients.calories?.value,
                                        protein: summary.totals.nutrients.protein?.value,
                                        carbohydrates: summary.totals.nutrients.carbohydrates?.value,
                                        fat: summary.totals.nutrients.totalFat?.value
                                    )
                                }
                                .appCard()
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("food-logs-summary")
                            }

                            if !logs.isEmpty {
                                ForEach(Array(logs.enumerated()), id: \.element.id) { index, log in
                                    NavigationLink {
                                        FoodLogDetailView(client: client, log: log, context: context) { Task { await loadMeals() } }
                                    } label: {
                                        FoodLogRow(log: log).appCard()
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("tracking-food-log-\(index)")
                                }
                            } else if !isLoading, error == nil {
                                EmptyStateCard(
                                    title: "No food logs on this day",
                                    message: "Add meals for this day from the Logs tab.",
                                    symbol: "list.bullet.clipboard"
                                )
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("tracking-food-logs-empty")
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom, 88)
            }
            .refreshable {
                waterChartRevision += 1; weightChartRevision += 1
                await load()
            }
            .appBackground()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("tracking-screen")
            .appNavigationBar("Tracking", style: .leading) {
                EmptyView()
            } trailing: {
                AppNavigationButton(.settings, action: settingsAction)
                    .accessibilityIdentifier("settings-button")
            }
            .task(id: loadTaskID) {
                // Nothing from the previous user or day stays on screen while this one loads, and
                // "Delete last" ends: it is offered only right after logging, for that user and day.
                logs = []; summary = nil; waterTotal = nil; dayWeight = nil; lastWaterLog = nil
                error = nil; waterError = nil; weightError = nil
                guard userID != nil else { return }
                await load()
            }
        }
    }

    // MARK: - Day picker

    private var dayPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button("Previous day", systemImage: "chevron.left") { shiftDay(by: -1) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(QuantityButtonStyle())
                    .accessibilityIdentifier("logs-day-previous")
                VStack(spacing: 2) {
                    Text(isToday ? "Today" : dayTitle)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppPalette.ink)
                    Text(dayQuery)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppPalette.muted)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("logs-day-label")
                Button("Next day", systemImage: "chevron.right") { shiftDay(by: 1) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(QuantityButtonStyle())
                    .disabled(isToday)
                    .accessibilityIdentifier("logs-day-next")
            }
            if !isToday {
                Button("Back to today") { day = .now }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppPalette.greenText)
                    .accessibilityIdentifier("logs-day-today")
            }
        }
        .appCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("logs-day-picker")
    }

    // MARK: - Water and weight

    private func waterCard(_ context: PartnerUserContext) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(waterHeadline)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppPalette.ink)
                        .accessibilityIdentifier("water-total")
                    Text(isToday ? "Logged today" : "Logged on \(dayTitle)")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.muted)
                }
                Spacer(minLength: 12)
                SegmentedControl(
                    VolumeUnit.allCases,
                    selection: $waterUnit,
                    identifier: { "water-unit-\($0.rawValue)" }
                ) { unitTitle($0) }
                    .frame(maxWidth: 200)
                    .accessibilityLabel("Water units")
                    // Keep the amount to log the same volume, so it stays within the new unit's range.
                    .onChange(of: waterUnit) { previous, unit in
                        waterValue = TrackingChartData.convertVolumeEntry(waterValue, from: previous.rawValue, to: unit.rawValue)
                        // Only the water total depends on the unit.
                        waterTotal = nil; waterError = nil
                        Task { await loadWater() }
                    }
            }
            if let waterError {
                ErrorNotice(
                    error: waterError,
                    retry: { Task { await loadWater() } },
                    identifier: "water-error",
                    retryIdentifier: "water-retry"
                )
            }
            numberField("Amount · \(unitTitle(waterUnit))") {
                EndAlignedNumberField(
                    value: waterValue.formatted(.number.precision(.fractionLength(0...1))),
                    allowsDecimal: true,
                    accessibilityIdentifier: "water-amount"
                ) { value in
                    if let value = Double(value) { waterValue = value }
                }
            }
            HStack(spacing: 12) {
                PrimaryButton(
                    title: "Log water",
                    systemImage: "drop",
                    isLoading: isLoggingWater,
                    isDisabled: isLoggingWater
                ) {
                    Task { await logWater() }
                }
                .accessibilityIdentifier("water-log-create")
                if lastWaterLog?.key == loadTaskID {
                    Button("Delete last", role: .destructive) { Task { await deleteLastWater() } }
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppPalette.rustText)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 56)
                        .background(AppPalette.rustBackground, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                        .accessibilityIdentifier("water-log-delete")
                }
            }
            Divider().overlay(AppPalette.divider)
            WaterTrendChart(
                client: client,
                context: context,
                unit: waterUnit,
                unitTitle: unitTitle(waterUnit),
                calendar: calendar,
                revision: waterChartRevision
            )
        }
        .appCard()
    }

    private func weightCard(_ context: PartnerUserContext) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(weightHeadline)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppPalette.ink)
                        .accessibilityIdentifier("weight-entry")
                    Text(isToday ? "Latest today" : "Latest on \(dayTitle)")
                        .font(.subheadline)
                        .foregroundStyle(AppPalette.muted)
                }
                Spacer(minLength: 12)
                SegmentedControl(
                    WeightUnit.allCases,
                    selection: $weightUnit,
                    identifier: { "weight-unit-\($0.rawValue)" }
                ) { $0.rawValue }
                    .frame(maxWidth: 150)
                    .accessibilityLabel("Weight units")
                    .onChange(of: weightUnit) { previous, unit in
                        weightValue = TrackingChartData.convertWeightEntry(weightValue, from: previous.rawValue, to: unit.rawValue)
                    }
            }
            if let weightError {
                ErrorNotice(
                    error: weightError,
                    retry: { Task { await loadWeight() } },
                    identifier: "weight-error",
                    retryIdentifier: "weight-retry"
                )
            }
            numberField("Weight · \(weightUnit.rawValue)") {
                EndAlignedNumberField(
                    value: weightValue.formatted(.number.precision(.fractionLength(0...1))),
                    allowsDecimal: true,
                    accessibilityIdentifier: "weight-value"
                ) { value in
                    if let value = Double(value) { weightValue = value }
                }
            }
            PrimaryButton(
                title: "Log weight",
                systemImage: "scalemass",
                isLoading: isLoggingWeight,
                isDisabled: isLoggingWeight
            ) {
                Task { await logWeight() }
            }
            .accessibilityIdentifier("weight-log-create")
            Divider().overlay(AppPalette.divider)
            WeightTrendChart(
                client: client,
                context: context,
                unit: weightUnit,
                calendar: calendar,
                revision: weightChartRevision
            )
        }
        .appCard()
    }

    // MARK: - Loading and actions

    private var userID: PartnerUserID? { userSession.partnerUserID }
    private var context: PartnerUserContext? { userSession.partnerContext }
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: userSession.timezone) ?? .current
        return calendar
    }
    private var dayQuery: String { AppFormatting.apiDayString(from: day, calendar: calendar) }
    private var isToday: Bool { calendar.isDate(day, inSameDayAs: .now) }
    private var dayTitle: String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: day)
    }
    /// A meal created for a past day is dated noon on that day; today's meals default to now.
    private var defaultMealTime: Date {
        isToday ? .now : (calendar.date(bySettingHour: 12, minute: 0, second: 0, of: day) ?? day)
    }
    private var loadTaskID: String {
        "\(userSession.endUserID)|\(userSession.timezone)|\(dayQuery)"
    }

    private func shiftDay(by days: Int) {
        guard let next = calendar.date(byAdding: .day, value: days, to: day) else { return }
        day = min(next, .now)
    }

    // Each load remembers the user, timezone, and day it was for (`loadTaskID`) and drops its
    // result if they changed while it ran, so a slow or cancelled request for another user or
    // day never lands on screen.

    @MainActor private func load() async {
        guard context != nil else { return }
        let key = loadTaskID
        isLoading = true
        await loadMeals()
        await loadWater()
        await loadWeight()
        if key == loadTaskID { isLoading = false }
    }

    /// Reloads the day's food logs and their totals, for example after a log is edited or deleted.
    @MainActor private func loadMeals() async {
        guard let context else { return }
        let key = loadTaskID, day = dayQuery
        error = nil
        do {
            let dayLogs = try await client.foodLogs.list(.init(start: day, end: day, user: context)).items
            let daySummary = try await client.foodLogs.getSummary(.init(start: day, end: day, user: context))
            guard key == loadTaskID else { return }
            logs = dayLogs
            summary = daySummary
        } catch {
            guard key == loadTaskID, !(error is CancellationError) else { return }
            self.error = error
        }
    }

    /// Reloads only the day's water total, so logging water costs one list request, not four.
    @MainActor private func loadWater() async {
        guard let context else { return }
        let key = loadTaskID, day = dayQuery, unit = waterUnit
        isLoadingWater = true
        defer { if key == loadTaskID, unit == waterUnit { isLoadingWater = false } }
        do {
            let total = try await client.waterLogs.list(.init(start: day, end: day, unit: unit, user: context)).items.first?.total
            guard key == loadTaskID, unit == waterUnit else { return }
            waterTotal = total
            waterError = nil
        } catch {
            guard key == loadTaskID, unit == waterUnit, !(error is CancellationError) else { return }
            waterError = error
        }
    }

    /// Reloads only the day's weight.
    @MainActor private func loadWeight() async {
        guard let context else { return }
        let key = loadTaskID, day = dayQuery
        do {
            let weight = try await client.weightLogs.list(.init(start: day, end: day, user: context)).items.first?.weight
            guard key == loadTaskID else { return }
            dayWeight = weight
            weightError = nil
        } catch {
            guard key == loadTaskID, !(error is CancellationError) else { return }
            weightError = error
        }
    }

    @MainActor private func logWater() async {
        guard let context else { return }
        isLoggingWater = true; waterError = nil
        do {
            let key = loadTaskID
            let log = try await client.waterLogs.create(.init(
                amount: .init(value: waterValue, unit: waterUnit),
                consumedAtUTC: AppFormatting.apiDate.string(from: defaultMealTime),
                user: context
            ))
            lastWaterLog = (log, key)
            waterChartRevision += 1
            await loadWater()
        } catch { waterError = error }
        isLoggingWater = false
    }

    @MainActor private func deleteLastWater() async {
        guard let context, let lastWaterLog, lastWaterLog.key == loadTaskID else { return }
        waterError = nil
        do {
            try await client.waterLogs.delete(.init(id: lastWaterLog.log.id, user: context))
            self.lastWaterLog = nil
            waterChartRevision += 1
            await loadWater()
        } catch { waterError = error }
    }

    @MainActor private func logWeight() async {
        guard let context else { return }
        isLoggingWeight = true; weightError = nil
        do {
            _ = try await client.weightLogs.create(.init(
                weight: .init(value: weightValue, unit: weightUnit),
                measuredAtUTC: AppFormatting.apiDate.string(from: defaultMealTime),
                user: context
            ))
            weightChartRevision += 1
            await loadWeight()
        } catch { weightError = error }
        isLoggingWeight = false
    }

    private var waterHeadline: String {
        if let waterTotal { return volumeText(waterTotal.value, waterTotal.unit) }
        if isLoading || isLoadingWater { return "Loading water…" }
        return waterError == nil ? "No water logged" : "Water total unavailable"
    }

    private var weightHeadline: String {
        if let dayWeight { return weightText(dayWeight) }
        if isLoading { return "Loading weight…" }
        return weightError == nil ? "No weight logged" : "Weight unavailable"
    }

    private func unitTitle(_ unit: VolumeUnit) -> String {
        switch unit {
        case .fluidOunces: "fl oz"
        case .milliliters: "ml"
        case .cups: "cup"
        }
    }

    private func volumeText(_ value: Double, _ unit: VolumeUnit) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0...1)))) \(unitTitle(unit))"
    }

    private func weightText(_ weight: Weight) -> String {
        "\(weight.value.formatted(.number.precision(.fractionLength(0...1)))) \(weight.unit.rawValue)"
    }

    private func numberField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppPalette.muted)
            content()
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(AppPalette.control, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
