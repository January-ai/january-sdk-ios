import January
import SwiftUI

private struct SearchCity: Identifiable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double

    static let cities = [
        SearchCity(id: "san-francisco", name: "San Francisco, CA", latitude: 37.7749, longitude: -122.4194),
        SearchCity(id: "new-york", name: "New York, NY", latitude: 40.7128, longitude: -74.0060),
        SearchCity(id: "los-angeles", name: "Los Angeles, CA", latitude: 34.0522, longitude: -118.2437),
        SearchCity(id: "chicago", name: "Chicago, IL", latitude: 41.8781, longitude: -87.6298),
        SearchCity(id: "austin", name: "Austin, TX", latitude: 30.2672, longitude: -97.7431),
        SearchCity(id: "miami", name: "Miami, FL", latitude: 25.7617, longitude: -80.1918),
        SearchCity(id: "seattle", name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321),
    ]
}

struct SearchView: View {
    enum Scope: String, CaseIterable { case foods = "Foods"; case restaurants = "Restaurants" }
    enum FoodMode: String, CaseIterable { case name = "Name"; case meal = "Meal description"; case barcode = "Barcode" }
    enum RestaurantMode: String, CaseIterable { case restaurants = "Restaurants"; case menuItems = "Menu items" }

    let client: JanuaryClient
    let settingsAction: () -> Void

    @EnvironmentObject private var userSession: UserSession
    @State private var scope = Scope.foods
    @State private var foodMode = FoodMode.name
    @State private var restaurantMode = RestaurantMode.restaurants
    @State private var query = ""
    @State private var category: FoodCategory?
    @State private var foodSuggestions: [FoodSuggestion] = []
    @State private var autocompleteSuppressedQuery: String?
    @State private var foodResults: [FoodSearchItem] = []
    @State private var naturalResult: FoodScan?
    @State private var restaurants: [Restaurant] = []
    @State private var menuItems: [RestaurantMenuItem] = []
    @State private var isLoading = false
    @State private var error: Error?
    @State private var isShowingFilters = false
    @State private var isShowingBarcodeScanner = false
    @State private var latitude = 37.7749
    @State private var longitude = -122.4194
    @State private var selectedLocationID = "san-francisco"
    @State private var radius = 8000.0
    @State private var foodResultLimit = 10
    @State private var restaurantResultLimit = 10
    @StateObject private var locationProvider = LocationProvider()

