import January
import SwiftUI

/// One day of the selected user's logs: food logs with the day's nutrient totals, the day's
/// water total, and the day's weight, each logged through its SDK resource.
struct FoodLogsView: View {
    let client: JanuaryClient
    let settingsAction: () -> Void

    @EnvironmentObject private var userSession: UserSession
    @State private var day = Date.now
    @State private var logs: [FoodLog] = []
    @State private var summary: FoodLogSummary?
    @State private var isLoading = false
    @State private var error: Error?
    @State private var isCreating = false

    @State private var waterValue = 8.0
    @State private var waterUnit = VolumeUnit.fluidOunces
    @State private var waterTotal: Volume?
    @State private var lastWaterLog: WaterLog?
    @State private var waterError: Error?
    @State private var isLoggingWater = false

    @State private var weightValue = 150.0
    @State private var weightUnit = WeightUnit.pounds
    @State private var dayWeight: Weight?
    @State private var weightError: Error?
    @State private var isLoggingWeight = false

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenShell {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        WorkflowGuideCard(
                            title: "One day at a time",
                            message: "Each day gathers the user’s meals with their nutrient totals, the water they drank, and their latest weight. A food log is one meal with one or more foods.",
                            steps: [
                                "Identify the user who owns the logs",
                                "Pick a day, then log meals, water, or a weight",
                                "Review the day’s totals"
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

                            PrimaryButton(title: "Create a food log", systemImage: "plus") {
                                isCreating = true
                            }
                            .accessibilityIdentifier("food-log-create")

                            SectionLabel("Water")
                            waterCard
                            SectionLabel("Weight")
                            weightCard

                            SectionLabel("Meals")
                            PrimaryButton(
                                title: "Refresh this day",
                                isLoading: isLoading && logs.isEmpty,
                                isDisabled: isLoading
                            ) {
                                Task { await load() }
                            }
                            .accessibilityIdentifier("food-logs-refresh")

                            if isLoading, logs.isEmpty {
                                HStack(spacing: 12) {
                                    LoadingSpinner(color: AppPalette.green)
                                    Text("Loading food logs…")
                                        .font(.headline)
                                        .foregroundStyle(AppPalette.muted)
                                }
                                .padding()
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("food-logs-loading")
                            }
                            if let error {
                                ErrorNotice(
                                    error: error,
                                    retry: { Task { await load() } },
                                    identifier: "food-logs-error",
                                    retryIdentifier: "food-logs-retry"
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
                                        FoodLogDetailView(client: client, log: log, context: context) { Task { await load() } }
                                    } label: {
                                        FoodLogRow(log: log).appCard()
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("food-log-\(index)")
                                }
                            } else if !isLoading, error == nil {
                                EmptyStateCard(
                                    title: "No food logs on this day",
                                    message: "Create a log, add one or more foods to the meal, then save it for this user.",
                                    symbol: "list.bullet.clipboard"
                                )
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("food-logs-empty")
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom, 88)
            }
            .refreshable { await load() }
            .appBackground()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("food-logs-screen")
            .appNavigationBar("Logs", style: .leading) {
                EmptyView()
            } trailing: {
                HStack(spacing: 8) {
                    if userID != nil {
                        AppNavigationButton(.add, title: "Add food log") { isCreating = true }
                            .accessibilityIdentifier("food-log-add")
                    }
                    AppNavigationButton(.settings, action: settingsAction)
                        .accessibilityIdentifier("settings-button")
                }
            }
            .sheet(isPresented: $isCreating) {
                if let context {
                    FoodLogEditorView(client: client, context: context, existing: nil, defaultTimestamp: defaultMealTime) {
                        isCreating = false
                        Task { await load() }
                    }
                }
            }
            .task(id: loadTaskID) {
                guard userID != nil else {
                    logs = []; summary = nil; waterTotal = nil; dayWeight = nil
                    error = nil; waterError = nil; weightError = nil
                    return
                }
                logs = []; summary = nil
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

    private var waterCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(waterTotal.map { volumeText($0.value, $0.unit) } ?? "No water logged")
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
                    .frame(maxWidth: 150)
                    .accessibilityLabel("Water units")
            }
            if let waterError {
                ErrorNotice(
                    error: waterError,
                    retry: { Task { await load() } },
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
                if lastWaterLog != nil {
                    Button("Delete last", role: .destructive) { Task { await deleteLastWater() } }
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(AppPalette.rustText)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 56)
                        .background(AppPalette.rustBackground, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                        .accessibilityIdentifier("water-log-delete")
                }
            }
        }
        .appCard()
    }

    private var weightCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(dayWeight.map(weightText) ?? "No weight logged")
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
            }
            if let weightError {
                ErrorNotice(
                    error: weightError,
                    retry: { Task { await load() } },
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
        "\(userSession.endUserID)|\(userSession.timezone)|\(dayQuery)|\(waterUnit.rawValue)"
    }

    private func shiftDay(by days: Int) {
        guard let next = calendar.date(byAdding: .day, value: days, to: day) else { return }
        day = min(next, .now)
    }

    @MainActor private func load() async {
        guard let context else { return }
        isLoading = true; error = nil
        let start = dayQuery, end = dayQuery
        do {
            logs = try await client.foodLogs.list(.init(start: start, end: end, user: context)).items
            summary = try await client.foodLogs.getSummary(.init(start: start, end: end, user: context))
        } catch { self.error = error }
        do {
            waterTotal = try await client.waterLogs.list(.init(start: start, end: end, unit: waterUnit, user: context)).items.first?.total
            waterError = nil
        } catch { waterError = error }
        do {
            dayWeight = try await client.weightLogs.list(.init(start: start, end: end, user: context)).items.first?.weight
            weightError = nil
        } catch { weightError = error }
        isLoading = false
    }

    @MainActor private func logWater() async {
        guard let context else { return }
        isLoggingWater = true; waterError = nil
        do {
            lastWaterLog = try await client.waterLogs.create(.init(
                amount: .init(value: waterValue, unit: waterUnit),
                consumedAtUTC: AppFormatting.apiDate.string(from: defaultMealTime),
                user: context
            ))
            await load()
        } catch { waterError = error }
        isLoggingWater = false
    }

    @MainActor private func deleteLastWater() async {
        guard let context, let lastWaterLog else { return }
        waterError = nil
        do {
            try await client.waterLogs.delete(.init(id: lastWaterLog.id, user: context))
            self.lastWaterLog = nil
            await load()
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
            await load()
        } catch { weightError = error }
        isLoggingWeight = false
    }

    private func unitTitle(_ unit: VolumeUnit) -> String {
        switch unit {
        case .fluidOunces: "fl oz"
        case .milliliters: "ml"
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

private struct FoodLogRow: View {
    let log: FoodLog
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "fork.knife.circle.fill").font(.largeTitle).foregroundStyle(AppPalette.green)
            VStack(alignment: .leading, spacing: 5) {
                Text(log.name?.isEmpty == false ? log.name! : "Meal").font(.headline)
                Text(log.foods.map { $0.name ?? "Unnamed food" }.joined(separator: ", ")).lineLimit(2).foregroundStyle(AppPalette.body)
                HStack {
                    Text(localDate(log.timestampUTC))
                    Text("· \(log.foods.count) food\(log.foods.count == 1 ? "" : "s")")
                }.font(.caption).foregroundStyle(AppPalette.muted)
            }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
    }
}

private struct FoodLogEditorView: View {
    let client: JanuaryClient
    let context: FoodLogUserContext
    let existing: FoodLog?
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var timestamp: Date
    @State private var foods: [SelectedFood]
    @State private var isShowingFoodPicker = false
    @State private var isSaving = false
    @State private var error: Error?

    init(client: JanuaryClient, context: FoodLogUserContext, existing: FoodLog?, defaultTimestamp: Date = .now, onSaved: @escaping () -> Void) {
        self.client = client; self.context = context; self.existing = existing; self.onSaved = onSaved
        _name = State(initialValue: existing?.name ?? "")
        _timestamp = State(initialValue: existing.flatMap { AppFormatting.apiDate.date(from: $0.timestampUTC) } ?? defaultTimestamp)
        _foods = State(initialValue: existing?.foods.map(selectedFood) ?? [])
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenShell {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.section) {
                        WorkflowGuideCard(
                            title: existing == nil ? "Build this meal" : "Update this meal",
                            message: "A log is one meal. Add every food that belongs to it, then choose each serving and quantity before saving.",
                            steps: [
                                "Set the meal time",
                                "Add one or more foods",
                                "Review servings and save"
                            ],
                            symbol: "fork.knife"
                        )

                        SectionLabel("Meal details")
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Meal name")
                                .font(AppTypography.bodyStrong)
                            TextField("Optional name", text: $name)
                                .font(AppTypography.body)
                                .padding(.horizontal, AppSpacing.controlHorizontal)
                                .frame(minHeight: 54)
                                .background(
                                    AppPalette.control,
                                    in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                )
                                .accessibilityIdentifier("food-log-name")
                        }

                        HStack(spacing: 12) {
                            Text("Date and time")
                                .font(AppTypography.bodyStrong)
                            Spacer(minLength: 12)
                            DatePicker("Date and time", selection: $timestamp)
                                .labelsHidden()
                        }
                        .appCard()

                        SectionLabel("Foods in this meal · \(foods.count)")
                        if foods.isEmpty {
                            EmptyStateCard(
                                title: "No foods added",
                                message: "Start with one food, then keep adding until the complete meal is represented.",
                                symbol: "plus.circle"
                            )
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("food-log-editor-empty")
                        } else {
                            ForEach($foods) { $item in
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "fork.knife.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(AppPalette.green)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.food.name ?? "Unnamed food")
                                                .font(AppTypography.bodyStrong)
                                            if let brand = item.food.brandName, !brand.isEmpty {
                                                Text(brand)
                                                    .font(.subheadline)
                                                    .foregroundStyle(AppPalette.muted)
                                            }
                                        }
                                        Spacer(minLength: 8)
                                        Button("Remove \(item.food.name ?? "food")", systemImage: "trash", role: .destructive) {
                                            foods.removeAll { $0.id == item.id }
                                        }
                                        .labelStyle(.iconOnly)
                                    }

                                    Divider().overlay(AppPalette.divider)

                                    HStack(spacing: 12) {
                                        Text("Serving")
                                            .font(AppTypography.bodyStrong)
                                        Spacer(minLength: 12)
                                        Picker("Serving", selection: $item.serving) {
                                            ForEach(item.food.servings, id: \.id) { serving in
                                                Text("\((serving.quantity ?? 1).formatted()) \(serving.unit ?? "serving")").tag(serving)
                                            }
                                        }
                                        .labelsHidden()
                                        .tint(AppPalette.green)
                                    }

                                    Divider().overlay(AppPalette.divider)

                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Quantity")
                                                .font(AppTypography.bodyStrong)
                                            Text(item.quantity.formatted(.number.precision(.fractionLength(0...2))))
                                                .font(.subheadline.monospacedDigit())
                                                .foregroundStyle(AppPalette.muted)
                                        }
                                        Spacer(minLength: 12)
                                        Stepper("Quantity", value: $item.quantity, in: 0.25...10_000, step: 0.25)
                                            .labelsHidden()
                                    }
                                }
                                .appCard()
                            }
                        }

                        Button(foods.isEmpty ? "Add first food" : "Add another food", systemImage: "plus") {
                            isShowingFoodPicker = true
                        }
                            .buttonStyle(OutlinedButtonStyle())
                            .accessibilityIdentifier("food-log-add-food")

                        if let error {
                            ErrorNotice(
                                error: error,
                                retry: { Task { await save() } },
                                identifier: "food-log-save-error",
                                retryIdentifier: "food-log-save-retry"
                            )
                        }

                        PrimaryButton(
                            title: existing == nil ? "Save food log" : "Update food log",
                            isLoading: isSaving,
                            isDisabled: foods.isEmpty
                        ) {
                            Task { await save() }
                        }
                        .accessibilityIdentifier(isSaving ? "food-log-save-loading" : "food-log-save")
                    }
                }
                .padding(.vertical, AppSpacing.sheetTop)
                .padding(.bottom, 88)
            }
            .appBackground()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("food-log-editor")
            .appNavigationBar(existing == nil ? "New food log" : "Edit food log") {
                AppNavigationButton(.close, title: existing == nil ? "Close new food log" : "Close food log editor") { dismiss() }
            } trailing: {
                EmptyView()
            }
            .sheet(isPresented: $isShowingFoodPicker) {
                FoodPickerView(client: client, endUserID: context.endUserID) { food in foods.append(food); isShowingFoodPicker = false }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    @MainActor private func save() async {
        guard !foods.isEmpty else { return }
        isSaving = true; error = nil
        do {
            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing {
                _ = try await client.foodLogs.update(.init(
                    id: existing.id ?? "",
                    foods: foods.map(\.selection),
                    timestampUTC: AppFormatting.apiDate.string(from: timestamp),
                    name: normalizedName.isEmpty ? nil : normalizedName,
                    user: context
                ))
            } else {
                _ = try await client.foodLogs.create(.init(
                    foods: foods.map(\.selection),
                    timestampUTC: AppFormatting.apiDate.string(from: timestamp),
                    name: normalizedName.isEmpty ? nil : normalizedName,
                    user: context
                ))
            }
            onSaved()
        } catch { self.error = error }
        isSaving = false
    }
}

