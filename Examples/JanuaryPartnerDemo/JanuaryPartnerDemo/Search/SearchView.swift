import JanuaryPartnerSDK
import SwiftUI

private struct DemoSearchCity: Identifiable, Hashable {
    let id: String
    let name: String
    let latitude: Double
    let longitude: Double

    static let cities = [
        DemoSearchCity(id: "san-francisco", name: "San Francisco, CA", latitude: 37.7749, longitude: -122.4194),
        DemoSearchCity(id: "new-york", name: "New York, NY", latitude: 40.7128, longitude: -74.0060),
        DemoSearchCity(id: "los-angeles", name: "Los Angeles, CA", latitude: 34.0522, longitude: -118.2437),
        DemoSearchCity(id: "chicago", name: "Chicago, IL", latitude: 41.8781, longitude: -87.6298),
        DemoSearchCity(id: "austin", name: "Austin, TX", latitude: 30.2672, longitude: -97.7431),
        DemoSearchCity(id: "miami", name: "Miami, FL", latitude: 25.7617, longitude: -80.1918),
        DemoSearchCity(id: "seattle", name: "Seattle, WA", latitude: 47.6062, longitude: -122.3321),
    ]
}

struct SearchView: View {
    enum Scope: String, CaseIterable { case foods = "Foods"; case restaurants = "Restaurants" }
    enum FoodMode: String, CaseIterable { case name = "Name"; case meal = "Meal description"; case barcode = "Barcode" }
    enum RestaurantMode: String, CaseIterable { case restaurants = "Restaurants"; case menuItems = "Menu items" }

    let client: JanuaryPartnerClient
    let settingsAction: () -> Void

    @AppStorage("demo.endUserID") private var endUserID = ""
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
    @State private var locationProvider = DemoLocationProvider()