    private var endUserID: String { userSession.endUserID }

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenShell {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        SearchField(
                            prompt: searchPrompt,
                            text: queryBinding,
                            voiceCaptureEnabled: foodMode != .barcode
                        ) {
                            Task { await submit() }
                        }

                        if !foodSuggestions.isEmpty {
                            FoodSuggestionList(items: foodSuggestions) { suggestion in
                                guard let suggestionName = suggestion.name else { return }
                                autocompleteSuppressedQuery = suggestionName
                                query = suggestionName
                                foodSuggestions = []
                                Task { await submit() }
                            }
                        }

                        SegmentedControl(Scope.allCases, selection: $scope) { $0.rawValue }
                            .onChange(of: scope) { _, _ in resetResults() }

                        if scope == .foods { foodContent } else { restaurantContent }
                    }
                }
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .appBackground()
            .appNavigationBar("Search", style: .leading) {
                EmptyView()
            } trailing: {
                AppNavigationButton(.settings, action: settingsAction)
            }
            .sheet(isPresented: $isShowingFilters) {
                RestaurantFiltersSheet(
                    latitude: $latitude,
                    longitude: $longitude,
                    selectedLocationID: $selectedLocationID,
                    radius: $radius,
                    limit: $restaurantResultLimit,
                    locationProvider: locationProvider
                )
            }
            .sheet(isPresented: $isShowingBarcodeScanner) {
                BarcodeScannerView { value in
                    query = value
                    isShowingBarcodeScanner = false
                    Task { await submit() }
                }
            }
            .onChange(of: locationProvider.location) { _, location in
                guard let location else { return }
                latitude = location.latitude
                longitude = location.longitude
                selectedLocationID = "current"
            }
            .task(id: autocompleteTaskID) {
                await loadAutocomplete()
            }
        }
    }

    private var autocompleteTaskID: String {
        let categoryValue = switch category {
        case .generic: "generic"
        case .branded: "branded"
        case .recipe: "recipe"
        case nil: "all"
        }
        return "\(scope.rawValue)|\(foodMode.rawValue)|\(categoryValue)|\(query)"
    }

    private var queryBinding: Binding<String> {
        Binding(
            get: { query },
            set: { value in
                query = value
                if value != autocompleteSuppressedQuery {
                    autocompleteSuppressedQuery = nil
                }
            }
        )
    }

    private var autocompleteCategory: AutocompleteFoodCategory? {
        switch category {
        case .generic: .generic
        case .branded: .branded
        case .recipe, nil: nil
        }
    }

    private var canAutocomplete: Bool {
        scope == .foods && foodMode == .name && category != .recipe
    }

    private var searchPrompt: String {
        if scope == .restaurants { return restaurantMode == .restaurants ? "Restaurant name" : "Dish or restaurant" }
        switch foodMode {
        case .name: return "Food name"
        case .meal: return "Describe what was eaten"
        case .barcode: return "6–14 digit barcode"
        }
    }

    @ViewBuilder
    private var foodContent: some View {
        SegmentedControl(FoodMode.allCases, selection: $foodMode) { mode in
            mode == .meal ? "Description" : mode.rawValue
        }
        .onChange(of: foodMode) { _, _ in resetResults() }

        if foodMode == .name {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    categoryChip("All", category: nil)
                    categoryChip("General", category: .generic)
                    categoryChip("Branded", category: .branded)
                }
                HStack(spacing: 8) {
                    categoryChip("Recipe", category: .recipe)
                }
            }
        } else if foodMode == .barcode {
            Button {
                isShowingBarcodeScanner = true
            } label: {
                Label("Scan barcode", systemImage: "barcode.viewfinder")
            }
            .buttonStyle(OutlinedButtonStyle())
        } else {
            Text("Try “a bowl of oatmeal with honey and a banana.”")
                .font(.subheadline)
                .foregroundStyle(AppPalette.muted)
        }

        if query.isEmpty {
            SearchPromptCard(
                title: foodMode == .meal ? "Describe a meal" : foodMode == .barcode ? "Enter or scan a barcode" : "Find a food",
                message: foodMode == .meal ? "January will identify foods, servings, and nutrition from a sentence." : "Search January’s database, then choose a serving and quantity.",
                symbol: foodMode == .barcode ? "barcode" : "fork.knife"
            )
        }

        submitButton
        requestState

        if let naturalResult {
            NaturalMealResultView(
                client: client,
                result: naturalResult,
                endUserID: AppFormatting.endUserID(endUserID),
                timezone: TimeZone(identifier: userSession.timezone) ?? .current,
                onAnalyzeAnother: resetMealAnalysis
            )
            .id(naturalResult)
        } else if !foodResults.isEmpty {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("Results · January food database")
                Spacer(minLength: 12)
                Menu {
                    ForEach([10, 20, 40], id: \.self) { limit in
                        Button("\(limit) results") { foodResultLimit = limit }
                    }
                } label: {
                    Text("\(foodResults.count)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(AppPalette.muted)
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(foodResults.enumerated()), id: \.element.id) { index, food in
                    NavigationLink {
                        FoodDetailView(client: client, food: food, endUserID: AppFormatting.endUserID(endUserID))
                    } label: {
                        FoodRow(food: food)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if index < foodResults.count - 1 {
                        Divider().overlay(AppPalette.divider)
                    }
                }
            }
            .appCard()
        } else if !isLoading, error == nil, !query.isEmpty {
            EmptyStateCard(
                title: "No foods found",
                message: "Try another name or broaden the selected food category.",
                symbol: "magnifyingglass"
            )
        }
    }

    @ViewBuilder
    private var restaurantContent: some View {
        SegmentedControl(RestaurantMode.allCases, selection: $restaurantMode) { $0.rawValue }
        .onChange(of: restaurantMode) { _, _ in resetResults() }

        Button { isShowingFilters = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .foregroundStyle(AppPalette.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Search location")
                        .font(.headline)
                    Text(locationSummary)
                        .font(.caption)
                        .foregroundStyle(AppPalette.muted)
                        .monospacedDigit()
                }
                Spacer(minLength: 8)
                Text("\(radius / 1609.344, format: .number.precision(.fractionLength(1))) mi")
                    .font(.subheadline)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(AppPalette.body)
        }
        .appCard()

        if query.isEmpty {
            SearchPromptCard(title: "Search nearby", message: "Find restaurants or dishes around a location.", symbol: "mappin.and.ellipse")
        }

        submitButton
        requestState

        if restaurantMode == .restaurants, !restaurants.isEmpty {
            Text("Nearby restaurants").font(.system(.title3, design: .serif, weight: .semibold))
            ForEach(restaurants, id: \.id) { restaurant in
                NavigationLink {
                    RestaurantDetailView(
                        client: client,
                        restaurant: restaurant,
                        latitude: latitude,
                        longitude: longitude,
                        radius: radius,
                        resultLimit: restaurantResultLimit,
                        endUserID: AppFormatting.endUserID(endUserID)
                    )
                } label: {
                    RestaurantRow(restaurant: restaurant).appCard()
                }
                .buttonStyle(.plain)
            }
        } else if restaurantMode == .menuItems, !menuItems.isEmpty {
            Text("Nearby menu items").font(.system(.title3, design: .serif, weight: .semibold))
            ForEach(menuItems, id: \.id) { item in
                NavigationLink {
                    RestaurantMenuItemDetailView(
                        client: client,
                        item: item,
                        endUserID: AppFormatting.endUserID(endUserID)
                    )
                } label: {
                    MenuItemRow(item: item).appCard()
                }
                .buttonStyle(.plain)
            }
        } else if !isLoading, error == nil, !query.isEmpty {
            EmptyStateCard(
                title: "No nearby matches",
                message: "Try another name, location, or search radius.",
                symbol: "mappin.slash"
            )
        }
    }

    private var locationSummary: String {
        if selectedLocationID == "current", let location = locationProvider.location {
            return "Current location · \(location.coordinateDescription)"
        }
        let city = SearchCity.cities.first { $0.id == selectedLocationID } ?? SearchCity.cities[0]
        return "Preset city · \(city.name)"
    }

    private var submitButton: some View {
        PrimaryButton(
            title: buttonTitle,
            isLoading: isLoading
        ) {
            Task { await submit() }
        }
    }

    private var buttonTitle: String {
        if scope == .restaurants { return "Search nearby" }
        switch foodMode { case .name: return "Search foods"; case .meal: return "Parse meal"; case .barcode: return "Look up barcode" }
    }

    @ViewBuilder
    private var requestState: some View {
        if let error { ErrorNotice(error: error) { Task { await submit() } } }
    }

    private func categoryChip(_ label: String, category value: FoodCategory?) -> some View {
        Button(label) { category = value }
            .buttonStyle(ChipButtonStyle(isSelected: category == value))
    }

    @MainActor
    private func submit() async {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        foodSuggestions = []
        isLoading = true
        error = nil
        resetResults(keepError: true)
        do {
            let userID = AppFormatting.endUserID(endUserID)
            if scope == .foods {
                switch foodMode {
                case .name:
                    foodResults = try await client.foods.search(.init(query: value, category: category, limit: foodResultLimit, endUserID: userID)).items
                case .meal:
                    naturalResult = try await client.foodAnalysis.analyzeDescription(.init(query: value, endUserID: userID))
                case .barcode:
                    foodResults = try await client.foods.lookupBarcode(.init(upc: value, endUserID: userID)).items
                }
            } else if restaurantMode == .restaurants {
                restaurants = try await client.restaurants.search(.init(query: value, latitude: latitude, longitude: longitude, radius: radius, limit: restaurantResultLimit, endUserID: userID)).items
            } else {
                menuItems = try await client.restaurants.searchMenuItems(.init(query: value, latitude: latitude, longitude: longitude, radius: radius, limit: restaurantResultLimit, endUserID: userID)).items
            }
        } catch { self.error = error }
        isLoading = false
    }

    @MainActor
    private func loadAutocomplete() async {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAutocomplete,
              value.count >= 2,
              value.count <= 64,
              value != autocompleteSuppressedQuery else {
            foodSuggestions = []
            return
        }

        do {
            try await Task.sleep(nanoseconds: 300_000_000)
            try Task.checkCancellation()
            let response = try await client.foods.autocomplete(
                .init(
                    query: value,
                    category: autocompleteCategory,
                    limit: 8,
                    endUserID: AppFormatting.endUserID(endUserID)
                )
            )
            try Task.checkCancellation()
            guard query.trimmingCharacters(in: .whitespacesAndNewlines) == value else { return }
            foodSuggestions = response.items
        } catch is CancellationError {
            return
        } catch {
            foodSuggestions = []
        }
    }

    private func resetResults(keepError: Bool = false) {
        foodSuggestions = []; foodResults = []; naturalResult = nil; restaurants = []; menuItems = []
        if !keepError { error = nil }
    }

    private func resetMealAnalysis() {
        query = ""
        autocompleteSuppressedQuery = nil
        resetResults()
    }
}

struct FoodSuggestionList: View {
    let items: [FoodSuggestion]
    var loadingID: FoodID?
    let onSelect: (FoodSuggestion) -> Void

