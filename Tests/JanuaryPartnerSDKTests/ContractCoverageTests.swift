import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
@testable import JanuaryPartnerSDK

private struct ProbeRequest: Sendable {
    let operationID: String
    let path: String
    let headers: HTTPFields
    let body: Data?
}

private actor ContractProbeTransport: ClientTransport {
    private let responses: [String: String]
    private var recorded: [ProbeRequest] = []

    init(responses: [String: String] = [:]) {
        self.responses = responses
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let data: Data? = if let body {
            try await Data(collecting: body, upTo: 6_000_000)
        } else {
            nil
        }
        recorded.append(
            ProbeRequest(
                operationID: operationID,
                path: request.path ?? "",
                headers: request.headerFields,
                body: data
            )
        )
        var response = HTTPResponse(status: .ok)
        response.headerFields[.contentType] = "application/json"
        let json = responses[operationID] ?? Self.defaultResponse(for: operationID)
        return (response, HTTPBody(json))
    }

    func requests() -> [ProbeRequest] { recorded }

    private static func defaultResponse(for operationID: String) -> String {
        switch operationID {
        case "searchFoods", "lookupFoodByBarcode", "searchRestaurants", "searchRestaurantMenuItems":
            #"{"total_count":0,"items":[]}"#
        case "searchFoodsByNaturalLanguage", "scanFoodPhoto", "correctPhotoScan":
            #"{"detections":[]}"#
        case "suggestFoodAlternatives":
            #"{"alternatives":[]}"#
        case "createFoodLog", "updateFoodLog":
            #"{"id":"00000000-0000-0000-0000-000000000001","foods":[],"timestamp_utc":"2026-08-23T12:00:00Z"}"#
        case "listFoodLogs":
            #"{"total_count":0,"items":[]}"#
        case "deleteFoodLog":
            #"{"status":"deleted"}"#
        case "predictGlucose":
            #"{"prediction":[{"minutes":0,"value":100}],"impact_score":"low","chart":{"min":70,"max":140}}"#
        default:
            #"{}"#
        }
    }
}

private func probeClient(_ transport: any ClientTransport) throws -> JanuaryPartnerClient {
    try JanuaryPartnerClient(
        developmentAPIKey: "fixture-api-key",
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport
    )
}

@Test(arguments: ["12345", "123456789012345", "12345A", "１２３４５６"])
func barcodeRejectsValuesOutsideTheDocumentedASCIIFormat(_ upc: String) async throws {
    let transport = ContractProbeTransport()
    let client = try probeClient(transport)

    await #expect(throws: JanuaryError.self) {
        _ = try await client.foods.lookupByBarcode(.init(upc: upc))
    }
    #expect(await transport.requests().isEmpty)
}

@Test(arguments: ["000001", "049000006346", "00000000000000"])
func barcodeAcceptsDocumentedLengthsAndPreservesLeadingZeroes(_ upc: String) async throws {
    let transport = ContractProbeTransport()
    let client = try probeClient(transport)

    _ = try await client.foods.lookupByBarcode(.init(upc: upc))

    let request = try #require(await transport.requests().first)
    #expect(request.path == "/v1.2/foods/barcode/\(upc)")
}

@Test(arguments: ["", String(repeating: "a", count: 513)])
func naturalLanguageSearchRejectsInvalidQueryLengths(_ query: String) async throws {
    let transport = ContractProbeTransport()
    let client = try probeClient(transport)

    await #expect(throws: JanuaryError.self) {
        _ = try await client.photoScanning.searchByNaturalLanguage(.init(query: query))
    }
    #expect(await transport.requests().isEmpty)
}

@Test
func alternativesAcceptEmptyPreferenceArrays() async throws {
    let transport = ContractProbeTransport()
    let client = try probeClient(transport)

    _ = try await client.foods.suggestAlternatives(
        .init(foodID: .init(rawValue: 1), dietRestrictions: [], dietPreferences: [])
    )
    #expect(await transport.requests().count == 1)
}

@Test(arguments: [
    SearchRestaurantsRequest(query: "", latitude: 0, longitude: 0),
    SearchRestaurantsRequest(query: String(repeating: "a", count: 257), latitude: 0, longitude: 0),
    SearchRestaurantsRequest(query: "cafe", latitude: -91, longitude: 0),
    SearchRestaurantsRequest(query: "cafe", latitude: 0, longitude: 181),
    SearchRestaurantsRequest(query: "cafe", latitude: 0, longitude: 0, radius: 0),
    SearchRestaurantsRequest(query: "cafe", latitude: 0, longitude: 0, radius: 17_001),
    SearchRestaurantsRequest(query: "cafe", latitude: 0, longitude: 0, limit: 0),
    SearchRestaurantsRequest(query: "cafe", latitude: 0, longitude: 0, limit: 101),
])
func restaurantSearchRejectsDocumentedOutOfRangeParameters(_ request: SearchRestaurantsRequest) async throws {
    let transport = ContractProbeTransport()
    let client = try probeClient(transport)

    await #expect(throws: JanuaryError.self) {
        _ = try await client.restaurants.search(request)
    }
    #expect(await transport.requests().isEmpty)
}

