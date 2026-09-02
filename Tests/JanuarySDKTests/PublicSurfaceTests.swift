import Foundation
import JanuaryPartnerTransport
import Testing
@_spi(JanuaryDevelopment) @testable import January

private actor SurfaceTransport: ClientTransport {
    private var operations: [String] = []
    private var endUserIDs: [String?] = []
    private var timezones: [String?] = []

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        operations.append(operationID)
        endUserIDs.append(request.headerFields[HTTPField.Name("January-End-User-ID")!])
        timezones.append(request.path?.contains("timezone=") == true ? "query" : nil)
        let status: HTTPResponse.Status = operationID == "createFoodLog" ? .init(code: 201) :
            (operationID == "deleteFoodLog" ? .init(code: 204) : .ok)
        var response = HTTPResponse(status: status)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(Data(responseJSON(for: operationID).utf8)))
    }

    func operationIDs() -> [String] { operations }
    func capturedEndUserIDs() -> [String?] { endUserIDs }
    func capturedTimezones() -> [String?] { timezones }

    private func responseJSON(for operationID: String) -> String {
        switch operationID {
        case "searchFoods":
            #"{"items":[]}"#
        case "lookupFoodByBarcode":
            #"{"type":"generic","id":"1","name":"Banana","barcode":"049000006346","nutrients":{},"servings":[]}"#
        case "autocompleteFoods":
            #"{"items":[]}"#
        case "getFood":
            #"{"type":"generic","id":"1","name":"Banana","barcode":null,"nutrients":{},"servings":[{"id":"2","quantity":1,"unit":"serving","is_primary":true}]}"#
        case "searchFoodsByNaturalLanguage":
            #"{"meal_name":null,"total_nutrients":{},"detections":[]}"#
        case "suggestFoodAlternatives":
            #"{"alternatives":[]}"#
        case "searchRestaurants", "searchRestaurantMenuItems":
            #"{"items":[]}"#
        case "getRestaurantMenuItems":
            #"{"items":[]}"#
        case "scanFoodPhoto", "correctPhotoScan":
            #"{"meal_name":"Fixture meal","total_nutrients":{},"detections":[]}"#
        case "createFoodLog", "updateFoodLog":
            #"{"id":"00000000-0000-0000-0000-000000000001","foods":[],"eaten_at":"2026-08-22T12:00:00Z","name":"Fixture"}"#
        case "getFoodLog":
            #"{"id":"00000000-0000-0000-0000-000000000001","foods":[],"eaten_at":"2026-08-22T12:00:00Z","name":"Fixture"}"#
        case "listFoodLogs":
            #"{"items":[]}"#
        case "deleteFoodLog":
            ""
        case "predictGlucose":
            #"{"points":[{"minutes":0,"value":100}],"impact_score":"low","chart":{"min":70,"max":140}}"#
        default:
            #"{}"#
        }
    }
}

@Test
func optionalUserIDAndDefaultTimezoneApplyToFoodLogs() async throws {
    let transport = SurfaceTransport()
    let client = try JanuaryClient(
        clientToken: "ct-fixture",
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport,
        userContext: PartnerUserContext()
    )

    _ = try await client.foodLogs.list(start: "2026-08-21", end: "2026-08-23")

    #expect(await transport.capturedEndUserIDs() == [nil])
    #expect(await transport.capturedTimezones() == ["query"])
}

@Test
func allContractOperationsAreExposedThroughThePublicClient() async throws {
    let transport = SurfaceTransport()
    let userID = PartnerUserID(rawValue: "fixture-user")
    let user = FoodLogUserContext(
        endUserID: userID,
        timezone: TimeZone(identifier: "America/New_York")!
    )
    let client = try JanuaryClient(
        developmentAPIKey: "fixture-api-key",
        userContext: user,
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport
    )
    let food = FoodSelection(
        id: FoodID(rawValue: 1),
        serving: ServingSelection(id: ServingID(rawValue: 2), quantity: 1)
    )
    let detection = FoodDetection(
        food: DetectedFood(
            id: FoodID(rawValue: 1),
            name: "Banana",
            nutrients: .init(),
            servings: [.init(id: ServingID(rawValue: 2), quantity: 1, unit: "serving")]
        )
    )

    _ = try await client.foods.autocomplete(.init(query: "ban"))
    _ = try await client.foods.get(id: FoodID(rawValue: 1))
    _ = try await client.foods.search(.init(query: "banana"))
    _ = try await client.foods.lookupBarcode(.init(upc: "049000006346"))
    _ = try await client.foodAnalysis.analyzeDescription(.init(query: "one banana"))
    _ = try await client.foods.suggestAlternatives(.init(foodID: FoodID(rawValue: 1)))
    _ = try await client.restaurants.search(.init(query: "cafe", latitude: 40, longitude: -74))
    _ = try await client.restaurants.getMenuItems(.init(restaurantID: "cafe-123"))
    _ = try await client.restaurants.searchMenuItems(.init(query: "salad", latitude: 40, longitude: -74))
    _ = try await client.foodAnalysis.analyzePhoto(.init(image: "fixture-image"))
    _ = try await client.foodAnalysis.correct(
        .init(mealName: "Meal", detections: [detection], userInput: "Add banana")
    )
    let created = try await client.foodLogs.create(foods: [food])
    let createdID = try #require(created.id)
    _ = try await client.foodLogs.list(start: "2026-08-21", end: "2026-08-23")
    _ = try await client.foodLogs.get(id: createdID)
    _ = try await client.foodLogs.update(id: createdID, name: "Updated")
    _ = try await client.foodLogs.delete(id: createdID)
    _ = try await client.glucose.predict(
        .init(
            userProfile: .init(age: 35, gender: .male, height: 70, weight: 175),
            foods: [food], startTime: Date()
        )
    )

    #expect(Set(await transport.operationIDs()) == Set([
        "autocompleteFoods", "getFood", "searchFoods", "lookupFoodByBarcode",
        "searchFoodsByNaturalLanguage", "suggestFoodAlternatives",
        "searchRestaurants", "getRestaurantMenuItems", "searchRestaurantMenuItems",
        "scanFoodPhoto", "correctPhotoScan", "createFoodLog", "listFoodLogs", "getFoodLog",
        "updateFoodLog", "deleteFoodLog", "predictGlucose",
    ]))
    let captured = await transport.capturedEndUserIDs()
    #expect(captured.compactMap { $0 }.count == 5)
    #expect(captured.compactMap { $0 }.allSatisfy { $0 == "fixture-user" })
}
