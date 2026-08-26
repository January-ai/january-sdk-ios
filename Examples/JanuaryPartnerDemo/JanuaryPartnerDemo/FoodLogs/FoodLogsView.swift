import JanuaryPartnerSDK
import SwiftUI

struct FoodLogsView: View {
    let client: JanuaryPartnerClient
    let settingsAction: () -> Void

    @Environment(UserSession.self) private var userSession
    @State private var selectedTimeSpan = FoodLogTimeSpan.currentWeek
    @State private var logs: [FoodLog] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenShell {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        WorkflowGuideCard(
                            title: "Build one complete meal",
                            message: "One food log represents one meal or eating event. It can contain multiple foods, each with its own serving and quantity.",
                            steps: [
                                "Identify the user who owns the log",
                                "Create a log and add every food in the meal",
                                "Save it, then browse that user’s history"
                            ],
                            symbol: "list.bullet.clipboard"
                        )

                        SectionLabel("User identity")
                        FoodLogUserCard(
                            userID: userID?.rawValue,
                            timezone: userSession.timezone,
                            onSave: { userSession.endUserID = $0 },
                            onSettings: settingsAction
                        )

                        if let context {
                            PrimaryButton(title: "Create a food log", systemImage: "plus") {
                                isCreating = true
                            }

                            SectionLabel("Browse saved logs")
                            Text("Food logs are fetched for the selected user ID and date range.")
                                .font(.system(size: 15))
                                .foregroundStyle(AppPalette.body)

                            FoodLogTimeSpanPicker(
                                selection: $selectedTimeSpan,
                                range: selectedDateRange,
                                calendar: foodLogCalendar
                            )

                            PrimaryButton(
                                title: "Refresh food logs",
                                isLoading: isLoading && logs.isEmpty,
                                isDisabled: isLoading
                            ) {
                                Task { await load() }
                            }

                            if isLoading, logs.isEmpty {
                                HStack(spacing: 12) {
                                    LoadingSpinner(color: AppPalette.green)
                                    Text("Loading food logs…")
                                        .font(.headline)
                                        .foregroundStyle(AppPalette.muted)
                                }
                                .padding()
                            }
                            if let error { ErrorNotice(error: error) { Task { await load() } } }

                            if !logs.isEmpty {
                                ForEach(logs, id: \.id) { log in
                                    NavigationLink {
                                        FoodLogDetailView(client: client, log: log, context: context) { Task { await load() } }
                                    } label: {
                                        FoodLogRow(log: log).appCard()
                                    }.buttonStyle(.plain)
                                }
                            } else if !isLoading, error == nil {
                                EmptyStateCard(
                                    title: "No food logs in this range",
                                    message: "Create a log, add one or more foods to the meal, then save it for this user.",
                                    symbol: "list.bullet.clipboard"
                                )
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom, 88)
            }
            .refreshable { await load() }
            .appBackground()
            .appNavigationBar("Food logs", style: .leading) {
                EmptyView()
            } trailing: {
                HStack(spacing: 8) {
                    if userID != nil {
                        AppNavigationButton(.add, title: "Add food log") { isCreating = true }
                    }
                    AppNavigationButton(.settings, action: settingsAction)
                }
            }
            .sheet(isPresented: $isCreating) {
                if let context {
                    FoodLogEditorView(client: client, context: context, existing: nil) {
                        isCreating = false
                        Task { await load() }
                    }
                }
            }
            .task(id: loadTaskID) {
                guard userID != nil else {
                    logs = []
                    error = nil
                    return
                }
                logs = []
                await load()
            }
        }
    }

    private var userID: PartnerUserID? { userSession.partnerUserID }
    private var context: PartnerUserContext? { userSession.partnerContext }
    private var foodLogCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(identifier: userSession.timezone) ?? .current
        calendar.firstWeekday = 1
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }
    private var selectedDateRange: FoodLogDateRange {
        selectedTimeSpan.dateRange(calendar: foodLogCalendar)
    }
    private var loadTaskID: String {
        "\(userSession.endUserID)|\(userSession.timezone)|\(selectedTimeSpan.rawValue)"
    }

    @MainActor private func load() async {
        guard let userClient = userSession.client(for: client) else { return }
        isLoading = true; error = nil
        do {
            let query = selectedDateRange.apiQuery(calendar: foodLogCalendar)
            logs = try await userClient.foodLogs.list(
                start: query.start,
                end: query.end
            ).items
        } catch { self.error = error }
        isLoading = false
    }
}