@Test
func documentedEnumValuesRoundTripOnTheWire() throws {
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()

    let categories = FoodCategory.allCases
    #expect(categories.map(\.rawValue) == ["general", "branded", "recipe"])
    for value in categories {
        #expect(try decoder.decode(FoodCategory.self, from: encoder.encode(value)) == value)
    }

    let restrictions = DietRestriction.allCases
    #expect(restrictions.map(\.rawValue) == [
        "gluten", "lactose", "yeast", "tree_nuts", "peanuts", "dairy", "eggs",
        "sulfites", "soy", "wheat", "shellfish", "fish", "mushrooms", "sesame",
        "msg", "caffeine", "fodmaps",
    ])
    for value in restrictions {
        #expect(try decoder.decode(DietRestriction.self, from: encoder.encode(value)) == value)
    }

    let preferences = DietPreference.allCases
    #expect(preferences.map(\.rawValue) == [
        "vegetarian", "vegan", "keto", "paleo", "pescatarian",
        "low_carbohydrate", "high_protein", "kosher", "halal",
    ])
    for value in preferences {
        #expect(try decoder.decode(DietPreference.self, from: encoder.encode(value)) == value)
    }

    #expect(RestaurantResultType.restaurant.rawValue == "restaurant")
    #expect(RestaurantResultType.menuItem.rawValue == "menu_item")
    #expect(ConfidenceScore.allCases.map(\.rawValue) == ["high", "medium", "low"])
    #expect(Sex.male.rawValue == "male")
    #expect(Sex.female.rawValue == "female")
    #expect(ActivityLevel.sedentary.rawValue == "sedentary")
    #expect(ActivityLevel.lightlyActive.rawValue == "lightly_active")
    #expect(ActivityLevel.moderatelyActive.rawValue == "moderately_active")
    #expect(ActivityLevel.veryActive.rawValue == "very_active")
    #expect(MedicalCondition.type2Diabetes.rawValue == "type_2_diabetes")
    #expect(MedicalCondition.prediabetes.rawValue == "prediabetes")
    #expect(GlucoseImpact.lowImpact.rawValue == "low")
    #expect(GlucoseImpact.mediumImpact.rawValue == "medium")
    #expect(GlucoseImpact.highImpact.rawValue == "high")
}

@Test
func foodLogCreateSendsAuthenticationUserTimezoneAndDocumentedBody() async throws {
    let response = #"{"id":"00000000-0000-0000-0000-000000000001","foods":[],"timestamp_utc":"2026-08-23T12:00:00Z","name":"Lunch"}"#
    let transport = ContractProbeTransport(responses: ["createFoodLog": response])
    let client = try probeClient(transport)
    let user = FoodLogUserContext(endUserID: .init(rawValue: "fixture-user"), timezone: "America/New_York")

    _ = try await client.foodLogs.create(
        .init(
            foods: [.init(id: .init(rawValue: 42), serving: .init(id: .init(rawValue: 7), quantity: 1.5))],
            timestampUTC: "2026-08-23T12:00:00Z",
            name: "Lunch",
            user: user
        )
    )

    let request = try #require(await transport.requests().first)
    #expect(request.operationID == "createFoodLog")
    #expect(request.path == "/v1.2/food-logs")
    #expect(request.headers[.authorization] == "Bearer fixture-api-key")
    #expect(request.headers[HTTPField.Name("x-end-user-id")!] == "fixture-user")
    #expect(request.headers[HTTPField.Name("x-end-user-timezone")!] == "America/New_York")
    let body = try #require(request.body)
    let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
    #expect(json["timestamp_utc"] as? String == "2026-08-23T12:00:00Z")
    #expect(json["name"] as? String == "Lunch")
    let foods = try #require(json["foods"] as? [[String: Any]])
    #expect(foods.first?["id"] as? Int == 42)
    let serving = try #require(foods.first?["serving"] as? [String: Any])
    #expect(serving["id"] as? Int == 7)
    #expect(serving["quantity"] as? Double == 1.5)
}

