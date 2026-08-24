import JanuaryPartnerSDK
import SwiftUI

struct FoodLogsView: View {
    let client: JanuaryPartnerClient
    let settingsAction: () -> Void

    @AppStorage("demo.endUserID") private var endUserID = ""
    @AppStorage("demo.timezone") private var timezone = TimeZone.current.identifier
    @State private var startDate = Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now
    @State private var endDate = Date.now
    @State private var logs: [FoodLog] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                DemoScreenShell {
                    LazyVStack(alignment: .leading, spacing: 16) {
                    Text("Food logs")
                        .font(DemoTypography.screenTitle)
                        .foregroundStyle(DemoPalette.ink)

                    if userID == nil {
                        VStack(alignment: .leading, spacing: 10) {
                            DemoSectionLabel("One thing first", color: DemoPalette.goldText)
                                .padding(.horizontal, 0)
                            Text("Logs are stored per person. Add the partner’s stable user ID before loading or creating logs.")
                                .font(DemoTypography.body)
                                .foregroundStyle(DemoPalette.ink)
                            Button("Open settings", action: settingsAction)
                                .buttonStyle(DemoPrimaryButtonStyle())
                        }
                        .padding(DemoSpacing.card)
                        .background(DemoPalette.goldBackground, in: RoundedRectangle(cornerRadius: DemoRadius.feature, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: DemoRadius.feature, style: .continuous)
                                .stroke(Color(red: 217 / 255, green: 194 / 255, blue: 95 / 255), lineWidth: 1.5)
                        }
                    }

                    DemoSectionLabel("Date range")
                    VStack(spacing: 0) {
                        HStack {
                            Text("From").font(DemoTypography.bodyStrong)
                            Spacer(minLength: 12)
                            DatePicker("From", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        }
                        .padding(.vertical, DemoSpacing.rowVertical)
                        Divider().overlay(DemoPalette.divider)
                        HStack {
                            Text("To").font(DemoTypography.bodyStrong)
                            Spacer(minLength: 12)
                            DatePicker("To", selection: $endDate, in: startDate..., displayedComponents: .date)
                                .labelsHidden()
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        }
                        .padding(.vertical, DemoSpacing.rowVertical)
                    }
                    .demoCard()

                    Button("Load logs") { Task { await load() } }
                        .buttonStyle(DemoPrimaryButtonStyle())
                        .disabled(userID == nil || isLoading)

                    if userID == nil {
                        DemoFillWidth {
                            HStack {
                                Spacer(minLength: 0)
                                Text("Available once a user ID is set.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(DemoPalette.muted)
                                    .multilineTextAlignment(.center)
                                Spacer(minLength: 0)
                            }
                        }
                    }

                    if isLoading {
                        HStack {
                            Spacer(minLength: 0)
                            ProgressView("Loading food logs…")
                            Spacer(minLength: 0)
                        }
                        .padding()
                    }
                    if let error { DemoErrorNotice(error: error) { Task { await load() } } }

                    if let context, !logs.isEmpty {
                        ForEach(logs, id: \.id) { log in
                            NavigationLink {
                                FoodLogDetailView(client: client, log: log, context: context) { Task { await load() } }
                            } label: {
                                FoodLogRow(log: log).demoCard()
                            }.buttonStyle(.plain)
                        }
                    } else if !isLoading, error == nil, userID != nil {
                        ContentUnavailableView("No food logs", systemImage: "list.bullet.clipboard", description: Text("There are no logs in this date range."))
                    }
                    }
                }
                .padding(.vertical, 16)
            }
            .refreshable { await load() }
            .demoBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if userID != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Add food log", systemImage: "plus") { isCreating = true }
                    }
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
            .task { if userID != nil { await load() } }
        }
    }

    private var userID: PartnerUserID? { DemoFormatting.endUserID(endUserID) }
    private var context: FoodLogUserContext? { userID.map { .init(endUserID: $0, timezone: timezone) } }

    @MainActor private func load() async {
        guard let context else { return }
        isLoading = true; error = nil
        do {
            logs = try await client.foodLogs.list(.init(
                start: DemoFormatting.apiDay.string(from: startDate),
                end: DemoFormatting.apiDay.string(from: endDate),
                user: context
            )).items
        } catch { self.error = error }
        isLoading = false
    }
}