    init(
        items: [FoodSuggestion],
        loadingID: FoodID? = nil,
        onSelect: @escaping (FoodSuggestion) -> Void
    ) {
        self.items = items
        self.loadingID = loadingID
        self.onSelect = onSelect
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, suggestion in
                Button { onSelect(suggestion) } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(suggestion.name ?? "Unnamed food")
                                .font(.body.weight(.medium))
                                .foregroundStyle(AppPalette.ink)
                                .multilineTextAlignment(.leading)
                            if let brandName = suggestion.brandName, !brandName.isEmpty {
                                Text(brandName)
                                    .font(.subheadline)
                                    .foregroundStyle(AppPalette.muted)
                            }
                        }
                        Spacer(minLength: 12)
                        if loadingID == suggestion.id {
                            ProgressView()
                                .tint(AppPalette.goldText)
                        }
                    }
                    .contentShape(Rectangle())
                    .frame(minHeight: 48)
                }
                .buttonStyle(.plain)
                .disabled(loadingID != nil)

                if index < items.count - 1 {
                    Divider().overlay(AppPalette.divider)
                }
            }
        }
        .appCard()
    }
}

private struct SearchPromptCard: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        EmptyStateCard(
            title: title,
            message: message,
            symbol: symbol
        )
    }
}

private struct NaturalMealResultView: View {
    let client: JanuaryClient
    let result: FoodScan
    let endUserID: PartnerUserID?
    let timezone: TimeZone
    let onAnalyzeAnother: () -> Void

    @State private var prediction: GlucosePrediction?
    @State private var isPredicting = false
    @State private var predictionError: Error?

    private let profile = GlucosePredictionProfile(
        age: 42,
        sex: .female,
        height: .init(value: 66, unit: .inches),
        weight: .init(value: 150, unit: .pounds),
        activityLevel: .moderatelyActive,
        healthConditions: []
    )

    private var foods: [FoodSelection] {
        result.detections.compactMap { detection in
            guard let foodID = detection.food.id,
                  let serving = detection.food.servings?.first(where: { $0.id != nil }),
                  let servingID = serving.id else { return nil }
            return FoodSelection(
                id: foodID,
                serving: ServingSelection(
                    id: servingID,
                    quantity: serving.selectedQuantity ?? serving.quantity ?? 1
                )
            )
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meal nutrition").font(.system(.title2, design: .serif, weight: .semibold))
            let nutrients = result.totalNutrients
            MacroGrid(
                calories: nutrients.calories?.value,
                protein: nutrients.protein?.value,
                carbohydrates: nutrients.carbohydrates?.value,
                fat: nutrients.totalFat?.value
            )
            .appCard()
            ForEach(Array(result.detections.enumerated()), id: \.offset) { _, detection in
                VStack(alignment: .leading, spacing: 10) {
                    Text(detection.food.name ?? "Unnamed food").font(.headline)
                    if let brand = detection.food.brandName { Text(brand).foregroundStyle(AppPalette.muted) }
                    MacroGrid(
                        calories: detection.food.nutrients.calories?.value,
                        protein: detection.food.nutrients.protein?.value,
                        carbohydrates: detection.food.nutrients.carbohydrates?.value,
                        fat: detection.food.nutrients.totalFat?.value
                    )
                }
                .appCard()
            }

            PrimaryButton(
                title: prediction == nil ? "Show glucose prediction" : "Refresh glucose prediction",
                systemImage: "waveform.path.ecg",
                isLoading: isPredicting,
                isDisabled: foods.isEmpty
            ) {
                Task { await predict() }
            }

            if let predictionError {
                ErrorNotice(error: predictionError) {
                    Task { await predict() }
                }
            }

            if let prediction {
                mealPrediction(prediction)
            }

            Button("Analyze another meal", action: onAnalyzeAnother)
                .buttonStyle(OutlinedButtonStyle())
        }
    }

    @ViewBuilder
    private func mealPrediction(_ prediction: GlucosePrediction) -> some View {
        let peak = prediction.prediction.max(by: { $0.value < $1.value })
        let impact = prediction.impact
        let lineColor = impact.map(impactColor) ?? AppPalette.rust

        VStack(alignment: .leading, spacing: 8) {
            SectionLabel("Likely meal peak")
            Text(peak?.value.formatted(.number.precision(.fractionLength(0))) ?? "—")
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(lineColor)
            Text("mg/dL" + (peak.map { " · about \($0.minutes.formatted(.number.precision(.fractionLength(0)))) minutes after the meal" } ?? ""))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppPalette.muted)
            if let impact {
                Text(impactLabel(impact))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(lineColor)
            }
        }
        .appCard()

        PredictionChart(
            points: prediction.prediction.map { .init(minutes: $0.minutes, value: $0.value) },
            lowerBound: prediction.minimum,
            upperBound: prediction.maximum,
            lineColor: lineColor
        )

        Text("Prediction for all detected foods. This estimate is for demonstration purposes, not medical advice.")
            .font(.footnote)
            .foregroundStyle(AppPalette.muted)
    }

    @MainActor
    private func predict() async {
        guard !foods.isEmpty else { return }
        isPredicting = true
        predictionError = nil
        do {
            prediction = try await client.glucose.predict(.init(
                userProfile: profile,
                foods: foods,
                startTime: .now,
                endUserID: endUserID,
                timezone: timezone
            ))
        } catch {
            predictionError = error
        }
        isPredicting = false
    }

    private func impactLabel(_ impact: GlucoseImpact) -> String {
        let value = impact.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
        return value.localizedCaseInsensitiveContains("impact") ? value : "\(value) impact"
    }

    private func impactColor(_ impact: GlucoseImpact) -> Color {
        if impact == .lowImpact { return AppPalette.green }
        if impact == .mediumImpact { return AppPalette.yellow }
        if impact == .highImpact { return AppPalette.rust }
        return AppPalette.muted
    }
}

struct FoodDetailView: View {
    let client: JanuaryClient
    let food: FoodSearchItem
    let endUserID: PartnerUserID?
    @State private var detailFood: FoodSearchItem
    @State private var selectedServingID: ServingID
    @State private var quantity = 1.0
    @State private var isShowingAlternatives = false
    @State private var isShowingGlucose = false
    @State private var detailLoadError: Error?

    init(client: JanuaryClient, food: FoodSearchItem, endUserID: PartnerUserID?) {
        self.client = client; self.food = food; self.endUserID = endUserID
        let initialServing = food.servings.first(where: { $0.isPrimary == true }) ?? food.servings.first
        _detailFood = State(initialValue: food)
        _selectedServingID = State(initialValue: initialServing?.id ?? ServingID(rawValue: "0"))
        _quantity = State(initialValue: initialServing?.quantity ?? 1)
    }