@Test
func documentedHTTPStatusesMapToPublicErrorCategories() {
    #expect(errorCategory(for: 400) == .validation)
    #expect(errorCategory(for: 401) == .authentication)
    #expect(errorCategory(for: 403) == .authorization)
    #expect(errorCategory(for: 404) == .notFound)
    #expect(errorCategory(for: 429) == .rateLimited)
    #expect(errorCategory(for: 500) == .server)
    #expect(errorCategory(for: 504) == .timeout)
    #expect(errorCategory(for: 422) == .validation)
    #expect(errorCategory(for: 418) == .transport)
}

private enum FailureMode: Sendable {
    case status(Int, String)
    case cancellation
    case january
    case decoding
    case timeout
    case transport
}

private struct FixtureTransportError: Error {}

private actor FailureTransport: ClientTransport {
    let mode: FailureMode

    init(_ mode: FailureMode) { self.mode = mode }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        switch mode {
        case .status(let code, let json):
            var response = HTTPResponse(status: .init(code: code))
            response.headerFields[.contentType] = "application/json"
            return (response, HTTPBody(json))
        case .cancellation:
            throw CancellationError()
        case .january:
            throw JanuaryError(category: .authorization, message: "fixture")
        case .decoding:
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "fixture"))
        case .timeout:
            throw URLError(.timedOut)
        case .transport:
            throw FixtureTransportError()
        }
    }
}

@Test
func transportFailuresMapToStablePublicErrors() async throws {
    let modes: [(FailureMode, ErrorCategory)] = [
        (.january, .authorization),
        (.decoding, .decoding),
        (.timeout, .timeout),
        (.transport, .transport),
    ]
    for (mode, expected) in modes {
        let client = try probeClient(FailureTransport(mode))
        do {
            _ = try await client.foods.lookupByBarcode(.init(upc: "049000006346"))
            Issue.record("Expected request to fail")
        } catch let error as JanuaryError {
            #expect(error.category == expected)
        }
    }

    let cancelled = try probeClient(FailureTransport(.cancellation))
    await #expect(throws: CancellationError.self) {
        _ = try await cancelled.foods.lookupByBarcode(.init(upc: "049000006346"))
    }

    let direct = mapTransportError(FixtureTransportError())
    #expect((direct as? JanuaryError)?.category == .transport)
}

@Test(arguments: [
    (400, ErrorCategory.validation),
    (401, ErrorCategory.authentication),
    (429, ErrorCategory.rateLimited),
    (500, ErrorCategory.server),
])
func foodSearchMapsEveryDeclaredAndUndocumentedStatus(_ status: Int, _ category: ErrorCategory) async throws {
    let json = #"{"code":"fixture_code","message":"fixture message","docs_url":"https://docs.january.ai/nutrition/apis/v1.2/"}"#
    let client = try probeClient(FailureTransport(.status(status, json)))
    do {
        _ = try await client.foods.search(.init(query: "banana"))
        Issue.record("Expected request to fail")
    } catch let error as JanuaryError {
        #expect(error.category == category)
        #expect(error.httpStatus == status)
        if status != 500 {
            #expect(error.code == "fixture_code")
            #expect(error.message == "fixture message")
        }
    }
}

@Test
func foodSearchMapsCancellationDecodingTimeoutAndTransportFailures() async throws {
    let modes: [(FailureMode, ErrorCategory?)] = [
        (.cancellation, nil),
        (.january, .authorization),
        (.decoding, .decoding),
        (.timeout, .timeout),
        (.transport, .transport),
    ]
    for (mode, expected) in modes {
        let client = try probeClient(FailureTransport(mode))
        do {
            _ = try await client.foods.search(.init(query: "banana"))
            Issue.record("Expected request to fail")
        } catch is CancellationError {
            #expect(expected == nil)
        } catch let error as JanuaryError {
            #expect(error.category == expected)
        }
    }
}

@Test
func publicClientAndCoreUtilitiesCoverValidAndInvalidConstruction() throws {
    _ = try JanuaryPartnerClient(developmentAPIKey: "fixture-key")
    #expect(throws: JanuaryError.self) {
        _ = try JanuaryPartnerClient(developmentAPIKey: " \n ")
    }

    let foodID = try JSONDecoder().decode(FoodID.self, from: Data("42".utf8))
    #expect(foodID == FoodID(rawValue: 42))
    let servingID = try JSONDecoder().decode(ServingID.self, from: Data("7".utf8))
    #expect(servingID == ServingID(rawValue: 7))
    let userID = PartnerUserID(rawValue: "fixture-user")
    #expect(try JSONDecoder().decode(PartnerUserID.self, from: JSONEncoder().encode(userID)) == userID)

    let error = JanuaryError(
        category: .rateLimited, code: "rate", message: "retry", httpStatus: 429,
        requestID: "request-id", retryAfterSeconds: 2
    )
    #expect(error.errorDescription == "retry")
    #expect(error.requestID == "request-id")
    #expect(error.retryAfterSeconds == 2)

    let defaultMessage = apiError(.server, status: 503)
    #expect(defaultMessage.message == "The January API returned HTTP 503.")
    let customMessage = apiError(.transport, status: 418, message: "teapot")
    #expect(customMessage.message == "teapot")
}