private struct FoodLogDetailView: View {
    let client: JanuaryClient
    let log: FoodLog
    let context: FoodLogUserContext
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var error: Error?
    @State private var isDeleting = false

    var body: some View {
        ScrollView {
            ScreenShell {
                VStack(alignment: .leading, spacing: 18) {
                Text(log.name?.isEmpty == false ? log.name! : "Meal").font(.system(.largeTitle, design: .serif, weight: .bold))
                Text(localDate(log.timestampUTC)).foregroundStyle(AppPalette.muted)
                ForEach(log.foods, id: \.id) { food in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(food.name ?? "Unnamed food").font(.headline)
                        if let brand = food.brandName { Text(brand).foregroundStyle(AppPalette.muted) }
                        Text("\((food.consumedServing.quantity ?? 1).formatted()) × \((food.servingDetails.quantity ?? 1).formatted()) \(food.servingDetails.unit ?? "serving")")
                            .font(.subheadline)
                        MacroGrid(
                            calories: food.nutrients.calories?.value,
                            protein: food.nutrients.protein?.value,
                            carbohydrates: food.nutrients.carbohydrates?.value,
                            fat: food.nutrients.totalFat?.value
                        )
                        NutritionList(rows: nutritionRows(food.nutrients))
                    }.appCard()
                }
                DisclosureGroup("Technical details") { LabeledContent("Log ID", value: log.id ?? "Unavailable") }.font(.footnote)
                HStack {
                    Spacer(minLength: 0)
                    Button("Delete food log", role: .destructive) { isConfirmingDelete = true }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppPalette.rustText)
                        .padding(.horizontal, 18)
                        .frame(minHeight: 48)
                        .background(AppPalette.rustBackground, in: RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: AppRadius.control, style: .continuous)
                                .stroke(AppPalette.rust.opacity(0.35), lineWidth: 1.5)
                        }
                        .accessibilityIdentifier("food-log-delete")
                    Spacer(minLength: 0)
                }
                if let error {
                    // A failed deletion is reported here, on the detail screen; the RN example
                    // reports it on the list, so the same IDs are used for the same recovery step.
                    ErrorNotice(
                        error: error,
                        retry: { Task { await delete() } },
                        identifier: "food-logs-error",
                        retryIdentifier: "food-logs-retry"
                    )
                }
                }
            }
            .padding(.vertical, 16)
        }
        .appBackground()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("food-log-detail")
        .appNavigationBar("Food log") {
            EmptyView()
        } trailing: {
            AppNavigationButton(.edit) { isEditing = true }
                .accessibilityIdentifier("food-log-edit")
        }
        .sheet(isPresented: $isEditing) {
            FoodLogEditorView(client: client, context: context, existing: log) { isEditing = false; onChanged(); dismiss() }
        }
        .confirmationDialog("Delete this food log?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("Delete food log", role: .destructive) { Task { await delete() } }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This action can’t be undone.") }
    }

    @MainActor private func delete() async {
        isDeleting = true; error = nil
        do { _ = try await client.foodLogs.delete(.init(id: log.id ?? "", user: context)); onChanged(); dismiss() }
        catch { self.error = error }
        isDeleting = false
    }
}