    var body: some View {
        NavigationStack {
            ScrollView {
                DemoScreenShell {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        Text("Search")
                            .font(DemoTypography.screenTitle)
                            .foregroundStyle(DemoPalette.ink)

                        DemoSearchField(prompt: searchPrompt, text: queryBinding) {
                            Task { await submit() }
                        }

                        if !foodSuggestions.isEmpty {
                            foodSuggestionList
                        }

                        DemoSegmentedControl(Scope.allCases, selection: $scope) { $0.rawValue }
                            .onChange(of: scope) { _, _ in resetResults() }

                        if scope == .foods { foodContent } else { restaurantContent }
                    }
                }
                .padding(.vertical, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .demoBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
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
        case .general: "general"
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
        case .general: .general
        case .branded: .branded
        case .recipe, nil: nil
        }
    }

    private var canAutocomplete: Bool {
        scope == .foods && foodMode == .name && category != .recipe
    }

    private var foodSuggestionList: some View {
        VStack(spacing: 0) {
            ForEach(Array(foodSuggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    autocompleteSuppressedQuery = suggestion.name
                    query = suggestion.name
                    foodSuggestions = []
                    Task { await submit() }
                } label: {
                    HStack {
                        Text(suggestion.name)
                            .font(.body.weight(.medium))
                            .foregroundStyle(DemoPalette.ink)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 12)
                    }
                    .contentShape(Rectangle())
                    .frame(minHeight: 48)
                }
                .buttonStyle(.plain)

                if index < foodSuggestions.count - 1 {
                    Divider().overlay(DemoPalette.divider)
                }
            }
        }
        .demoCard()
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
        DemoSegmentedControl(FoodMode.allCases, selection: $foodMode) { mode in
            mode == .meal ? "Description" : mode.rawValue
        }
        .onChange(of: foodMode) { _, _ in resetResults() }

        if foodMode == .name {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    categoryChip("All", category: nil)
                    categoryChip("General", category: .general)
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
            .buttonStyle(.bordered)
        } else {
            Text("Try “a bowl of oatmeal with honey and a banana.”")
                .font(.subheadline)
                .foregroundStyle(DemoPalette.muted)
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
            NaturalMealResultView(result: naturalResult)
        } else if !foodResults.isEmpty {
            DemoFillWidth {
                HStack(alignment: .firstTextBaseline) {
                    DemoSectionLabel("Results · January food database")
                    Spacer(minLength: 12)
                    Menu {
                        ForEach([10, 20, 40], id: \.self) { limit in
                            Button("\(limit) results") { foodResultLimit = limit }
                        }
                    } label: {
                        Text("\(foodResults.count)")
                            .font(.system(size: 14, weight: .semibold, design: .monospaced))
                            .foregroundStyle(DemoPalette.muted)
                    }
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(foodResults.enumerated()), id: \.element.id) { index, food in
                    NavigationLink {
                        FoodDetailView(client: client, food: food, endUserID: DemoFormatting.endUserID(endUserID))
                    } label: {
                        DemoFoodRow(food: food)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if index < foodResults.count - 1 {
                        Divider().overlay(DemoPalette.divider)
                    }
                }
            }
            .demoCard()
        } else if !isLoading, error == nil, !query.isEmpty {
            ContentUnavailableView("No foods found", systemImage: "magnifyingglass", description: Text("Try a different search."))
        }
    }

    @ViewBuilder
    private var restaurantContent: some View {
        DemoSegmentedControl(RestaurantMode.allCases, selection: $restaurantMode) { $0.rawValue }
        .onChange(of: restaurantMode) { _, _ in resetResults() }

        Button { isShowingFilters = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "location.fill")
                    .foregroundStyle(DemoPalette.green)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Search location")
                        .font(.headline)
                    Text(locationSummary)
                        .font(.caption)
                        .foregroundStyle(DemoPalette.muted)
                        .monospacedDigit()
                }
                Spacer(minLength: 8)
                Text("\(radius / 1609.344, format: .number.precision(.fractionLength(1))) mi")
                    .font(.subheadline)
                    .monospacedDigit()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(DemoPalette.body)
        }
        .demoCard()

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
                        menuQuery: query,
                        endUserID: DemoFormatting.endUserID(endUserID)
                    )
                } label: {
                    RestaurantRow(restaurant: restaurant).demoCard()
                }
                .buttonStyle(.plain)
            }
        } else if restaurantMode == .menuItems, !menuItems.isEmpty {
            Text("Nearby menu items").font(.system(.title3, design: .serif, weight: .semibold))
            ForEach(menuItems, id: \.id) { item in
                NavigationLink { RestaurantMenuItemDetailView(item: item) } label: {
                    MenuItemRow(item: item).demoCard()
                }
                .buttonStyle(.plain)
            }
        } else if !isLoading, error == nil, !query.isEmpty {
            ContentUnavailableView("No nearby matches", systemImage: "mappin.slash", description: Text("Try another name, location, or radius."))
        }
    }

    private var locationSummary: String {
        if selectedLocationID == "current", let location = locationProvider.location {
            return "Current location · \(location.coordinateDescription)"
        }
        let city = DemoSearchCity.cities.first { $0.id == selectedLocationID } ?? DemoSearchCity.cities[0]
        return "Preset city · \(city.name)"
    }

    private var submitButton: some View {
        Button {
            Task { await submit() }
        } label: {
            if isLoading { ProgressView().tint(DemoPalette.ink) } else { Text(buttonTitle) }
        }
        .buttonStyle(DemoPrimaryButtonStyle())
        .disabled(isLoading)
    }

    private var buttonTitle: String {
        if scope == .restaurants { return "Search nearby" }
        switch foodMode { case .name: return "Search foods"; case .meal: return "Parse meal"; case .barcode: return "Look up barcode" }
    }

    @ViewBuilder
    private var requestState: some View {
        if let error { DemoErrorNotice(error: error) { Task { await submit() } } }
    }

    private func categoryChip(_ label: String, category value: FoodCategory?) -> some View {
        Button(label) { category = value }
            .buttonStyle(DemoChipButtonStyle(isSelected: category == value))
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
            let userID = DemoFormatting.endUserID(endUserID)
            if scope == .foods {
                switch foodMode {
                case .name:
                    foodResults = try await client.foods.search(.init(query: value, category: category, limit: Double(foodResultLimit), endUserID: userID)).items
                case .meal:
                    naturalResult = try await client.photoScanning.searchByNaturalLanguage(.init(query: value, endUserID: userID))
                case .barcode:
                    foodResults = try await client.foods.lookupByBarcode(.init(upc: value, endUserID: userID)).items
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
            try await Task.sleep(for: .milliseconds(300))
            try Task.checkCancellation()
            let response = try await client.foods.autocomplete(
                .init(
                    query: value,
                    category: autocompleteCategory,
                    limit: 8,
                    endUserID: DemoFormatting.endUserID(endUserID)
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
}

private struct SearchPromptCard: View {
    let title: String
    let message: String
    let symbol: String

    var body: some View {
        DemoEmptyStateCard(
            title: title,
            message: message,
            symbol: symbol == "fork.knife" ? "Sr" : symbol,
            usesSerifSymbol: symbol == "fork.knife"
        )
    }
}

private struct NaturalMealResultView: View {
    let result: FoodScan

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Meal nutrition").font(.system(.title2, design: .serif, weight: .semibold))
            if let nutrients = result.totalNutrients {
                DemoMacroStrip(
                    calories: nutrients.calories?.value,
                    protein: nutrients.protein?.value,
                    carbohydrates: nutrients.carbohydrates?.value,
                    fat: nutrients.totalFat?.value
                )
                .demoCard()
            }
            ForEach(Array(result.detections.enumerated()), id: \.offset) { _, detection in
                VStack(alignment: .leading, spacing: 10) {
                    Text(detection.food.name).font(.headline)
                    if let brand = detection.food.brandName { Text(brand).foregroundStyle(DemoPalette.muted) }
                    DemoMacroStrip(
                        calories: detection.food.nutrients.calories?.value,
                        protein: detection.food.nutrients.protein?.value,
                        carbohydrates: detection.food.nutrients.carbohydrates?.value,
                        fat: detection.food.nutrients.totalFat?.value
                    )
                }
                .demoCard()
            }
        }
    }
}

struct FoodDetailView: View {
    let client: JanuaryPartnerClient
    let food: FoodSearchItem
    let endUserID: PartnerUserID?
    @State private var detailFood: FoodSearchItem
    @State private var selectedServingID: ServingID
    @State private var quantity = 1.0
    @State private var isShowingAlternatives = false
    @State private var isShowingGlucose = false
    @State private var detailLoadError: Error?

    init(client: JanuaryPartnerClient, food: FoodSearchItem, endUserID: PartnerUserID?) {
        self.client = client; self.food = food; self.endUserID = endUserID
        let initialServing = food.servings.first(where: \.isPrimary) ?? food.servings.first
        _detailFood = State(initialValue: food)
        _selectedServingID = State(initialValue: initialServing?.id ?? ServingID(rawValue: 0))
        _quantity = State(initialValue: initialServing?.quantity ?? 1)
    }

    var body: some View {
        ScrollView {
            DemoScreenShell {
                VStack(alignment: .leading, spacing: 18) {
                DemoFillWidth {
                    ZStack {
                        DemoPalette.control
                        AsyncImage(url: detailFood.photoURL.flatMap(URL.init(string:))) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Image(systemName: "fork.knife")
                                .font(.system(size: 44))
                                .foregroundStyle(DemoPalette.green)
                        }
                    }
                }
                .frame(height: 220)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))

                VStack(alignment: .leading, spacing: 5) {
                    Text(detailFood.name).font(.system(.largeTitle, design: .serif, weight: .bold))
                    if let brand = detailFood.brandName { Text(brand).foregroundStyle(DemoPalette.muted) }
                }

                if !detailFood.servings.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Menu {
                            ForEach(detailFood.servings, id: \.id) { serving in
                                Button {
                                    selectedServingID = serving.id
                                    quantity = serving.quantity
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
                                        .foregroundStyle(DemoPalette.muted)
                                    Text(selectedServing.map(servingLabel) ?? "Choose a serving")
                                        .font(.headline)
                                        .foregroundStyle(DemoPalette.green)
                                }
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(DemoPalette.green)
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
                    .demoCard()
                }

                DemoMacroStrip(
                    calories: portion?.nutrition.calories?.value,
                    protein: portion?.nutrition.protein?.value,
                    carbohydrates: portion?.nutrition.carbohydrates?.value,
                    fat: portion?.nutrition.totalFat?.value
                )
                    .demoCard()

                let rows = portion.map(portionNutrients) ?? []
                if !rows.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Nutrition facts").font(.system(.title2, design: .serif, weight: .semibold))
                        DemoNutritionList(rows: rows)
                    }
                    .demoCard()
                }

                Button {
                    isShowingGlucose = true
                } label: {
                    Label("Check glucose", systemImage: "waveform.path.ecg")
                }
                .buttonStyle(DemoPrimaryButtonStyle())
                .disabled(selectedServing == nil)

                Button("Find alternatives") { isShowingAlternatives = true }
                    .buttonStyle(DemoPrimaryButtonStyle())

                DisclosureGroup("Technical details") {
                    LabeledContent("Food ID", value: "\(detailFood.id.rawValue)")
                    LabeledContent("Serving ID", value: "\(selectedServingID.rawValue)")
                }
                .font(.footnote)
                if detailLoadError != nil {
                    Text("Complete serving details could not be loaded. Showing the serving returned by search.")
                        .font(.footnote)
                        .foregroundStyle(DemoPalette.muted)
                }
                }
            }
            .padding(.vertical, 16)
        }
        .demoBackground()
        .navigationTitle("Food details")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: food.id) { await loadFullFood() }
        .sheet(isPresented: $isShowingAlternatives) {
            AlternativesView(client: client, food: detailFood, endUserID: endUserID)
        }
        .sheet(isPresented: $isShowingGlucose) {
            if let selectedServing {
                FoodGlucoseSheet(
                    client: client,
                    food: detailFood,
                    serving: selectedServing,
                    quantity: quantity,
                    endUserID: endUserID
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
        var parts = [serving.unit]
        if let grams = serving.weightGrams {
            parts.append("\(grams.formatted(.number.precision(.fractionLength(0...1)))) g")
        }
        return parts.joined(separator: " · ")
    }

    @MainActor
    private func loadFullFood() async {
        do {
            let fullFood = try await client.foods.getFood(.init(foodID: food.id, endUserID: endUserID))
            detailFood = fullFood
            let initialServing = fullFood.servings.first(where: \.isPrimary) ?? fullFood.servings.first
            if let initialServing {
                selectedServingID = initialServing.id
                quantity = initialServing.quantity
            }
            detailLoadError = nil
        } catch {
            detailLoadError = error
        }
    }
}

private struct FoodGlucoseSheet: View {
    let client: JanuaryPartnerClient
    let food: FoodSearchItem
    let serving: ServingOption
    let quantity: Double
    let endUserID: PartnerUserID?

    @Environment(\.dismiss) private var dismiss
    @AppStorage("demo.timezone") private var timezone = TimeZone.current.identifier
    @State private var prediction: GlucosePrediction?
    @State private var isLoading = false
    @State private var error: Error?

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
                DemoScreenShell {
                    VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(food.name)
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(DemoPalette.ink)
                        Text("\(quantity.formatted(.number.precision(.fractionLength(0...2)))) \(serving.unit)")
                            .font(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(DemoPalette.muted)
                    }

                    if isLoading {
                        HStack(spacing: 0) {
                            Spacer(minLength: 0)
                            VStack(spacing: 14) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Predicting your glucose response…")
                                .font(.headline)
                            Text("This usually takes a few seconds.")
                                .font(.subheadline)
                                .foregroundStyle(DemoPalette.muted)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 42)
                        .demoCard()
                    } else if let error {
                        DemoErrorNotice(error: error) {
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
                            .foregroundStyle(DemoPalette.muted)
                    }
                    .demoCard()

                    Text("This is an estimate for demonstration purposes, not medical advice.")
                        .font(.footnote)
                        .foregroundStyle(DemoPalette.muted)
                    }
                }
                .padding(.vertical, 16)
            }
            .demoBackground()
            .navigationTitle("Glucose response")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task {
                guard prediction == nil, !isLoading else { return }
                await predict()
            }
        }
    }

    @ViewBuilder
    private func predictionContent(_ prediction: GlucosePrediction) -> some View {
        let points = prediction.curve.compactMap { point -> DemoChartPoint? in
            guard point.count >= 2 else { return nil }
            return DemoChartPoint(minutes: point[0], value: point[1])
        }

        HStack {
            Label(impactLabel(prediction.scoring), systemImage: "waveform.path.ecg")
                .font(.headline)
                .foregroundStyle(impactColor(prediction.scoring))
            Spacer()
            Text("Estimated impact")
                .font(.subheadline)
                .foregroundStyle(DemoPalette.muted)
        }
        .demoCard()

        DemoPredictionChart(
            points: points,
            lowerBound: prediction.minimum,
            upperBound: prediction.maximum,
            lineColor: prediction.scoring == .lowImpact ? DemoPalette.green : DemoPalette.rust
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
        .demoCard()
    }

    private func glucoseMetric(_ title: String, value: Double?, unit: String) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DemoPalette.muted)
            if let value {
                Text("\(value.formatted(.number.precision(.fractionLength(0...1))))\(unit.isEmpty ? "" : " \(unit)")")
                    .font(.system(.headline, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(DemoPalette.ink)
            } else {
                Text("—")
                    .font(.headline)
                    .foregroundStyle(DemoPalette.muted)
            }
            }
            Spacer(minLength: 0)
        }
        .demoCard()
    }

    @MainActor
    private func predict() async {
        isLoading = true
        error = nil
        do {
            prediction = try await client.glucose.predict(.init(
                userProfile: profile,
                foods: [FoodSelection(
                    id: food.id,
                    serving: ServingSelection(id: serving.id, quantity: quantity)
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
        if impact == .lowImpact { return DemoPalette.green }
        if impact == .mediumImpact { return DemoPalette.yellow }
        if impact == .highImpact { return DemoPalette.rust }
        return DemoPalette.muted
    }
}

private struct AlternativesView: View {
    let client: JanuaryPartnerClient
    let food: FoodSearchItem
    let endUserID: PartnerUserID?
    @Environment(\.dismiss) private var dismiss
    @State private var restrictions: Set<DietRestriction> = []
    @State private var preferences: Set<DietPreference> = []
    @State private var result: SuggestFoodAlternativesResponse?
    @State private var error: Error?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                DemoScreenShell {
                    VStack(alignment: .leading, spacing: 18) {
                    Text("Dietary restrictions").font(.headline)
                    FlowChoiceGrid(values: DietRestriction.allCases, selected: $restrictions)
                    Text("Dietary preferences").font(.headline)
                    FlowChoiceGrid(values: DietPreference.allCases, selected: $preferences)

                    Button { Task { await load() } } label: {
                        if isLoading { ProgressView().tint(DemoPalette.ink) } else { Text("Find alternatives") }
                    }
                    .buttonStyle(DemoPrimaryButtonStyle())

                    if let error { DemoErrorNotice(error: error) { Task { await load() } } }
                    if let result {
                        if result.alternatives.isEmpty {
                            ContentUnavailableView("No suitable alternatives", systemImage: "leaf", description: Text("No alternatives matched these choices."))
                        } else {
                            ForEach(Array(result.alternatives.enumerated()), id: \.offset) { _, alternative in
                                Group {
                                    if let detailFood = alternativeDetailFood(alternative.food) {
                                        NavigationLink {
                                            FoodDetailView(client: client, food: detailFood, endUserID: endUserID)
                                        } label: {
                                            AlternativeFoodRow(food: alternative.food, isInteractive: true)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        AlternativeFoodRow(food: alternative.food, isInteractive: false)
                                    }
                                }
                                .demoCard()
                            }
                        }
                    }
                    }
                }
                .padding(.vertical, 16)
            }
            .demoBackground()
            .navigationTitle("Alternatives")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
        }
    }

    @MainActor private func load() async {
        isLoading = true; error = nil
        do {
            result = try await client.foods.suggestAlternatives(.init(
                foodID: food.id,
                dietRestrictions: Array(restrictions),
                dietPreferences: Array(preferences),
                endUserID: endUserID
            ))
        } catch { self.error = error }
        isLoading = false
    }
}

private struct AlternativeFoodRow: View {
    let food: DetectedFood
    let isInteractive: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(DemoPalette.green.opacity(0.12))
                Image(systemName: "leaf.fill")
                    .font(.title3)
                    .foregroundStyle(DemoPalette.green)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(food.name)
                        .font(.headline)
                        .foregroundStyle(DemoPalette.ink)
                    if let brand = food.brandName, !brand.isEmpty {
                        Text(brand)
                            .font(.subheadline)
                            .foregroundStyle(DemoPalette.muted)
                    }
                    if let serving = food.servings?.first {
                        Text("\((serving.quantity ?? 1).formatted(.number.precision(.fractionLength(0...2)))) \(serving.unit)")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(DemoPalette.muted)
                    }
                }

                HStack(spacing: 7) {
                    nutrientPill("cal", food.nutrients.calories?.value)
                    nutrientPill("P", food.nutrients.protein?.value)
                    nutrientPill("C", food.nutrients.carbohydrates?.value)
                    nutrientPill("F", food.nutrients.totalFat?.value)
                }
            }

            Spacer(minLength: 4)
            if isInteractive {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .padding(.top, 20)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint(isInteractive ? "Opens food details" : "Details are unavailable for this result")
    }

    private func nutrientPill(_ label: String, _ value: Double?) -> some View {
        Group {
            if let value {
                Text(label == "cal"
                     ? "\(value.formatted(.number.precision(.fractionLength(0)))) cal"
                     : "\(label) \(value.formatted(.number.precision(.fractionLength(0...1))))g")
            }
        }
        .font(.system(.caption2, design: .monospaced, weight: .medium))
        .monospacedDigit()
        .foregroundStyle(DemoPalette.body)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(DemoPalette.control, in: Capsule())
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
                Button(value.rawValue) { toggle(value) }
                    .buttonStyle(.borderedProminent)
                    .tint(selected.contains(value) ? DemoPalette.green : DemoPalette.control)
                    .foregroundStyle(selected.contains(value) ? .white : DemoPalette.body)
            }
        }
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
            Image(systemName: "fork.knife.circle.fill").font(.title).foregroundStyle(DemoPalette.green)
            VStack(alignment: .leading, spacing: 4) {
                Text(restaurant.name).font(.headline)
                Text([restaurant.city, restaurant.distance.map { "\(($0 / 1609.344).formatted(.number.precision(.fractionLength(1)))) mi" }].compactMap { $0 }.joined(separator: " · "))
                    .font(.subheadline).foregroundStyle(DemoPalette.muted)
            }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
    }
}