@Test
func transportBoundaryPreservesDirectStructuredFailures() async throws {
    await #expect(throws: CancellationError.self) {
        _ = try await performTransportRequest { () async throws -> Int in throw CancellationError() }
    }

    do {
        _ = try await performTransportRequest { () async throws -> Int in
            throw JanuaryError(category: .authorization, message: "fixture")
        }
        Issue.record("Expected JanuaryError")
    } catch let error as JanuaryError {
        #expect(error.category == .authorization)
    }

    do {
        _ = try await performTransportRequest { () async throws -> Int in
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "fixture"))
        }
        Issue.record("Expected decoding error")
    } catch let error as JanuaryError {
        #expect(error.category == .decoding)
    }

    do {
        _ = try await performTransportRequest { () async throws -> Int in throw URLError(.timedOut) }
        Issue.record("Expected timeout")
    } catch let error as JanuaryError {
        #expect(error.category == .timeout)
    }
}

@Test(arguments: [0.0, 41.0])
func foodSearchRejectsLimitsOutsideTheDocumentedRange(_ limit: Double) async throws {
    let transport = ContractProbeTransport()
    let client = try probeClient(transport)
    await #expect(throws: JanuaryError.self) {
        _ = try await client.foods.search(.init(query: "banana", limit: limit))
    }
    #expect(await transport.requests().isEmpty)
}

@Test
func userAgentIsSanitizedBoundedAndIncludesAvailableAppMetadata() {
    let value = SDKUserAgent.make(
        platform: "iOS\r\nInjected",
        osVersion: "18.0 (22A)",
        deviceFamily: "iPhone",
        bundleIdentifier: "ai.january.fixture",
        appVersion: "1.2.3",
        appBuild: "456"
    )
    #expect(value.contains("Platform/iOS__Injected"))
    #expect(value.contains("OS/18.0__22A_"))
    #expect(value.contains("App/ai.january.fixture"))
    #expect(value.contains("AppVersion/1.2.3"))
    #expect(value.contains("AppBuild/456"))
    #expect(!value.contains("\r"))
    #expect(!value.contains("\n"))
    #expect(SDKUserAgent.token(String(repeating: "a", count: 200)).count == 128)

    let minimal = SDKUserAgent.make(
        platform: "macOS", osVersion: "15", deviceFamily: "Mac",
        bundleIdentifier: "", appVersion: nil, appBuild: ""
    )
    #expect(!minimal.contains("App/"))
    #expect(!minimal.contains("AppVersion/"))
    #expect(!minimal.contains("AppBuild/"))
    #expect(SDKUserAgent.current.contains("JanuaryPartnerSDK/"))
}