    var body: some View {
        ScrollView {
            ScreenShell {
                VStack(alignment: .leading, spacing: 18) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppPalette.control)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                    NetworkImage(
                        url: detailFood.photoURL,
                        placeholder: Image(systemName: "fork.knife"),
                        contentMode: .fit
                    )
                    .padding(18)
                    .font(.system(size: 44))
                    .foregroundStyle(AppPalette.green)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(detailFood.name ?? "Unnamed food").font(.system(.largeTitle, design: .serif, weight: .bold))
                    if let brand = detailFood.brandName { Text(brand).foregroundStyle(AppPalette.muted) }
                }

                if !detailFood.servings.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Menu {
                            ForEach(detailFood.servings, id: \.id) { serving in
                                Button {
                                    if let servingID = serving.id { selectedServingID = servingID }
                                    quantity = serving.quantity ?? 1
                                } label: {
                                    if serving.id == selectedServingID {
                                        Label(servingLabel(serving), systemImage: "checkmark")
                                    } else {
                                        Text(servingLabel(serving))
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Serving unit")
                                        .font(.caption)
                                        .foregroundStyle(AppPalette.muted)
                                    Text(selectedServing.map(servingLabel) ?? "Choose a serving")
                                        .font(.headline)
                                        .foregroundStyle(AppPalette.green)
                                }
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppPalette.green)
                            }
                        }
                        Stepper(
                            "Quantity: \(quantity.formatted(.number.precision(.fractionLength(0...2)))) \(selectedServing?.unit ?? "")",
                            value: $quantity,
                            in: 0.25...100,
                            step: 0.25
                        )
                        .monospacedDigit()
                    }
                    .appCard()
                }

                MacroGrid(
                    calories: portion?.nutrition.calories?.value,
                    protein: portion?.nutrition.protein?.value,
                    carbohydrates: portion?.nutrition.carbohydrates?.value,
                    fat: portion?.nutrition.totalFat?.value
                )
                    .appCard()

                let rows = portion.map(portionNutrients) ?? []
                if !rows.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nutrition facts").font(.system(.title2, design: .serif, weight: .semibold))
                        NutritionList(rows: rows)
                    }
                    .appCard()
                }

                PrimaryButton(
                    title: "Check glucose",
                    systemImage: "waveform.path.ecg",
                    isDisabled: selectedServing == nil
                ) {
                    isShowingGlucose = true
                }

                PrimaryButton(title: "Find alternatives") {
                    isShowingAlternatives = true
                }

                DisclosureGroup("Technical details") {
                    LabeledContent("Food ID", value: "\(detailFood.id.rawValue)")
                    LabeledContent("Serving ID", value: "\(selectedServingID.rawValue)")
                }
                .font(.footnote)
                if detailLoadError != nil {
                    Text("Complete serving details could not be loaded. Showing the serving returned by search.")
                        .font(.footnote)
                        .foregroundStyle(AppPalette.muted)
                }
                }
            }
            .padding(.vertical, 16)
        }
        .appBackground()
        .appNavigationBar("Food details")
        .task(id: food.id) { await loadFullFood() }
        .sheet(isPresented: $isShowingAlternatives) {
            AlternativesView(client: client, food: detailFood, endUserID: endUserID)
        }
        .sheet(isPresented: $isShowingGlucose) {
            if let selectedServing {
                FoodGlucoseSheet(
                    client: client,
                    foodID: detailFood.id,
                    foodName: detailFood.name ?? "Unnamed food",
                    serving: selectedServing,
                    quantity: quantity,
                    endUserID: endUserID
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
    }

    private var selectedServing: ServingOption? {
        detailFood.servings.first { $0.id == selectedServingID }
    }

    private var portion: FoodPortion? {
        try? detailFood.portion(servingID: selectedServingID, quantity: quantity)
    }

    private func servingLabel(_ serving: ServingOption) -> String {
        var parts = [serving.unit ?? "serving"]
        if let grams = serving.weightGrams {
            parts.append("\(grams.formatted(.number.precision(.fractionLength(0...1)))) g")
        }
        return parts.joined(separator: " · ")
    }

    @MainActor
    private func loadFullFood() async {
        do {
            let fullFood = try await client.foods.get(id: food.id, endUserID: endUserID)
            detailFood = fullFood
            let initialServing = fullFood.servings.first(where: { $0.isPrimary == true }) ?? fullFood.servings.first
            if let initialServing, let servingID = initialServing.id {
                selectedServingID = servingID
                quantity = initialServing.quantity ?? 1
            }
            detailLoadError = nil
        } catch {
            detailLoadError = error
        }
    }
}

private struct FoodGlucoseSheet: View {
    let client: JanuaryClient
    let foodID: FoodID
    let foodName: String
    let serving: ServingOption
    let quantity: Double
    let endUserID: PartnerUserID?

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var userSession: UserSession
    @State private var prediction: GlucosePrediction?
    @State private var isLoading = false
    @State private var error: Error?

    private var timezone: TimeZone { TimeZone(identifier: userSession.timezone) ?? .current }

    private let profile = GlucosePredictionProfile(
        age: 42,
        sex: .female,
        height: .init(value: 66, unit: .inches),
        weight: .init(value: 150, unit: .pounds),
        activityLevel: nil,
        healthConditions: []
    )

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenShell {
                    VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(foodName)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(AppPalette.ink)
                        Text("\(quantity.formatted(.number.precision(.fractionLength(0...2)))) \(serving.unit)")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(AppPalette.muted)
                    }

                    if isLoading {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            VStack(spacing: 14) {
                            LoadingSpinner(color: AppPalette.green, size: 30)
                            Text("Predicting your glucose response…")
                                .font(.headline)
                            Text("This usually takes a few seconds.")
                                .font(.subheadline)
                                .foregroundStyle(AppPalette.muted)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 42)
                        .appCard()
                    } else if let error {
                        ErrorNotice(error: error) {
                            Task { await predict() }
                        }
                    } else if let prediction {
                        predictionContent(prediction)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Demo profile", systemImage: "person.crop.circle")
                            .font(.headline)
                        Text("42 years · Female · 66 in · 150 lb · No reported condition")
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.muted)
                    }
                    .appCard()

                    Text("This is an estimate for demonstration purposes, not medical advice.")
                        .font(.footnote)
                        .foregroundStyle(AppPalette.muted)
                    }
                }
                .padding(.vertical, 16)
            }
            .appBackground()
            .appNavigationBar("Glucose response") {
                AppNavigationButton(.close, title: "Close glucose response") { dismiss() }
            } trailing: {
                EmptyView()
            }
            .task {
                guard prediction == nil, !isLoading else { return }
                await predict()
            }
        }
    }

    @ViewBuilder
    private func predictionContent(_ prediction: GlucosePrediction) -> some View {
        let points = prediction.curve.compactMap { point -> ChartPoint? in
            guard point.count >= 2 else { return nil }
            return ChartPoint(minutes: point[0], value: point[1])
        }

        HStack {
            Label(prediction.scoring.map(impactLabel) ?? "Unknown impact", systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(prediction.scoring.map(impactColor) ?? AppPalette.muted)
            Spacer()
            Text("Estimated impact")
                .font(.subheadline)
                .foregroundStyle(AppPalette.muted)
        }
        .appCard()

        PredictionChart(
            points: points,
            lowerBound: prediction.minimum,
            upperBound: prediction.maximum,
            lineColor: prediction.scoring == .lowImpact ? AppPalette.green : AppPalette.rust
        )

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            glucoseMetric("Peak", value: points.map(\.value).max(), unit: "mg/dL")
            glucoseMetric("Target minimum", value: prediction.minimum, unit: "mg/dL")
            glucoseMetric("Target maximum", value: prediction.maximum, unit: "mg/dL")
            glucoseMetric("Data points", value: Double(points.count), unit: "")
        }

        DisclosureGroup("Prediction data") {
            VStack(spacing: 0) {
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    LabeledContent(
                        "+\(point.minutes.formatted(.number.precision(.fractionLength(0)))) min",
                        value: "\(point.value.formatted(.number.precision(.fractionLength(0...1)))) mg/dL"
                    )
                    .font(.subheadline)
                    .monospacedDigit()
                    .padding(.vertical, 9)
                    if index < points.count - 1 { Divider() }
                }
            }
            .padding(.top, 8)
        }
        .appCard()
    }

    private func glucoseMetric(_ title: String, value: Double?, unit: String) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppPalette.muted)
            if let value {
                Text("\(value.formatted(.number.precision(.fractionLength(0...1))))\(unit.isEmpty ? "" : " \(unit)")")
                    .font(.system(.headline, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(AppPalette.ink)
            } else {
                Text("—")
                    .font(.headline)
                    .foregroundStyle(AppPalette.muted)
            }
            }
            Spacer(minLength: 0)
        }
        .appCard()
    }

    @MainActor
    private func predict() async {
        guard let servingID = serving.id else { return }
        isLoading = true
        error = nil
        do {
            prediction = try await client.glucose.predict(.init(
                userProfile: profile,
                foods: [FoodSelection(
                    id: foodID,
                    serving: ServingSelection(id: servingID, quantity: quantity)
                )],
                startTime: .now,
                endUserID: endUserID,
                timezone: timezone
            ))
        } catch {
            self.error = error
        }
        isLoading = false
    }

    private func impactLabel(_ impact: GlucoseImpact) -> String {
        if impact == .lowImpact { return "Low impact" }
        if impact == .mediumImpact { return "Medium impact" }
        if impact == .highImpact { return "High impact" }
        return impact.rawValue.capitalized
    }

    private func impactColor(_ impact: GlucoseImpact) -> Color {
        if impact == .lowImpact { return AppPalette.green }
        if impact == .mediumImpact { return AppPalette.yellow }
        if impact == .highImpact { return AppPalette.rust }
        return AppPalette.muted
    }
}