struct FoodPickerView: View {
    let client: JanuaryClient
    let endUserID: PartnerUserID?
    let onSelect: (SelectedFood) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var suggestions: [FoodSuggestion] = []
    @State private var autocompleteSuppressedQuery: String?
    @State private var results: [FoodSearchItem] = []
    @State private var chosenFood: FoodSearchItem?
    @State private var hydratingFoodID: FoodID?
    @State private var failedFoodID: FoodID?
    @State private var isLoading = false
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenShell {
                    VStack(alignment: .leading, spacing: 16) {
                            SearchField(
                                prompt: "Search foods",
                                text: queryBinding,
                                identifier: "food-picker-input",
                                voiceIdentifier: "food-picker-voice"
                            ) {
                                Task { await search() }
                            }

                            if !suggestions.isEmpty {
                                FoodSuggestionList(
                                    items: suggestions,
                                    identifier: "food-picker-suggestions",
                                    itemIdentifier: { "food-picker-suggestion-\($0)" }
                                ) { suggestion in
                                    guard let suggestionName = suggestion.name else { return }
                                    autocompleteSuppressedQuery = suggestionName
                                    query = suggestionName
                                    suggestions = []
                                    Task { await search() }
                                }
                            }

                            if let error {
                                ErrorNotice(
                                    error: error,
                                    retry: {
                                        Task {
                                            if let failedFoodID {
                                                await hydrate(failedFoodID)
                                            } else {
                                                await search()
                                            }
                                        }
                                    },
                                    identifier: "food-picker-error",
                                    retryIdentifier: "food-picker-retry"
                                )
                            } else if suggestions.isEmpty && results.isEmpty && !isLoading {
                                EmptyStateCard(
                                    title: "Find a food",
                                    message: "Start typing for suggestions, or search January’s food database.",
                                    symbol: "fork.knife"
                                )
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("food-picker-empty")
                            } else if !results.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    SectionLabel("Results · January food database")
                                    VStack(spacing: 0) {
                                        ForEach(Array(results.enumerated()), id: \.element.id) { index, food in
                                            Button { Task { await choose(food) } } label: {
                                                FoodRow(food: food, isLoading: hydratingFoodID == food.id)
                                                    .padding(.vertical, 12)
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(hydratingFoodID != nil)
                                            .accessibilityIdentifier("food-picker-result-\(index)")
                                            if index < results.count - 1 { Divider().overlay(AppPalette.divider) }
                                        }
                                    }
                                    .appCard()
                                    HStack {
                                        Spacer(minLength: 0)
                                        Text("Photos load from January’s food database.")
                                            .font(.system(size: 14))
                                            .foregroundStyle(AppPalette.muted)
                                            .multilineTextAlignment(.center)
                                        Spacer(minLength: 0)
                                    }
                                }
                            }
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom, 32)
            }
            .appBackground()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("food-picker")
            .appNavigationBar("Add food") {
                AppNavigationButton(.close, title: "Close add food") { dismiss() }
                    .accessibilityIdentifier("food-picker-close")
            } trailing: {
                EmptyView()
            }
            .sheet(isPresented: Binding(
                get: { chosenFood != nil },
                set: { if !$0 { chosenFood = nil } }
            )) {
                if let chosenFood { ServingSelectionSheet(food: chosenFood, onSelect: onSelect) }
            }
            .task(id: query) {
                await loadAutocomplete()
            }
        }
        .presentationDragIndicator(.hidden)
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { query },
            set: { value in
                query = value
                if value != autocompleteSuppressedQuery {
                    autocompleteSuppressedQuery = nil
                    results = []
                    error = nil
                }
                if value.isEmpty {
                    suggestions = []
                }
            }
        )
    }

    @MainActor private func search() async {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines); guard !value.isEmpty else { return }
        autocompleteSuppressedQuery = value
        suggestions = []
        isLoading = true; error = nil; failedFoodID = nil
        do { results = try await client.foods.search(.init(query: value, endUserID: endUserID)).items }
        catch { self.error = error }
        isLoading = false
    }

    @MainActor private func choose(_ food: FoodSearchItem) async {
        await hydrate(food.id)
    }

    @MainActor private func hydrate(_ foodID: FoodID) async {
        guard hydratingFoodID == nil else { return }
        hydratingFoodID = foodID
        error = nil
        failedFoodID = nil
        do {
            chosenFood = try await client.foods.get(id: foodID, endUserID: endUserID)
        } catch {
            self.error = error
            failedFoodID = foodID
        }
        hydratingFoodID = nil
    }

    @MainActor private func loadAutocomplete() async {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.count >= 2,
              value.count <= 64,
              value != autocompleteSuppressedQuery else {
            suggestions = []
            return
        }

        do {
            try await Task.sleep(nanoseconds: 300_000_000)
            try Task.checkCancellation()
            let response = try await client.foods.autocomplete(
                .init(query: value, limit: 8, endUserID: endUserID)
            )
            try Task.checkCancellation()
            guard query.trimmingCharacters(in: .whitespacesAndNewlines) == value else { return }
            suggestions = response.items
        } catch is CancellationError {
            return
        } catch {
            suggestions = []
        }
    }
}