@Test
func publicModelsRoundTripEveryCustomCodingKeyAndInitializer() throws {
    let amount = NutrientAmount(value: 12, unit: "g")
    let complete = CompleteScanNutritionFacts(
        calories: amount, protein: amount, carbohydrates: amount, netCarbohydrates: amount,
        totalFat: amount, saturatedFat: amount, fiber: amount, totalSugars: amount,
        addedSugars: amount, sodium: amount
    )
    let nutrition = NutritionFacts(
        calories: amount, protein: amount, carbohydrates: amount, netCarbohydrates: amount,
        totalFat: amount, transFat: amount, saturatedFat: amount, fiber: amount,
        totalSugars: amount, addedSugars: amount, cholesterol: amount, calcium: amount,
        iron: amount, potassium: amount, sodium: amount, vitaminD: amount
    )
    let serving = ServingSelection(id: .init(rawValue: 7), quantity: 1.5)
    let selection = FoodSelection(id: .init(rawValue: 42), serving: serving)
    let naturalServing = DetectedServing(id: .init(rawValue: 7), quantity: 1, unit: "cup")
    let naturalFood = DetectedFood(id: .init(rawValue: 42), name: "Food", brandName: "Brand", nutrients: complete, servings: [naturalServing])
    let naturalResponse = FoodScan(
        totalNutrients: complete, detections: [.init(food: naturalFood)]
    )
    let detectedServing = DetectedServing(id: .init(rawValue: 7), quantity: 1, unit: "cup")
    let detectedFood = DetectedFood(id: .init(rawValue: 42), name: "Food", brandName: "Brand", nutrients: complete, servings: [detectedServing])
    let alternatives = SuggestFoodAlternativesResponse(alternatives: [.init(food: detectedFood)])
    let user = FoodLogUserContext(endUserID: .init(rawValue: "user"), timezone: "UTC")
    _ = CreateFoodLogRequest(foods: [selection], timestampUTC: "2026-08-23T12:00:00Z", name: "Meal", user: user)
    _ = UpdateFoodLogRequest(id: UUID().uuidString, foods: [selection], timestampUTC: "2026-08-23T12:00:00Z", name: "Meal", user: user)
    _ = ListFoodLogsRequest(start: "2026-08-22", end: "2026-08-24", user: user)
    _ = DeleteFoodLogRequest(id: UUID().uuidString, user: user)
    _ = ConsumedServing(id: .init(rawValue: 7), quantity: 1)
    _ = ServingDetails(id: .init(rawValue: 7), quantity: 1, unit: "cup", weightGrams: 100)
    _ = FoodLog(id: UUID().uuidString, foods: [], timestampUTC: "2026-08-23T12:00:00Z", name: "Meal")
    _ = ListFoodLogsResponse(totalCount: 0, items: [])
    _ = DeleteFoodLogResponse(status: "deleted")
    let profile = GlucosePredictionProfile(
        age: 35, sex: .male,
        height: .init(value: 70, unit: .inches),
        weight: .init(value: 175, unit: .pounds),
        activityLevel: .moderatelyActive,
        healthConditions: []
    )
    let reading = CgmReading(timestamp: "2026-08-23T12:00:00Z", value: 100)
    let historicalServing = ConsumedHistoricalServing(id: .init(rawValue: 7), quantity: 1)
    let historicalFood = ConsumedHistoricalFood(timestamp: reading.timestamp, id: .init(rawValue: 42), serving: historicalServing)
    _ = PredictGlucoseRequest(userProfile: profile, foods: [selection], startTime: Date(), cgmData: [reading], consumedFoods: [historicalFood], endUserID: user.endUserID, timezone: "UTC")
    let prediction = GlucosePrediction(curve: [[0, 100]], scoring: .lowImpact, minimum: 100, maximum: 100)
    _ = SearchRestaurantsRequest(query: "cafe", latitude: 40, longitude: -74)
    _ = SearchRestaurantMenuItemsRequest(query: "salad", latitude: 40, longitude: -74)
    _ = Restaurant(type: .restaurant, id: "r1", name: "Cafe", isChain: false, distance: 1, city: "NYC", address1: "1 Main", address2: "Floor 2")
    _ = SearchRestaurantsResponse(totalCount: 0, items: [])
    _ = SearchRestaurantMenuItemsResponse(totalCount: 0, items: [])
    _ = ScanFoodPhotoRequest(image: "https://example.com/food.png", endUserID: user.endUserID)
    let detection = FoodDetection(food: detectedFood, confidenceScore: .high)
    let point = GlucosePredictionPoint(minutes: 0, value: 100)
    let impact = PhotoScanGlucoseImpact(impactScore: "low", prediction: [point])
    _ = FoodScan(mealName: "Meal", totalNutrients: complete, detections: [detection], glucoseImpact: impact)
    _ = CorrectPhotoScanRequest(mealName: "Meal", detections: [detection], userInput: "Correction", endUserID: user.endUserID)

    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    #expect(try decoder.decode(CompleteScanNutritionFacts.self, from: encoder.encode(complete)) == complete)
    #expect(try decoder.decode(NutritionFacts.self, from: encoder.encode(nutrition)) == nutrition)
    #expect(try decoder.decode(FoodScan.self, from: encoder.encode(naturalResponse)) == naturalResponse)
    #expect(try decoder.decode(SuggestFoodAlternativesResponse.self, from: encoder.encode(alternatives)) == alternatives)
    #expect(try decoder.decode(GlucosePrediction.self, from: encoder.encode(prediction)) == prediction)

    let loggedFoodJSON = #"{"id":42,"name":"Food","brand_name":"Brand","image_url":"https://example.com","glycemic_index":50,"glycemic_load":10,"nutrients":{},"consumed_serving":{"id":7,"quantity":1},"serving_details":{"id":7,"quantity":1,"unit":"cup","weight_grams":100}}"#
    let logged = try decoder.decode(LoggedFood.self, from: Data(loggedFoodJSON.utf8))
    #expect(logged.id.rawValue == 42)
    let menuJSON = #"{"type":"menu_item","id":"m1","name":"Burger","restaurant_name":"Cafe","is_chain":true,"energy":500,"carbs":40,"net_carbs":35,"fat":20,"protein":25,"fiber":5,"sugars":4,"added_sugars":1,"gi":50,"gl":20,"photo_url":"https://example.com","distance":1,"servings":[]}"#
    let menu = try decoder.decode(RestaurantMenuItem.self, from: Data(menuJSON.utf8))
    #expect(menu.restaurantName == "Cafe")
}

