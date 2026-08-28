import Foundation
import JanuaryPartnerTransport
import Testing
@_spi(JanuaryDevelopment) @testable import JanuarySDK

private actor SurfaceTransport: ClientTransport {
    private var operations: [String] = []
    private var endUserIDs: [String?] = []

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        operations.append(operationID)
        endUserIDs.append(request.headerFields[HTTPField.Name("x-end-user-id")!])
        var response = HTTPResponse(status: .ok)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(Data(responseJSON(for: operationID).utf8)))
    }

    func operationIDs() -> [String] { operations }
    func capturedEndUserIDs() -> [String?] { endUserIDs }

    private func responseJSON(for operationID: String) -> String {
        switch operationID {
        case "searchFoods", "lookupFoodByBarcode":
            #"{"total_count":0,"items":[]}"#
        case "autocompleteFoods":
            #"{"items":[]}"#
        case "getFood":
            #"{"id":1,"name":"Banana","nutrients":{},"servings":[{"id":2,"quantity":1,"unit":"serving","scaling_factor":1,"weight_grams":100,"is_primary":true}]}"#
        case "searchFoodsByNaturalLanguage":
            #"{"detections":[]}"#
        case "suggestFoodAlternatives":
            #"{"alternatives":[]}"#
        case "searchRestaurants", "searchRestaurantMenuItems":
            #"{"total_count":0,"items":[]}"#
        case "scanFoodPhoto", "correctPhotoScan":
            #"{"meal_name":"Fixture meal","detections":[]}"#
        case "createFoodLog", "updateFoodLog":
            #"{"id":"00000000-0000-0000-0000-000000000001","foods":[],"timestamp_utc":"2026-08-22T12:00:00Z","name":"Fixture"}"#
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

@Test
func allContractOperationsAreExposedThroughThePublicClient() async throws {
    let transport = SurfaceTransport()
    let client = try JanuaryClient(
        developmentAPIKey: "fixture-api-key",
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport
    )
    let userID = PartnerUserID(rawValue: "fixture-user")
    let user = FoodLogUserContext(endUserID: userID, timezone: "America/New_York")
    let userClient = client.forUser(user)
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

    _ = try await userClient.foods.autocomplete(.init(query: "ban"))
    _ = try await userClient.foods.getFood(.init(foodID: FoodID(rawValue: 1)))
    _ = try await userClient.foods.search(.init(query: "banana"))
    _ = try await userClient.foods.lookupByBarcode(.init(upc: "049000006346"))
    _ = try await userClient.photoScanning.searchByNaturalLanguage(.init(query: "one banana"))
    _ = try await userClient.foods.suggestAlternatives(.init(foodID: FoodID(rawValue: 1)))
    _ = try await userClient.restaurants.search(.init(query: "cafe", latitude: 40, longitude: -74))
    _ = try await userClient.restaurants.searchMenuItems(.init(query: "salad", latitude: 40, longitude: -74))
    _ = try await userClient.photoScanning.scan(.init(image: "fixture-image"))
    _ = try await userClient.photoScanning.correct(
        .init(mealName: "Meal", detections: [detection], userInput: "Add banana")
    )
    let created = try await userClient.foodLogs.create(foods: [food])
    _ = try await userClient.foodLogs.list(start: "2026-08-21", end: "2026-08-23")
    _ = try await userClient.foodLogs.update(id: created.id, name: "Updated")
    _ = try await userClient.foodLogs.delete(id: created.id)
    _ = try await userClient.glucose.predict(
        .init(
            userProfile: .init(age: 35, gender: .male, height: 70, weight: 175),
            foods: [food], startTime: Date()
        )
    )

    #expect(Set(await transport.operationIDs()) == Set([
        "autocompleteFoods", "getFood", "searchFoods", "lookupFoodByBarcode",
        "searchFoodsByNaturalLanguage", "suggestFoodAlternatives",
        "searchRestaurants", "searchRestaurantMenuItems", "scanFoodPhoto", "correctPhotoScan",
        "createFoodLog", "listFoodLogs", "updateFoodLog", "deleteFoodLog", "predictGlucose",
    ]))
    #expect(await transport.capturedEndUserIDs().allSatisfy { $0 == "fixture-user" })
}