private struct ServingSelectionSheet: View {
    let food: FoodSearchItem
    let onSelect: (SelectedFood) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var serving: ServingOption
    @State private var quantity = 1.0

    init(food: FoodSearchItem, onSelect: @escaping (SelectedFood) -> Void) {
        self.food = food; self.onSelect = onSelect
        _serving = State(initialValue: food.servings.first(where: { $0.isPrimary == true }) ?? food.servings.first ?? .init(id: .init(rawValue: "0"), quantity: 1, unit: "serving", scalingFactor: 1, isPrimary: true))
    }

    var body: some View {
        NavigationStack {
            ScreenShell {
                VStack(alignment: .leading, spacing: 14) {
                            Text(food.name ?? "Unnamed food")
                                .font(AppTypography.sheetTitle)
                                .foregroundStyle(AppPalette.ink)

                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Text("Serving")
                                        .font(AppTypography.bodyStrong)
                                    Spacer(minLength: 8)
                                    Picker("Serving", selection: $serving) {
                                        ForEach(Array(food.servings.enumerated()), id: \.element.id) { index, option in
                                            Text("\((option.quantity ?? 1).formatted()) \(option.unit ?? "serving")")
                                                .tag(option)
                                                .accessibilityIdentifier("food-serving-option-\(index)")
                                        }
                                    }
                                    .labelsHidden()
                                    .tint(AppPalette.goldText)
                                    .accessibilityIdentifier("food-serving-unit")
                                }
                                .padding(.horizontal, 22)
                                .padding(.vertical, 11)

                                Divider().overlay(AppPalette.border)

                                HStack(spacing: 12) {
                                    Text("Quantity")
                                        .font(AppTypography.bodyStrong)
                                    Spacer(minLength: 8)
                                    Button("Decrease quantity", systemImage: "minus") {
                                        quantity = max(0.25, quantity - 0.25)
                                    }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(QuantityButtonStyle())
                                    Text(quantity.formatted(.number.precision(.fractionLength(0...2))))
                                        .font(.system(size: 26, weight: .semibold, design: .monospaced))
                                        .monospacedDigit()
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.8)
                                        .frame(width: 64)
                                    Button("Increase quantity", systemImage: "plus") {
                                        quantity += 0.25
                                    }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(QuantityButtonStyle(isPrimary: true))
                                }
                                .padding(.horizontal, 22)
                                .padding(.vertical, 10)
                            }
                            .background(AppPalette.paper, in: RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: AppRadius.card, style: .continuous)
                                    .stroke(AppPalette.border, lineWidth: 1.5)
                            }
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("food-serving-controls")