@Test
func everyMutationAndContextualRequestMatchesTheDocumentedWireShape() async throws {
    let logJSON = #"{"id":"00000000-0000-0000-0000-000000000001","foods":[],"timestamp_utc":"2026-08-23T12:00:00Z","name":"Meal"}"#
    let responses = [
        "searchFoodsByNaturalLanguage": #"{"detections":[]}"#,
        "suggestFoodAlternatives": #"{"alternatives":[]}"#,
        "scanFoodPhoto": #"{"meal_name":"Meal","detections":[]}"#,
        "correctPhotoScan": #"{"meal_name":"Meal","detections":[]}"#,
        "createFoodLog": logJSON,
        "listFoodLogs": #"{"total_count":0,"items":[]}"#,
        "updateFoodLog": logJSON,
        "deleteFoodLog": #"{"status":"deleted"}"#,
        "predictGlucose": #"{"prediction":[{"minutes":0,"value":100}],"impact_score":"low","chart":{"min":70,"max":140}}"#,
    ]
    let transport = ContractProbeTransport(responses: responses)
    let client = try probeClient(transport)
    let userID = PartnerUserID(rawValue: "wire-user")
    let user = FoodLogUserContext(endUserID: userID, timezone: "America/New_York")
    let food = FoodSelection(id: .init(rawValue: 42), serving: .init(id: .init(rawValue: 7), quantity: 1.5))
    let detection = FoodDetection(
        food: .init(
            id: .init(rawValue: 42),
            name: "Banana",
            nutrients: .init(),
            servings: [.init(id: .init(rawValue: 7), quantity: 1, unit: "serving")]
        ),
        confidenceScore: .high
    )

    _ = try await client.photoScanning.searchByNaturalLanguage(.init(query: "one banana", endUserID: userID))
    _ = try await client.foods.suggestAlternatives(
        .init(foodID: .init(rawValue: 42), dietRestrictions: [.gluten], dietPreferences: [.vegan], endUserID: userID)
    )
    _ = try await client.photoScanning.scan(.init(image: "https://example.com/meal.png", endUserID: userID))
    _ = try await client.photoScanning.correct(
        .init(mealName: "Meal", detections: [detection], userInput: "Add banana", endUserID: userID)
    )
    _ = try await client.foodLogs.create(
        .init(foods: [food], timestampUTC: "2026-08-23T12:00:00Z", name: "Meal", user: user)
    )
    _ = try await client.foodLogs.list(.init(start: "2026-08-22", end: "2026-08-24", user: user))
    _ = try await client.foodLogs.update(
        .init(id: "00000000-0000-0000-0000-000000000001", foods: [food], timestampUTC: "2026-08-23T12:00:00Z", name: "Updated", user: user)
    )
    _ = try await client.foodLogs.delete(
        .init(id: "00000000-0000-0000-0000-000000000001", user: user)
    )
    _ = try await client.glucose.predict(
        .init(
            userProfile: .init(
                age: 35, gender: .female, height: 65, weight: 140,
                activityLevel: .lightlyActive, healthConditions: [.prediabetes]
            ),
            foods: [food], startTime: Date(timeIntervalSince1970: 0),
            cgmData: [.init(timestamp: "2026-08-20T12:00:00Z", value: 100)],
            consumedFoods: [.init(timestamp: "2026-08-20T12:00:00Z", id: .init(rawValue: 42), serving: .init(id: .init(rawValue: 7), quantity: 1))],
            endUserID: userID, timezone: "America/New_York"
        )
    )

    let requests = await transport.requests()
    #expect(requests.count == 9)
    for request in requests {
        #expect(request.headers[.authorization] == "Bearer fixture-api-key")
        #expect(request.headers[HTTPField.Name("x-end-user-id")!] == "wire-user")
    }

    let alternatives = try #require(requests.first { $0.operationID == "suggestFoodAlternatives" })
    #expect(alternatives.path == "/v1.2/foods/42/alternatives")
    let alternativesBody = try jsonObject(alternatives)
    #expect(alternativesBody["diet_restrictions"] as? [String] == ["gluten"])
    #expect(alternativesBody["diet_preferences"] as? [String] == ["vegan"])

    let correction = try #require(requests.first { $0.operationID == "correctPhotoScan" })
    let correctionBody = try jsonObject(correction)
    #expect(correctionBody["meal_name"] as? String == "Meal")
    #expect(correctionBody["user_input"] as? String == "Add banana")
    #expect((correctionBody["detections"] as? [[String: Any]])?.count == 1)

    let list = try #require(requests.first { $0.operationID == "listFoodLogs" })
    #expect(list.path.contains("start=2026-08-22"))
    #expect(list.path.contains("end=2026-08-24"))
    #expect(list.headers[HTTPField.Name("x-end-user-timezone")!] == "America/New_York")

    let update = try #require(requests.first { $0.operationID == "updateFoodLog" })
    #expect(update.path == "/v1.2/food-logs/00000000-0000-0000-0000-000000000001")
    let updateBody = try jsonObject(update)
    #expect(updateBody["name"] as? String == "Updated")
    #expect((updateBody["foods"] as? [[String: Any]])?.count == 1)

    let delete = try #require(requests.first { $0.operationID == "deleteFoodLog" })
    #expect(delete.path == "/v1.2/food-logs/00000000-0000-0000-0000-000000000001")

    let glucose = try #require(requests.first { $0.operationID == "predictGlucose" })
    #expect(glucose.headers[HTTPField.Name("x-end-user-timezone")!] == "America/New_York")
    let glucoseBody = try jsonObject(glucose)
    #expect((glucoseBody["foods"] as? [[String: Any]])?.count == 1)
    #expect((glucoseBody["cgm_data"] as? [[String: Any]])?.count == 1)
    #expect((glucoseBody["consumed_foods"] as? [[String: Any]])?.count == 1)
    let profile = try #require(glucoseBody["user_profile"] as? [String: Any])
    #expect(profile["activity_level"] as? String == "lightly_active")
    #expect(profile["sex"] as? String == "female")
    #expect((profile["height"] as? [String: Any])?["unit"] as? String == "in")
    #expect((profile["weight"] as? [String: Any])?["unit"] as? String == "lb")
    #expect(profile["health_conditions"] as? [String] == ["prediabetes"])
}