private struct FoodLogRow: View {
    let log: FoodLog
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "fork.knife.circle.fill").font(.largeTitle).foregroundStyle(DemoPalette.green)
            VStack(alignment: .leading, spacing: 5) {
                Text(log.name?.isEmpty == false ? log.name! : "Meal").font(.headline)
                Text(log.foods.map(\.name).joined(separator: ", ")).lineLimit(2).foregroundStyle(DemoPalette.body)
                HStack {
                    Text(localDate(log.timestampUTC))
                    Text("· \(log.foods.count) food\(log.foods.count == 1 ? "" : "s")")
                }.font(.caption).foregroundStyle(DemoPalette.muted)
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
    @State private var foods: [DemoSelectedFood]
    @State private var isShowingFoodPicker = false
    @State private var isSaving = false
    @State private var error: Error?

    init(client: JanuaryPartnerClient, context: FoodLogUserContext, existing: FoodLog?, onSaved: @escaping () -> Void) {
        self.client = client; self.context = context; self.existing = existing; self.onSaved = onSaved
        _name = State(initialValue: existing?.name ?? "")
        _timestamp = State(initialValue: existing.flatMap { DemoFormatting.apiDate.date(from: $0.timestampUTC) } ?? .now)
        _foods = State(initialValue: existing?.foods.map(selectedFood) ?? [])
    }

    var body: some View {
        NavigationStack {
            DemoScreenShell {
                Form {
                Section("Meal") {
                    TextField("Name (optional)", text: $name)
                    DatePicker("Date and time", selection: $timestamp)
                }
                Section("Foods") {
                    ForEach($foods) { $item in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.food.name).font(.headline)
                            Picker("Serving", selection: $item.serving) {
                                ForEach(item.food.servings, id: \.id) { serving in Text("\(serving.quantity.formatted()) \(serving.unit)").tag(serving) }
                            }
                            Stepper("Quantity: \(item.quantity.formatted(.number.precision(.fractionLength(0...2))))", value: $item.quantity, in: 0.25...10_000, step: 0.25)
                        }
                    }.onDelete { foods.remove(atOffsets: $0) }
                    Button("Add food", systemImage: "plus") { isShowingFoodPicker = true }
                }
                if let error { Section { DemoErrorNotice(error: error) { Task { await save() } } } }
                }
            }
            .navigationTitle(existing == nil ? "New food log" : "Edit food log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existing == nil ? "Save" : "Update") { Task { await save() } }
                        .disabled(foods.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $isShowingFoodPicker) {
                FoodPickerView(client: client, endUserID: context.endUserID) { food in foods.append(food); isShowingFoodPicker = false }
            }
        }
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
                    timestampUTC: DemoFormatting.apiDate.string(from: timestamp),
                    name: normalizedName.isEmpty ? nil : normalizedName,
                    user: context
                ))
            } else {
                _ = try await client.foodLogs.create(.init(
                    foods: foods.map(\.selection),
                    timestampUTC: DemoFormatting.apiDate.string(from: timestamp),
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
            DemoScreenShell {
                VStack(alignment: .leading, spacing: 18) {
                Text(log.name?.isEmpty == false ? log.name! : "Meal").font(.system(.largeTitle, design: .serif, weight: .bold))
                Text(localDate(log.timestampUTC)).foregroundStyle(DemoPalette.muted)
                ForEach(log.foods, id: \.id) { food in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(food.name).font(.headline)
                        if let brand = food.brandName { Text(brand).foregroundStyle(DemoPalette.muted) }
                        Text("\(food.consumedServing.quantity.formatted()) × \(food.servingDetails.quantity.formatted()) \(food.servingDetails.unit)")
                            .font(.subheadline)
                        DemoMacroStrip(
                            calories: food.nutrients.calories?.value,
                            protein: food.nutrients.protein?.value,
                            carbohydrates: food.nutrients.carbohydrates?.value,
                            fat: food.nutrients.totalFat?.value
                        )
                        DemoNutritionList(rows: nutritionRows(food.nutrients))
                    }.demoCard()
                }
                DisclosureGroup("Technical details") { LabeledContent("Log ID", value: log.id) }.font(.footnote)
                HStack {
                    Spacer(minLength: 0)
                    Button("Delete food log", role: .destructive) { isConfirmingDelete = true }
                        .buttonStyle(.bordered)
                    Spacer(minLength: 0)
                }
                if let error { DemoErrorNotice(error: error) { Task { await delete() } } }
                }
            }
            .padding(.vertical, 16)
        }
        .demoBackground().navigationTitle("Food log").navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Edit") { isEditing = true } } }
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
    let onSelect: (DemoSelectedFood) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [FoodSearchItem] = []
    @State private var chosenFood: FoodSearchItem?
    @State private var isLoading = false
    @State private var error: Error?

    var body: some View {
        NavigationStack {
            ScrollView {
                DemoScreenShell {
                    DemoFillWidth {
                        VStack(alignment: .leading, spacing: 16) {
                            DemoSearchField(prompt: "Search foods", text: $query) {
                                Task { await search() }
                            }
                            .onChange(of: query) { _, value in
                                if value.isEmpty {
                                    results = []
                                    error = nil
                                }
                            }

                            if let error {
                                DemoErrorNotice(error: error) { Task { await search() } }
                            } else if results.isEmpty && !isLoading {
                                DemoEmptyStateCard(
                                    title: "Find a food",
                                    message: "Search January’s food database, then choose a serving and quantity.",
                                    symbol: "fork.knife"
                                )
                            } else if !results.isEmpty {
                                VStack(alignment: .leading, spacing: 10) {
                                    DemoSectionLabel("Results · January food database")
                                    VStack(spacing: 0) {
                                        ForEach(Array(results.enumerated()), id: \.element.id) { index, food in
                                            Button { chosenFood = food } label: {
                                                DemoFoodRow(food: food)
                                                    .padding(.vertical, 12)
                                            }
                                            .buttonStyle(.plain)
                                            if index < results.count - 1 { Divider().overlay(DemoPalette.divider) }
                                        }
                                    }
                                    .demoCard()
                                    DemoFillWidth {
                                        Text("Photos load from January’s food database.")
                                            .font(.system(size: 14))
                                            .foregroundStyle(DemoPalette.muted)
                                            .multilineTextAlignment(.center)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.bottom, 32)
            }
            .demoBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(DemoPalette.goldText)
                }
                ToolbarItem(placement: .principal) {
                    Text("Add food")
                        .font(DemoTypography.cardTitle)
                        .foregroundStyle(DemoPalette.ink)
                }
            }
            .sheet(isPresented: Binding(
                get: { chosenFood != nil },
                set: { if !$0 { chosenFood = nil } }
            )) {
                if let chosenFood { ServingSelectionSheet(food: chosenFood, onSelect: onSelect) }
            }
        }
    }

    @MainActor private func search() async {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines); guard !value.isEmpty else { return }
        isLoading = true; error = nil
        do { results = try await client.foods.search(.init(query: value, endUserID: endUserID)).items }
        catch { self.error = error }
        isLoading = false
    }
}

private struct ServingSelectionSheet: View {
    let food: FoodSearchItem
    let onSelect: (DemoSelectedFood) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var serving: ServingOption
    @State private var quantity = 1.0

    init(food: FoodSearchItem, onSelect: @escaping (DemoSelectedFood) -> Void) {
        self.food = food; self.onSelect = onSelect
        _serving = State(initialValue: food.servings.first(where: \.isPrimary) ?? food.servings.first ?? .init(id: .init(rawValue: 0), quantity: 1, unit: "serving", scalingFactor: 1, isPrimary: true))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                DemoScreenShell {
                    DemoFillWidth {
                        VStack(alignment: .leading, spacing: 14) {
                            DemoFillWidth {
                                HStack(spacing: 8) {
                                    Button("Cancel") { dismiss() }
                                        .font(.system(size: 17, weight: .semibold))
                                        .foregroundStyle(DemoPalette.goldText)
                                        .frame(width: 88, alignment: .leading)
                                    Spacer(minLength: 0)
                                    DemoSectionLabel("Choose serving")
                                        .padding(.horizontal, 0)
                                    Spacer(minLength: 0)
                                    Color.clear.frame(width: 88, height: 1)
                                }
                            }

                            Text(food.name)
                                .font(DemoTypography.sheetTitle)
                                .foregroundStyle(DemoPalette.ink)

                            VStack(spacing: 0) {
                                HStack(spacing: 12) {
                                    Text("Serving")
                                        .font(DemoTypography.bodyStrong)
                                    Spacer(minLength: 8)
                                    Picker("Serving", selection: $serving) {
                                        ForEach(food.servings, id: \.id) {
                                            Text("\($0.quantity.formatted()) \($0.unit)").tag($0)
                                        }
                                    }
                                    .labelsHidden()
                                    .tint(DemoPalette.goldText)
                                }
                                .padding(.horizontal, 22)
                                .padding(.vertical, 11)

                                Divider().overlay(DemoPalette.border)

                                HStack(spacing: 12) {
                                    Text("Quantity")
                                        .font(DemoTypography.bodyStrong)
                                    Spacer(minLength: 8)
                                    Button("Decrease quantity", systemImage: "minus") {
                                        quantity = max(0.25, quantity - 0.25)
                                    }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(DemoQuantityButtonStyle())
                                    Text(quantity.formatted(.number.precision(.fractionLength(0...2))))
                                        .font(.system(size: 34, weight: .semibold, design: .monospaced))
                                        .monospacedDigit()
                                        .frame(width: 66)
                                    Button("Increase quantity", systemImage: "plus") {
                                        quantity += 0.25
                                    }
                                    .labelStyle(.iconOnly)
                                    .buttonStyle(DemoQuantityButtonStyle(isPrimary: true))
                                }
                                .padding(.horizontal, 22)
                                .padding(.vertical, 10)
                            }
                            .background(DemoPalette.paper, in: RoundedRectangle(cornerRadius: DemoRadius.card, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: DemoRadius.card, style: .continuous)
                                    .stroke(DemoPalette.border, lineWidth: 1.5)
                            }

                            DemoEqualColumns(spacing: 8) {
                                servingMetric("Calories", scaled(food.calories), "cal")
                                servingMetric("Carbs", scaled(food.carbohydrates), "g")
                                servingMetric("Protein", scaled(food.protein), "g")
                                servingMetric("Fat", scaled(food.totalFat), "g")
                            }

                            Button("Add to meal") {
                                onSelect(.init(food: food, serving: serving, quantity: quantity))
                                dismiss()
                            }
                            .buttonStyle(DemoPrimaryButtonStyle())
                        }
                    }
                }
                .padding(.top, DemoSpacing.sheetTop)
                .padding(.bottom, 12)
            }
            .demoBackground()
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.medium])
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
                .foregroundStyle(DemoPalette.muted)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value?.formatted(.number.precision(.fractionLength(0...1))) ?? "—")
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                Text(unit)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DemoPalette.muted)
            }
        }
    }
}

private func selectedFood(_ logged: LoggedFood) -> DemoSelectedFood {
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

private func nutritionRows(_ value: NutritionFacts) -> [DemoNutrientRow] {
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
    guard let date = DemoFormatting.apiDate.date(from: value) else { return value }
    return date.formatted(date: .abbreviated, time: .shortened)
}