private struct FoodLogRow: View {
    let log: FoodLog
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "fork.knife.circle.fill").font(.largeTitle).foregroundStyle(AppPalette.green)
            VStack(alignment: .leading, spacing: 5) {
                Text(log.name?.isEmpty == false ? log.name! : "Meal").font(.headline)
                Text(log.foods.map(\.name).joined(separator: ", ")).lineLimit(2).foregroundStyle(AppPalette.body)
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
    let client: JanuaryPartnerClient
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

    init(client: JanuaryPartnerClient, context: FoodLogUserContext, existing: FoodLog?, onSaved: @escaping () -> Void) {
        self.client = client; self.context = context; self.existing = existing; self.onSaved = onSaved
        _name = State(initialValue: existing?.name ?? "")
        _timestamp = State(initialValue: existing.flatMap { AppFormatting.apiDate.date(from: $0.timestampUTC) } ?? .now)
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
                        } else {
                            ForEach($foods) { $item in
                                VStack(alignment: .leading, spacing: 14) {
                                    HStack(alignment: .top, spacing: 12) {
                                        Image(systemName: "fork.knife.circle.fill")
                                            .font(.title2)
                                            .foregroundStyle(AppPalette.green)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(item.food.name)
                                                .font(AppTypography.bodyStrong)
                                            if let brand = item.food.brandName, !brand.isEmpty {
                                                Text(brand)
                                                    .font(.subheadline)
                                                    .foregroundStyle(AppPalette.muted)
                                            }
                                        }
                                        Spacer(minLength: 8)
                                        Button("Remove \(item.food.name)", systemImage: "trash", role: .destructive) {
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
                                                Text("\(serving.quantity.formatted()) \(serving.unit)").tag(serving)
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

                        if let error { ErrorNotice(error: error) { Task { await save() } } }

                        PrimaryButton(
                            title: existing == nil ? "Save food log" : "Update food log",
                            isLoading: isSaving,
                            isDisabled: foods.isEmpty
                        ) {
                            Task { await save() }
                        }
                    }
                }
                .padding(.vertical, AppSpacing.sheetTop)
                .padding(.bottom, 88)
            }
            .appBackground()
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
    }

    @MainActor private func save() async {
        guard !foods.isEmpty else { return }
        isSaving = true; error = nil
        do {
            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if let existing {
                _ = try await client.foodLogs.update(.init(
                    id: existing.id,
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
    let client: JanuaryPartnerClient
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
                        Text(food.name).font(.headline)
                        if let brand = food.brandName { Text(brand).foregroundStyle(AppPalette.muted) }
                        Text("\(food.consumedServing.quantity.formatted()) × \(food.servingDetails.quantity.formatted()) \(food.servingDetails.unit)")
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
                DisclosureGroup("Technical details") { LabeledContent("Log ID", value: log.id) }.font(.footnote)
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
                    Spacer(minLength: 0)
                }
                if let error { ErrorNotice(error: error) { Task { await delete() } } }
                }
            }
            .padding(.vertical, 16)
        }
        .appBackground()
        .appNavigationBar("Food log") {
            EmptyView()
        } trailing: {
            AppNavigationButton(.edit) { isEditing = true }
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
        do { _ = try await client.foodLogs.delete(.init(id: log.id, user: context)); onChanged(); dismiss() }
        catch { self.error = error }
        isDeleting = false
    }
}

struct FoodPickerView: View {
    let client: JanuaryPartnerClient
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
                            SearchField(prompt: "Search foods", text: queryBinding) {
                                Task { await search() }
                            }

                            if !suggestions.isEmpty {
                                FoodSuggestionList(items: suggestions) { suggestion in
                                    autocompleteSuppressedQuery = suggestion.name
                                    query = suggestion.name
                                    suggestions = []
                                    Task { await search() }
                                }
                            }

                            if let error {
                                ErrorNotice(error: error) {
                                    Task {
                                        if let failedFoodID {
                                            await hydrate(failedFoodID)
                                        } else {
                                            await search()
                                        }
                                    }
                                }
                            } else if suggestions.isEmpty && results.isEmpty && !isLoading {
                                EmptyStateCard(
                                    title: "Find a food",
                                    message: "Start typing for suggestions, or search January’s food database.",
                                    symbol: "fork.knife"
                                )
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
            .appNavigationBar("Add food") {
                AppNavigationButton(.close, title: "Close add food") { dismiss() }
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
            chosenFood = try await client.foods.getFood(.init(foodID: foodID, endUserID: endUserID))
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
            try await Task.sleep(for: .milliseconds(300))
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
        _serving = State(initialValue: food.servings.first(where: \.isPrimary) ?? food.servings.first ?? .init(id: .init(rawValue: 0), quantity: 1, unit: "serving", scalingFactor: 1, isPrimary: true))
    }

    var body: some View {
        NavigationStack {
            ScreenShell {
                VStack(alignment: .leading, spacing: 14) {
                            Text(food.name)
                                .font(AppTypography.sheetTitle)
                                .foregroundStyle(AppPalette.ink)

                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Text("Serving")
                                        .font(AppTypography.bodyStrong)
                                    Spacer(minLength: 8)
                                    Picker("Serving", selection: $serving) {
                                        ForEach(food.servings, id: \.id) {
                                            Text("\($0.quantity.formatted()) \($0.unit)").tag($0)
                                        }
                                    }
                                    .labelsHidden()
                                    .tint(AppPalette.goldText)
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
                }
            }
            .padding(.top, AppSpacing.sheetTop)
            .padding(.bottom, 12)
            .appBackground()
            .appNavigationBar("Choose serving") {
                AppNavigationButton(.close, title: "Close serving picker") { dismiss() }
            } trailing: {
                EmptyView()
            }
        }
        .presentationDetents([.height(400)])
        .presentationCornerRadius(18)
        .presentationDragIndicator(.visible)
    }

    private var nutritionScale: Double {
        let baseQuantity = serving.quantity == 0 ? 1 : serving.quantity
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
        id: logged.id,
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
    return .init(food: food, serving: serving, quantity: logged.consumedServing.quantity)
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