private struct AlternativesView: View {
    let client: JanuaryClient
    let food: FoodSearchItem
    let endUserID: PartnerUserID?
    @Environment(\.dismiss) private var dismiss
    @State private var restrictions: Set<DietRestriction> = []
    @State private var preferences: Set<DietPreference> = []
    @State private var result: SuggestFoodAlternativesResponse?
    @State private var alternativeDetails: [FoodID: FoodSearchItem] = [:]
    @State private var error: Error?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenShell {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.section) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("Personalized suggestions", systemImage: "leaf.fill")
                                .font(AppTypography.eyebrow)
                                .foregroundStyle(AppPalette.green)
                            Text(food.name ?? "Unnamed food")
                                .font(AppTypography.sheetTitle)
                                .foregroundStyle(AppPalette.ink)
                            Text("Choose any dietary needs that should shape January’s recommendations.")
                                .font(AppTypography.body)
                                .foregroundStyle(AppPalette.body)
                        }
                        .appCard()

                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel("Dietary restrictions")
                            FlowChoiceGrid(values: DietRestriction.allCases, selected: $restrictions)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            SectionLabel("Dietary preferences")
                            FlowChoiceGrid(values: DietPreference.allCases, selected: $preferences)
                        }

                        if let error { ErrorNotice(error: error) { Task { await load() } } }
                        if let result {
                            if result.alternatives.isEmpty {
                                EmptyStateCard(
                                    title: "No suitable alternatives",
                                    message: "No foods matched every selected dietary need.",
                                    symbol: "leaf"
                                )
                            } else {
                                SectionLabel("Suggestions · \(result.alternatives.count)")
                                ForEach(Array(result.alternatives.enumerated()), id: \.offset) { _, alternative in
                                    let loadedFood = alternative.id.flatMap { alternativeDetails[$0] }
                                    let detailFood = loadedFood ?? alternativeDetailFood(alternative)
                                    Group {
                                        if let detailFood {
                                            NavigationLink {
                                                FoodDetailView(client: client, food: detailFood, endUserID: endUserID)
                                            } label: {
                                                AlternativeFoodRow(food: alternative, photoURL: detailFood.photoURL, isInteractive: true)
                                            }
                                            .buttonStyle(.plain)
                                        } else {
                                            AlternativeFoodRow(food: alternative, photoURL: nil, isInteractive: false)
                                        }
                                    }
                                    .appCard()
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
            }
            .appBackground()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                PrimaryButton(
                    title: result == nil ? "Find alternatives" : "Refresh alternatives",
                    systemImage: "leaf",
                    isLoading: isLoading && result == nil,
                    isDisabled: isLoading
                ) {
                    Task { await load() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(AppPalette.paper)
            }
            .appNavigationBar("Food alternatives") {
                AppNavigationButton(.close, title: "Close alternatives") { dismiss() }
            } trailing: {
                EmptyView()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }

    @MainActor private func load() async {
        isLoading = true; error = nil
        do {
            let response = try await client.foods.suggestAlternatives(.init(
                foodID: food.id,
                dietRestrictions: Array(restrictions),
                dietPreferences: Array(preferences),
                endUserID: endUserID
            ))
            result = response
            alternativeDetails = [:]
            await loadAlternativeDetails(response)
        } catch { self.error = error }
        isLoading = false
    }

    @MainActor
    private func loadAlternativeDetails(_ response: SuggestFoodAlternativesResponse) async {
        let ids = Set(response.alternatives.compactMap(\.id))
        await withTaskGroup(of: (FoodID, FoodSearchItem)?.self) { group in
            for id in ids {
                group.addTask {
                    guard let detail = try? await client.foods.get(id: id, endUserID: endUserID) else {
                        return nil
                    }
                    return (id, detail)
                }
            }
            for await detail in group {
                if let (id, food) = detail {
                    alternativeDetails[id] = food
                }
            }
        }
    }
}

private struct AlternativeFoodRow: View {
    let food: DetectedFood
    let photoURL: String?
    let isInteractive: Bool

    var body: some View {
        HStack(spacing: 14) {
            NetworkImage(
                url: photoURL,
                placeholder: Image(systemName: "fork.knife")
            )
            .font(.title3)
            .foregroundStyle(AppPalette.green)
            .frame(width: 58, height: 58)
            .background(AppPalette.control)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            VStack(alignment: .leading, spacing: 7) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name ?? "Unnamed food")
                        .font(.headline)
                        .foregroundStyle(AppPalette.ink)
                    if let brand = food.brandName, !brand.isEmpty {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundStyle(AppPalette.muted)
                    }
                    if let serving = food.servings?.first {
                        Text("\((serving.quantity ?? 1).formatted(.number.precision(.fractionLength(0...2)))) \(serving.unit)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(AppPalette.muted)
                    }
                }

                HStack(spacing: 10) {
                    nutrientMetric("cal", food.nutrients.calories?.value)
                    nutrientMetric("P", food.nutrients.protein?.value)
                    nutrientMetric("C", food.nutrients.carbohydrates?.value)
                    nutrientMetric("F", food.nutrients.totalFat?.value)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 4)
            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(isInteractive ? "Opens food details" : "Details are unavailable for this result")
    }

    private func nutrientMetric(_ label: String, _ value: Double?) -> some View {
        Group {
            if let value {
                Text(label == "cal"
                     ? "\(value.formatted(.number.precision(.fractionLength(0)))) cal"
                     : "\(label) \(value.formatted(.number.precision(.fractionLength(0...1))))g")
            }
        }
        .font(.system(.caption, design: .monospaced, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(AppPalette.muted)
    }
}

private func alternativeDetailFood(_ food: DetectedFood) -> FoodSearchItem? {
    guard let id = food.id, let detectedServings = food.servings, !detectedServings.isEmpty else {
        return nil
    }
    let servings = detectedServings.enumerated().map { index, serving in
        ServingOption(
            id: serving.id,
            quantity: serving.quantity ?? 1,
            unit: serving.unit,
            scalingFactor: 1,
            isPrimary: index == 0
        )
    }
    return FoodSearchItem(
        id: id,
        name: food.name,
        brandName: food.brandName,
        calories: food.nutrients.calories?.value,
        protein: food.nutrients.protein?.value,
        carbohydrates: food.nutrients.carbohydrates?.value,
        netCarbohydrates: food.nutrients.netCarbohydrates?.value,
        totalFat: food.nutrients.totalFat?.value,
        saturatedFat: food.nutrients.saturatedFat?.value,
        fiber: food.nutrients.fiber?.value,
        totalSugars: food.nutrients.totalSugars?.value,
        addedSugars: food.nutrients.addedSugars?.value,
        sodium: food.nutrients.sodium?.value,
        servings: servings
    )
}

private struct FlowChoiceGrid<Value: CaseIterable & Hashable & RawRepresentable>: View where Value.RawValue == String, Value.AllCases: RandomAccessCollection {
    let values: Value.AllCases
    @Binding var selected: Set<Value>

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
            ForEach(Array(values), id: \.self) { value in
                Button(choiceLabel(value)) { toggle(value) }
                    .buttonStyle(ChipButtonStyle(isSelected: selected.contains(value)))
            }
        }
    }

    private func choiceLabel(_ value: Value) -> String {
        value.rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func toggle(_ value: Value) {
        if value.rawValue == "None" {
            selected = [value]
        } else {
            selected = Set(selected.filter { $0.rawValue != "None" })
            if selected.contains(value) { selected.remove(value) } else { selected.insert(value) }
            if selected.isEmpty, let none = Array(values).first(where: { $0.rawValue == "None" }) { selected = [none] }
        }
    }
}

private struct RestaurantRow: View {
    let restaurant: Restaurant
    var body: some View {
        HStack {
            Image(systemName: "fork.knife.circle.fill").font(.title).foregroundStyle(AppPalette.green)
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name ?? "Restaurant").font(.headline)
                Text([restaurant.city, restaurant.distance.map { "\(($0 / 1609.344).formatted(.number.precision(.fractionLength(1)))) mi" }].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(AppPalette.muted)
            }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
    }
}

private struct MenuItemRow: View {
    let item: RestaurantMenuItem
    var body: some View {
        HStack(spacing: 12) {
            NetworkImage(
                url: item.photoURL,
                placeholder: Image(systemName: "fork.knife")
            )
                .font(.system(size: 24))
                .foregroundStyle(AppPalette.green)
                .frame(width: 56, height: 56).background(AppPalette.control).clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name ?? "Unnamed menu item").font(.headline)
                Text(item.restaurantName ?? "Restaurant").foregroundStyle(AppPalette.muted)
                if let calories = item.calories { Text("\(calories.formatted(.number.precision(.fractionLength(0)))) cal").font(.caption) }
            }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
    }
}

private struct RestaurantDetailView: View {
    let client: JanuaryClient
    let restaurant: Restaurant
    let endUserID: PartnerUserID?
    @StateObject private var model: RestaurantDetailViewModel

    init(
        client: JanuaryClient,
        restaurant: Restaurant,
        latitude: Double,
        longitude: Double,
        radius: Double,
        resultLimit: Int,
        endUserID: PartnerUserID?
    ) {
        self.client = client
        self.restaurant = restaurant
        self.endUserID = endUserID
        _model = StateObject(wrappedValue: RestaurantDetailViewModel(
            client: client,
            restaurant: restaurant,
            latitude: latitude,
            longitude: longitude,
            radius: radius,
            resultLimit: resultLimit,
            endUserID: endUserID
        ))
    }

    var body: some View {
        ScrollView {
            ScreenShell {
                VStack(alignment: .leading, spacing: 20) {
                    Text(restaurant.name ?? "Restaurant")
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(AppPalette.ink)

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Location")
                        if let city = restaurant.city { LabeledContent("City", value: city) }
                        if let address = restaurant.address1 { Text(address) }
                        if let address = restaurant.address2 { Text(address) }
                        if let distance = restaurant.distance {
                            Divider().overlay(AppPalette.divider)
                            LabeledContent("Distance", value: "\((distance / 1609.344).formatted(.number.precision(.fractionLength(1)))) mi")
                                .monospacedDigit()
                        }
                    }
                    .appCard()

                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Menu items")
                        menuContent
                    }

                    DisclosureGroup("Technical details") {
                        if let isChain = restaurant.isChain { LabeledContent("Type", value: isChain ? "Chain" : "Independent") }
                        LabeledContent("Restaurant ID", value: restaurant.id)
                    }
                    .font(.footnote)
                }
            }
            .padding(.vertical, 16)
        }
        .appBackground()
        .appNavigationBar("Restaurant")
        .task(id: restaurant.id) { await model.loadIfNeeded() }
    }

    @ViewBuilder
    private var menuContent: some View {
        if model.showsInitialLoading {
            HStack(spacing: 12) {
                LoadingSpinner(color: AppPalette.green)
                Text("Loading menu")
                    .font(.headline)
                    .foregroundStyle(AppPalette.muted)
                Spacer(minLength: 0)
            }
            .appCard()
        } else if model.menuItems.isEmpty, let menuError = model.error {
            ErrorNotice(error: menuError) { Task { await model.retry() } }
        } else if model.menuItems.isEmpty {
            EmptyStateCard(
                title: "No menu items found",
                message: "January did not return menu items for this restaurant.",
                symbol: "fork.knife"
            )
        } else {
            VStack(spacing: 0) {
                ForEach(Array(model.menuItems.enumerated()), id: \.element.id) { index, item in
                    NavigationLink {
                        RestaurantMenuItemDetailView(client: client, item: item, endUserID: endUserID)
                    } label: {
                        MenuItemRow(item: item)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if index < model.menuItems.count - 1 {
                        Divider().overlay(AppPalette.divider)
                    }
                }
            }
            .appCard()
        }
    }

}

private struct RestaurantMenuItemDetailView: View {
    let client: JanuaryClient
    let item: RestaurantMenuItem
    let endUserID: PartnerUserID?

    @State private var selectedServingID: ServingID?
    @State private var quantity: Double
    @State private var isShowingGlucoseImpact = false

    init(client: JanuaryClient, item: RestaurantMenuItem, endUserID: PartnerUserID?) {
        self.client = client
        self.item = item
        self.endUserID = endUserID
        let initialServing = item.servings.first(where: { $0.isPrimary == true }) ?? item.servings.first
        _selectedServingID = State(initialValue: initialServing?.id)
        _quantity = State(initialValue: initialServing?.quantity ?? 1)
    }

    var body: some View {
        ScrollView {
            ScreenShell {
                VStack(alignment: .leading, spacing: 18) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(AppPalette.control)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        NetworkImage(
                            url: item.photoURL,
                            placeholder: Image(systemName: "fork.knife"),
                            contentMode: .fit
                        )
                        .padding(18)
                        .font(.system(size: 44))
                        .foregroundStyle(AppPalette.green)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                Text(item.name ?? "Unnamed menu item").font(.system(.largeTitle, design: .serif, weight: .bold))
                Text(item.restaurantName ?? "Restaurant").foregroundStyle(AppPalette.muted)
                MacroGrid(calories: item.calories, protein: item.protein, carbohydrates: item.carbohydrates, fat: item.totalFat).appCard()
                NutritionList(rows: menuItemNutrients(item)).appCard()
                if !item.servings.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionLabel("Serving")
                        Menu {
                            ForEach(item.servings, id: \.id) { serving in
                                Button {
                                    selectedServingID = serving.id
                                    quantity = serving.quantity ?? 1
                                } label: {
                                    if serving.id == selectedServingID {
                                        Label(servingLabel(serving), systemImage: "checkmark")
                                    } else {
                                        Text(servingLabel(serving))
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedServing.map(servingLabel) ?? "Choose a serving")
                                    .font(.headline)
                                    .foregroundStyle(AppPalette.green)
                                Spacer(minLength: 12)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppPalette.green)
                            }
                        }
                        Stepper(
                            "Quantity: \(quantity.formatted(.number.precision(.fractionLength(0...2)))) \(selectedServing?.unit ?? "")",
                            value: $quantity,
                            in: 0.25...100,
                            step: 0.25
                        )
                        .monospacedDigit()
                    }
                    .appCard()
                }

                PrimaryButton(
                    title: "See glucose impact",
                    systemImage: "waveform.path.ecg",
                    isDisabled: selectedServing == nil || glucoseFoodID == nil
                ) {
                    isShowingGlucoseImpact = true
                }

                DisclosureGroup("Technical details") { LabeledContent("Menu item ID", value: item.id) }.font(.footnote)
                }
            }
            .padding(.vertical, 16)
        }
        .appBackground()
        .appNavigationBar("Menu item")
        .sheet(isPresented: $isShowingGlucoseImpact) {
            if let glucoseFoodID, let selectedServing {
                FoodGlucoseSheet(
                    client: client,
                    foodID: glucoseFoodID,
                    foodName: item.name ?? "Unnamed menu item",
                    serving: selectedServing,
                    quantity: quantity,
                    endUserID: endUserID
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
            }
        }
    }

    private var glucoseFoodID: FoodID? {
        FoodID(rawValue: item.id)
    }

    private var selectedServing: ServingOption? {
        item.servings.first { $0.id == selectedServingID }
    }

    private func servingLabel(_ serving: ServingOption) -> String {
        var parts = [serving.unit ?? "serving"]
        if let grams = serving.weightGrams {
            parts.append("\(grams.formatted(.number.precision(.fractionLength(0...1)))) g")
        }
        return parts.joined(separator: " · ")
    }
}