private func expectEndpointError<Value: Sendable>(
    status: Int,
    category: ErrorCategory,
    operation: (JanuaryPartnerClient) async throws -> Value
) async throws {
    let body = #"{"code":"fixture_code","message":"fixture message","docs_url":"https://docs.january.ai/nutrition/apis/v1.2/"}"#
    let client = try probeClient(FailureTransport(.status(status, body)))
    do {
        _ = try await operation(client)
        Issue.record("Expected HTTP \(status)")
    } catch let error as JanuaryError {
        #expect(error.category == category)
        #expect(error.httpStatus == status)
    }
}

@Test
func everyFoodsResponseVariantMapsThroughThePublicResource() async throws {
    let common: [(Int, ErrorCategory)] = [
        (400, .validation), (401, .authentication), (429, .rateLimited), (500, .server),
    ]
    for (status, category) in common {
        try await expectEndpointError(status: status, category: category) {
            try await $0.photoScanning.searchByNaturalLanguage(.init(query: "banana"))
        }
    }
    for (status, category) in common + [(404, .notFound)] {
        try await expectEndpointError(status: status, category: category) {
            try await $0.foods.lookupByBarcode(.init(upc: "049000006346"))
        }
        try await expectEndpointError(status: status, category: category) {
            try await $0.foods.suggestAlternatives(.init(foodID: .init(rawValue: 42)))
        }
    }

    let transport = ContractProbeTransport()
    let client = try probeClient(transport)
    for category in FoodCategory.allCases {
        _ = try await client.foods.search(.init(query: "banana", category: category))
    }

    let missingScaleJSON = #"{"total_count":1,"items":[{"id":42,"name":"Food","nutrients":{"calories":{"value":160,"unit":"cal"},"protein":{"value":2,"unit":"g"},"carbohydrates":{"value":15,"unit":"g"},"total_fat":{"value":10,"unit":"g"}},"glycemic_index":34.9,"glycemic_load":5.2,"servings":[{"id":7,"quantity":1,"unit":"cup","weight_grams":60,"is_primary":true}]}]}"#
    let missingScale = try probeClient(ContractProbeTransport(responses: ["searchFoods": missingScaleJSON]))
    let result = try await missingScale.foods.search(.init(query: "food"))
    #expect(result.items[0].servings[0].scalingFactor == 1)
}