private struct MenuItemRow: View {
    let item: RestaurantMenuItem
    var body: some View {
        HStack(spacing: 12) {
            AsyncImage(url: item.photoURL.flatMap(URL.init(string:))) { $0.resizable().scaledToFill() } placeholder: { Image(systemName: "takeoutbag.and.cup.and.straw") }
                .frame(width: 56, height: 56).background(DemoPalette.control).clipShape(RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.name).font(.headline)
                Text(item.restaurantName).foregroundStyle(DemoPalette.muted)
                if let calories = item.calories { Text("\(calories.formatted(.number.precision(.fractionLength(0)))) cal").font(.caption) }
            }
            Spacer(); Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
    }
}

private struct RestaurantDetailView: View {
    let client: JanuaryPartnerClient
    let restaurant: Restaurant
    let latitude: Double
    let longitude: Double
    let radius: Double
    let resultLimit: Int
    let menuQuery: String
    let endUserID: PartnerUserID?

    @State private var menuItems: [RestaurantMenuItem] = []
    @State private var isLoadingMenu = false
    @State private var menuError: Error?

    var body: some View {
        ScrollView {
            DemoScreenShell {
                VStack(alignment: .leading, spacing: 20) {
                    Text(restaurant.name)
                        .font(.system(.largeTitle, design: .serif, weight: .bold))
                        .foregroundStyle(DemoPalette.ink)

                    VStack(alignment: .leading, spacing: 12) {
                        DemoSectionLabel("Location")
                        if let city = restaurant.city { LabeledContent("City", value: city) }
                        if let address = restaurant.address1 { Text(address) }
                        if let address = restaurant.address2 { Text(address) }
                        if let distance = restaurant.distance {
                            Divider().overlay(DemoPalette.divider)
                            LabeledContent("Distance", value: "\((distance / 1609.344).formatted(.number.precision(.fractionLength(1)))) mi")
                                .monospacedDigit()
                        }
                    }
                    .demoCard()

                    VStack(alignment: .leading, spacing: 12) {
                        DemoSectionLabel("Menu items")
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
        .demoBackground()
        .navigationTitle("Restaurant")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: restaurant.id) { await loadMenuItems() }
    }

    @ViewBuilder
    private var menuContent: some View {
        if isLoadingMenu {
            HStack {
                Spacer(minLength: 0)
                ProgressView("Loading menu")
                Spacer(minLength: 0)
            }
            .demoCard()
        } else if let menuError {
            DemoErrorNotice(error: menuError) { Task { await loadMenuItems() } }
        } else if menuItems.isEmpty {
            DemoEmptyStateCard(
                title: "No menu items found",
                message: "January did not return menu items for this restaurant.",
                symbol: "fork.knife"
            )
        } else {
            VStack(spacing: 0) {
                ForEach(Array(menuItems.enumerated()), id: \.element.id) { index, item in
                    NavigationLink {
                        RestaurantMenuItemDetailView(item: item)
                    } label: {
                        MenuItemRow(item: item)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                    if index < menuItems.count - 1 {
                        Divider().overlay(DemoPalette.divider)
                    }
                }
            }
            .demoCard()
        }
    }

    @MainActor
    private func loadMenuItems() async {
        isLoadingMenu = true
        menuError = nil
        do {
            let response = try await client.restaurants.searchMenuItems(.init(
                query: menuQuery,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                limit: resultLimit,
                endUserID: endUserID
            ))
            let selectedRestaurantName = normalizedRestaurantName(restaurant.name)
            menuItems = response.items.filter {
                let itemRestaurantName = normalizedRestaurantName($0.restaurantName)
                return itemRestaurantName.contains(selectedRestaurantName)
                    || selectedRestaurantName.contains(itemRestaurantName)
            }
        } catch {
            menuError = error
        }
        isLoadingMenu = false
    }

    private func normalizedRestaurantName(_ value: String) -> String {
        let baseName = value.split(separator: "(", maxSplits: 1).first.map(String.init) ?? value
        return baseName
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

private struct RestaurantMenuItemDetailView: View {
    let item: RestaurantMenuItem
    var body: some View {
        ScrollView {
            DemoScreenShell {
                VStack(alignment: .leading, spacing: 18) {
                Text(item.name).font(.system(.largeTitle, design: .serif, weight: .bold))
                Text(item.restaurantName).foregroundStyle(DemoPalette.muted)
                DemoMacroStrip(calories: item.calories, protein: item.protein, carbohydrates: item.carbohydrates, fat: item.totalFat).demoCard()
                DemoNutritionList(rows: menuItemNutrients(item)).demoCard()
                if !item.servings.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Servings").font(.headline)
                        ForEach(item.servings, id: \.id) { Text("\($0.quantity.formatted()) \($0.unit)") }
                    }.demoCard()
                }
                DisclosureGroup("Technical details") { LabeledContent("Menu item ID", value: item.id) }.font(.footnote)
                }
            }
            .padding(.vertical, 16)
        }.demoBackground().navigationTitle("Menu item").navigationBarTitleDisplayMode(.inline)
    }
}

private struct RestaurantFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var latitude: Double
    @Binding var longitude: Double
    @Binding var selectedLocationID: String
    @Binding var radius: Double
    @Binding var limit: Int
    let locationProvider: DemoLocationProvider

    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            DemoScreenShell {
                Form {
                Section("Location") {
                    LabeledContent("Status", value: locationProvider.authorizationDescription)

                    Picker("City", selection: $selectedLocationID) {
                        if selectedLocationID == "current" {
                            Text("Current location").tag("current")
                        }
                        ForEach(DemoSearchCity.cities) { city in
                            Text(city.name).tag(city.id)
                        }
                    }
                    .onChange(of: selectedLocationID) { _, id in
                        guard let city = DemoSearchCity.cities.first(where: { $0.id == id }) else { return }
                        latitude = city.latitude
                        longitude = city.longitude
                    }

                    LabeledContent("Coordinates") {
                        Text("\(latitude.formatted(.number.precision(.fractionLength(4)))), \(longitude.formatted(.number.precision(.fractionLength(4))))")
                            .monospacedDigit()
                    }

                    Button {
                        locationProvider.requestCurrentLocation()
                    } label: {
                        if locationProvider.isRequesting {
                            Label("Finding current location", systemImage: "location.fill")
                        } else {
                            Label("Use my current location", systemImage: "location.fill")
                        }
                    }
                    .disabled(locationProvider.isRequesting)

                    if locationProvider.requiresSettings,
                       let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        Button("Open location settings", systemImage: "gear") {
                            openURL(settingsURL)
                        }
                    }

                    if let errorMessage = locationProvider.errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(DemoPalette.rust)
                    }
                }

                Section("Radius") {
                    Slider(value: $radius, in: 500...17_000, step: 500)
                    LabeledContent("Distance", value: "\((radius / 1609.344).formatted(.number.precision(.fractionLength(1)))) mi · \(Int(radius)) m")
                }
                Section("Results") { Stepper("Limit: \(limit)", value: $limit, in: 1...100) }
                }
            }
            .navigationTitle("Search filters").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

private func foodNutrients(_ food: FoodSearchItem, scale: Double = 1) -> [DemoNutrientRow] {
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

private func portionNutrients(_ portion: FoodPortion) -> [DemoNutrientRow] {
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

private func menuItemNutrients(_ item: RestaurantMenuItem) -> [DemoNutrientRow] {
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
    var body: some View { ContentUnavailableView("Barcode scanning unavailable", systemImage: "barcode.viewfinder") }
}
#endif