private struct RestaurantFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var latitude: Double
    @Binding var longitude: Double
    @Binding var selectedLocationID: String
    @Binding var radius: Double
    @Binding var limit: Int
    let locationProvider: LocationProvider

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                ScreenShell {
                    LazyVStack(alignment: .leading, spacing: AppSpacing.section) {
                        SectionLabel("Location")
                        VStack(spacing: 0) {
                            HStack(alignment: .top, spacing: 16) {
                                Image(systemName: "location.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(AppPalette.green)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Location access")
                                        .font(AppTypography.bodyStrong)
                                    Text(locationProvider.authorizationDescription)
                                        .font(.subheadline)
                                        .foregroundStyle(AppPalette.muted)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, AppSpacing.rowVertical)

                            Divider().overlay(AppPalette.divider)

                            HStack(spacing: 12) {
                                Text("Search city")
                                    .font(AppTypography.bodyStrong)
                                Spacer(minLength: 12)
                                Picker("Search city", selection: $selectedLocationID) {
                                    if selectedLocationID == "current" {
                                        Text("Current location").tag("current")
                                    }
                                    ForEach(SearchCity.cities) { city in
                                        Text(city.name).tag(city.id)
                                    }
                                }
                                .labelsHidden()
                                .tint(AppPalette.green)
                                .onChange(of: selectedLocationID) { _, id in
                                    guard let city = SearchCity.cities.first(where: { $0.id == id }) else { return }
                                    latitude = city.latitude
                                    longitude = city.longitude
                                }
                            }
                            .padding(.vertical, AppSpacing.rowVertical)

                            Divider().overlay(AppPalette.divider)

                            HStack(spacing: 12) {
                                Text("Coordinates")
                                    .font(AppTypography.bodyStrong)
                                Spacer(minLength: 12)
                                Text("\(latitude.formatted(.number.precision(.fractionLength(3)))), \(longitude.formatted(.number.precision(.fractionLength(3))))")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(AppPalette.muted)
                            }
                            .padding(.vertical, AppSpacing.rowVertical)
                        }
                        .appCard()

                        Button {
                            locationProvider.requestCurrentLocation()
                        } label: {
                            Label(
                                locationProvider.isRequesting ? "Finding current location" : "Use my current location",
                                systemImage: "location.fill"
                            )
                        }
                        .buttonStyle(OutlinedButtonStyle())
                        .disabled(locationProvider.isRequesting)

                        if locationProvider.requiresSettings,
                           let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                            Button("Open location settings", systemImage: "gear") {
                                openURL(settingsURL)
                            }
                            .buttonStyle(OutlinedButtonStyle())
                        }

                        if let errorMessage = locationProvider.errorMessage {
                            ErrorNotice(error: AppLocalError(errorMessage)) {
                                locationProvider.requestCurrentLocation()
                            }
                        }

                        SectionLabel("Search radius")
                        VStack(alignment: .leading, spacing: 14) {
                            HStack {
                                Text("Nearby distance")
                                    .font(AppTypography.bodyStrong)
                                Spacer(minLength: 12)
                                Text("\((radius / 1609.344).formatted(.number.precision(.fractionLength(1)))) mi")
                                    .font(AppTypography.metric)
                                    .foregroundStyle(AppPalette.green)
                            }
                            Slider(value: $radius, in: 500...17_000, step: 500)
                                .tint(AppPalette.green)
                            Text("Search within \(Int(radius).formatted()) meters of the selected location.")
                                .font(.footnote)
                                .foregroundStyle(AppPalette.muted)
                        }
                        .appCard()

                        SectionLabel("Results")
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Maximum results")
                                    .font(AppTypography.bodyStrong)
                                Text("Up to \(limit) nearby matches")
                                    .font(.subheadline)
                                    .foregroundStyle(AppPalette.muted)
                            }
                            Spacer(minLength: 12)
                            Stepper("Maximum results", value: $limit, in: 1...100)
                                .labelsHidden()
                        }
                        .appCard()

                        PrimaryButton(title: "Apply filters") { dismiss() }
                    }
                }
                .padding(.vertical, AppSpacing.sheetTop)
            }
            .appBackground()
            .appNavigationBar("Search filters") {
                AppNavigationButton(.close, title: "Close filters") { dismiss() }
            } trailing: {
                EmptyView()
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
    }
}