@Test
func everyRestaurantResponseVariantMapsThroughBothPublicOperations() async throws {
    for (status, category) in [
        (400, ErrorCategory.validation), (401, .authentication), (429, .rateLimited), (500, .server),
    ] {
        try await expectEndpointError(status: status, category: category) {
            try await $0.restaurants.search(.init(query: "cafe", latitude: 40, longitude: -74))
        }
        try await expectEndpointError(status: status, category: category) {
            try await $0.restaurants.searchMenuItems(.init(query: "salad", latitude: 40, longitude: -74))
        }
    }

    let transport = ContractProbeTransport()
    let client = try probeClient(transport)
    await #expect(throws: JanuaryError.self) {
        _ = try await client.restaurants.searchMenuItems(.init(query: "", latitude: 40, longitude: -74))
    }
    #expect(await transport.requests().isEmpty)
}

@Test
func everyPhotoScanningResponseVariantMapsThroughBothPublicOperations() async throws {
    let detection = FoodDetection(
        food: .init(
            name: "Food",
            nutrients: .init(),
            servings: [.init(id: .init(rawValue: 7), quantity: 1, unit: "serving")]
        )
    )
    for (status, category) in [
        (400, ErrorCategory.validation), (401, .authentication), (429, .rateLimited),
        (504, .timeout), (500, .server),
    ] {
        try await expectEndpointError(status: status, category: category) {
            try await $0.photoScanning.scan(.init(image: "https://example.com/food.png"))
        }
        try await expectEndpointError(status: status, category: category) {
            try await $0.photoScanning.correct(.init(mealName: "Meal", detections: [detection], userInput: "Fix"))
        }
    }
    try await expectEndpointError(status: 413, category: .validation) {
        try await $0.photoScanning.scan(.init(image: "fixture"))
    }
}

@Test
func everyFoodLogResponseVariantMapsThroughEveryPublicOperation() async throws {
    let user = FoodLogUserContext(endUserID: .init(rawValue: "user"), timezone: "UTC")
    let food = FoodSelection(id: .init(rawValue: 42), serving: .init(id: .init(rawValue: 7), quantity: 1))
    let common: [(Int, ErrorCategory)] = [
        (400, .validation), (401, .authentication), (429, .rateLimited), (500, .server),
    ]
    for (status, category) in common {
        try await expectEndpointError(status: status, category: category) {
            try await $0.foodLogs.create(.init(foods: [food], user: user))
        }
        try await expectEndpointError(status: status, category: category) {
            try await $0.foodLogs.list(.init(start: "2026-08-22", end: "2026-08-24", user: user))
        }
        try await expectEndpointError(status: status, category: category) {
            try await $0.foodLogs.update(.init(id: UUID().uuidString, name: "Meal", user: user))
        }
        try await expectEndpointError(status: status, category: category) {
            try await $0.foodLogs.delete(.init(id: UUID().uuidString, user: user))
        }
    }
    try await expectEndpointError(status: 404, category: .notFound) {
        try await $0.foodLogs.update(.init(id: UUID().uuidString, name: "Meal", user: user))
    }
}

@Test
func everyGlucoseResponseVariantMapsThroughThePublicResource() async throws {
    let request = PredictGlucoseRequest(
        userProfile: .init(age: 35, gender: .female, height: 65, weight: 140),
        foods: [.init(id: .init(rawValue: 42), serving: .init(id: .init(rawValue: 7), quantity: 1))],
        startTime: Date()
    )
    for (status, category) in [
        (400, ErrorCategory.validation), (401, .authentication), (429, .rateLimited),
        (504, .timeout), (500, .server),
    ] {
        try await expectEndpointError(status: status, category: category) {
            try await $0.glucose.predict(request)
        }
    }

    let liveResponse = #"{"prediction":[{"minutes":0,"value":101.5},{"minutes":15,"value":128.25}],"impact_score":"medium","chart":{"min":70,"max":140}}"#
    let transport = ContractProbeTransport(responses: ["predictGlucose": liveResponse])
    let result = try await probeClient(transport).glucose.predict(request)
    #expect(result.curve == [[0, 101.5], [15, 128.25]])
    #expect(result.scoring == .mediumImpact)
    #expect(result.minimum == 70)
    #expect(result.maximum == 140)
    #expect(try #require(await transport.requests().first).path == "/v1.2/glucose/predictions")
}

private func jsonObject(_ request: ProbeRequest) throws -> [String: Any] {
    let data = try #require(request.body)
    return try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
}