                            LazyVGrid(
                                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                                spacing: 8
                            ) {
                                servingMetric("Calories", scaled(food.calories), "cal")
                                servingMetric("Carbs", scaled(food.carbohydrates), "g")
                                servingMetric("Protein", scaled(food.protein), "g")
                                servingMetric("Fat", scaled(food.totalFat), "g")
                            }

                            PrimaryButton(title: "Add to meal") {
                                onSelect(.init(food: food, serving: serving, quantity: quantity))
                                dismiss()
                            }
                            .accessibilityIdentifier("food-serving-add")
                }
            }
            .padding(.top, AppSpacing.sheetTop)
            .padding(.bottom, 12)
            .appBackground()
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("food-serving-sheet")
            .appNavigationBar("Choose serving") {
                AppNavigationButton(.close, title: "Close serving picker") { dismiss() }
            } trailing: {
                EmptyView()
            }
        }
        .presentationDetents([.height(400)])
        .presentationCornerRadius(18)
        .presentationDragIndicator(.hidden)
    }

    private var nutritionScale: Double {
        let baseQuantity = (serving.quantity ?? 1) == 0 ? 1 : (serving.quantity ?? 1)
        return quantity * serving.scalingFactor / baseQuantity
    }

    private func scaled(_ value: Double?) -> Double? {
        value.map { $0 * nutritionScale }
    }

    private func servingMetric(_ label: String, _ value: Double?, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .tracking(0.7)
                .foregroundStyle(AppPalette.muted)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value?.formatted(.number.precision(.fractionLength(0...1))) ?? "—")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppPalette.muted)
            }
        }
    }
}