private func foodNutrients(_ food: FoodSearchItem, scale: Double = 1) -> [NutrientRow] {
    [
        food.netCarbohydrates.map { .init(name: "Net carbohydrates", value: $0 * scale, unit: "g") },
        food.saturatedFat.map { .init(name: "Saturated fat", value: $0 * scale, unit: "g") },
        food.fiber.map { .init(name: "Fiber", value: $0 * scale, unit: "g") },
        food.totalSugars.map { .init(name: "Total sugars", value: $0 * scale, unit: "g") },
        food.addedSugars.map { .init(name: "Added sugars", value: $0 * scale, unit: "g") },
        food.sodium.map { .init(name: "Sodium", value: $0 * scale, unit: "mg") },
        food.potassium.map { .init(name: "Potassium", value: $0 * scale, unit: "mg") },
        food.cholesterol.map { .init(name: "Cholesterol", value: $0 * scale, unit: "mg") },
        food.glycemicIndex.map { .init(name: "Glycemic index", value: $0, unit: "") },
        food.glycemicLoad.map { .init(name: "Glycemic load", value: $0 * scale, unit: "") },
    ].compactMap { $0 }
}

private func portionNutrients(_ portion: FoodPortion) -> [NutrientRow] {
    let nutrition = portion.nutrition
    return [
        nutrition.netCarbohydrates.map { .init(name: "Net carbohydrates", value: $0.value, unit: $0.unit) },
        nutrition.saturatedFat.map { .init(name: "Saturated fat", value: $0.value, unit: $0.unit) },
        nutrition.fiber.map { .init(name: "Fiber", value: $0.value, unit: $0.unit) },
        nutrition.totalSugars.map { .init(name: "Total sugars", value: $0.value, unit: $0.unit) },
        nutrition.addedSugars.map { .init(name: "Added sugars", value: $0.value, unit: $0.unit) },
        nutrition.sodium.map { .init(name: "Sodium", value: $0.value, unit: $0.unit) },
        nutrition.potassium.map { .init(name: "Potassium", value: $0.value, unit: $0.unit) },
        nutrition.cholesterol.map { .init(name: "Cholesterol", value: $0.value, unit: $0.unit) },
        portion.glycemicIndex.map { .init(name: "Glycemic index", value: $0, unit: "") },
        portion.glycemicLoad.map { .init(name: "Glycemic load", value: $0, unit: "") },
    ].compactMap { $0 }
}

