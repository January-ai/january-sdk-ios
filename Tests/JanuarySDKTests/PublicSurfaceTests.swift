import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
@_spi(JanuaryDevelopment) @testable import JanuarySDK

private actor SurfaceTransport: ClientTransport {
    private var operations: [String] = []

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        operations.append(operationID)
        var response = HTTPResponse(status: .ok)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(Data(responseJSON(for: operationID).utf8)))
    }

    func operationIDs() -> [String] { operations }

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

    _ = try await client.foods.autocomplete(.init(query: "ban", endUserID: userID))
    _ = try await client.foods.getFood(.init(foodID: FoodID(rawValue: 1), endUserID: userID))
    _ = try await client.foods.search(.init(query: "banana", endUserID: userID))
    _ = try await client.foods.lookupByBarcode(.init(upc: "049000006346", endUserID: userID))
    _ = try await client.photoScanning.searchByNaturalLanguage(.init(query: "one banana", endUserID: userID))
    _ = try await client.foods.suggestAlternatives(.init(foodID: FoodID(rawValue: 1), endUserID: userID))
    _ = try await client.restaurants.search(.init(query: "cafe", latitude: 40, longitude: -74, endUserID: userID))
    _ = try await client.restaurants.searchMenuItems(.init(query: "salad", latitude: 40, longitude: -74, endUserID: userID))
    _ = try await client.photoScanning.scan(.init(image: "fixture-image", endUserID: userID))
    _ = try await client.photoScanning.correct(
        .init(mealName: "Meal", detections: [detection], userInput: "Add banana", endUserID: userID)
    )
    let created = try await client.foodLogs.create(.init(foods: [food], user: user))
    _ = try await client.foodLogs.list(.init(start: "2026-08-21", end: "2026-08-23", user: user))
    _ = try await client.foodLogs.update(.init(id: created.id, name: "Updated", user: user))
    _ = try await client.foodLogs.delete(.init(id: created.id, user: user))
    _ = try await client.glucose.predict(
        .init(
            userProfile: .init(age: 35, gender: .male, height: 70, weight: 175),
            foods: [food], startTime: Date(), endUserID: userID
        )
    )

    #expect(Set(await transport.operationIDs()) == Set([
        "autocompleteFoods", "getFood", "searchFoods", "lookupFoodByBarcode",
        "searchFoodsByNaturalLanguage", "suggestFoodAlternatives",
        "searchRestaurants", "searchRestaurantMenuItems", "scanFoodPhoto", "correctPhotoScan",
        "createFoodLog", "listFoodLogs", "updateFoodLog", "deleteFoodLog", "predictGlucose",
    ]))
}