private func selectedFood(_ logged: LoggedFood) -> SelectedFood {
    let serving = ServingOption(
        id: logged.servingDetails.id,
        quantity: logged.servingDetails.quantity,
        unit: logged.servingDetails.unit,
        scalingFactor: 1,
        weightGrams: logged.servingDetails.weightGrams,
        isPrimary: true
    )
    let food = FoodSearchItem(
        id: logged.id ?? .init(rawValue: "missing-food-id"),
        name: logged.name,
        brandName: logged.brandName,
        calories: logged.nutrients.calories?.value,
        protein: logged.nutrients.protein?.value,
        carbohydrates: logged.nutrients.carbohydrates?.value,
        netCarbohydrates: logged.nutrients.netCarbohydrates?.value,
        totalFat: logged.nutrients.totalFat?.value,
        saturatedFat: logged.nutrients.saturatedFat?.value,
        fiber: logged.nutrients.fiber?.value,
        totalSugars: logged.nutrients.totalSugars?.value,
        addedSugars: logged.nutrients.addedSugars?.value,
        sodium: logged.nutrients.sodium?.value,
        potassium: logged.nutrients.potassium?.value,
        cholesterol: logged.nutrients.cholesterol?.value,
        glycemicIndex: logged.glycemicIndex,
        glycemicLoad: logged.glycemicLoad,
        photoURL: logged.imageURL,
        servings: [serving]
    )
    return .init(food: food, serving: serving, quantity: logged.consumedServing.quantity ?? 1)
}