private func menuItemNutrients(_ item: RestaurantMenuItem) -> [NutrientRow] {
    [
        item.netCarbohydrates.map { .init(name: "Net carbohydrates", value: $0, unit: "g") },
        item.fiber.map { .init(name: "Fiber", value: $0, unit: "g") },
        item.totalSugars.map { .init(name: "Total sugars", value: $0, unit: "g") },
        item.addedSugars.map { .init(name: "Added sugars", value: $0, unit: "g") },
        item.glycemicIndex.map { .init(name: "Glycemic index", value: $0, unit: "") },
        item.glycemicLoad.map { .init(name: "Glycemic load", value: $0, unit: "") },
    ].compactMap { $0 }
}

#if canImport(VisionKit)
import VisionKit

private struct BarcodeScannerView: UIViewControllerRepresentable {
    let onCode: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onCode: onCode) }
    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(recognizedDataTypes: [.barcode()], qualityLevel: .balanced, recognizesMultipleItems: false, isHighFrameRateTrackingEnabled: true, isHighlightingEnabled: true)
        controller.delegate = context.coordinator
        try? controller.startScanning()
        return controller
    }
    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onCode: (String) -> Void
        init(onCode: @escaping (String) -> Void) { self.onCode = onCode }
        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            guard case .barcode(let barcode) = item, let value = barcode.payloadStringValue else { return }
            onCode(value)
        }
    }
}
#else
private struct BarcodeScannerView: View {
    let onCode: (String) -> Void
    var body: some View {
        ScreenShell {
            EmptyStateCard(
                title: "Barcode scanning unavailable",
                message: "Use a physical device with a supported camera to scan a barcode.",
                symbol: "barcode.viewfinder"
            )
        }
        .padding(.vertical, AppSpacing.sheetTop)
        .appBackground()
    }
}
#endif