private func nutritionRows(_ value: NutritionFacts) -> [NutrientRow] {
    [
        value.netCarbohydrates.map { .init(name: "Net carbohydrates", value: $0.value, unit: $0.unit) },
        value.transFat.map { .init(name: "Trans fat", value: $0.value, unit: $0.unit) },
        value.saturatedFat.map { .init(name: "Saturated fat", value: $0.value, unit: $0.unit) },
        value.fiber.map { .init(name: "Fiber", value: $0.value, unit: $0.unit) },
        value.totalSugars.map { .init(name: "Total sugars", value: $0.value, unit: $0.unit) },
        value.addedSugars.map { .init(name: "Added sugars", value: $0.value, unit: $0.unit) },
        value.cholesterol.map { .init(name: "Cholesterol", value: $0.value, unit: $0.unit) },
        value.calcium.map { .init(name: "Calcium", value: $0.value, unit: $0.unit) },
        value.iron.map { .init(name: "Iron", value: $0.value, unit: $0.unit) },
        value.potassium.map { .init(name: "Potassium", value: $0.value, unit: $0.unit) },
        value.sodium.map { .init(name: "Sodium", value: $0.value, unit: $0.unit) },
        value.vitaminD.map { .init(name: "Vitamin D", value: $0.value, unit: $0.unit) },
    ].compactMap { $0 }
}

private func localDate(_ value: String) -> String {
    guard let date = AppFormatting.apiDate.date(from: value) else { return value }
    return date.formatted(date: .abbreviated, time: .shortened)
}
