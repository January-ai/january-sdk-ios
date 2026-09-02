import Foundation
import Testing
@testable import January

@Test
func exercisesAllSeventeenClientOperationsLive() async throws {
    let environment = ProcessInfo.processInfo.environment
    guard
        let apiKey = environment["JANUARY_API_KEY"], !apiKey.isEmpty,
        let endUserID = environment["JANUARY_END_USER_ID"], !endUserID.isEmpty
    else { return }

    let timezone = TimeZone(identifier: "America/New_York")!
    let client = try JanuaryClient(
        developmentAPIKey: apiKey,
        endUserID: endUserID,
        timezone: timezone
    )

    let autocomplete = try await client.foods.autocomplete(.init(query: "ban", limit: 3))
    #expect(!autocomplete.items.isEmpty)
    pass("foods.autocomplete")

    let search = try await client.foods.search(.init(query: "banana", limit: 3))
    let food = try #require(search.items.first)
    let serving = try #require(food.servings.first { $0.id != nil })
    let servingID = try #require(serving.id)
    pass("foods.search")

    _ = try await client.foods.get(id: food.id)
    pass("foods.get")

    let natural = try await client.foodAnalysis.analyzeDescription(
        .init(query: "one banana and a bowl of oatmeal")
    )
    #expect(!natural.detections.isEmpty)
    pass("foodAnalysis.analyzeDescription")

    _ = try await client.foods.suggestAlternatives(.init(foodID: food.id))
    pass("foods.suggestAlternatives")

    _ = try await client.foods.lookupBarcode(.init(upc: "049000006346"))
    pass("foods.lookupBarcode")

    let restaurants = try await client.restaurants.search(
        .init(query: "mcdonalds", latitude: 37.7749, longitude: -122.4194, limit: 3)
    )
    pass("restaurants.search")

    _ = try await client.restaurants.searchMenuItems(
        .init(query: "burger", latitude: 37.7749, longitude: -122.4194, limit: 3)
    )
    pass("restaurants.searchMenuItems")

    var restaurantMenu: GetRestaurantMenuItemsResponse?
    for restaurant in restaurants.items {
        if let menu = try? await client.restaurants.getMenuItems(
            .init(restaurantID: restaurant.id, limit: 3)
        ) {
            restaurantMenu = menu
            break
        }
    }
    #expect(restaurantMenu != nil)
    pass("restaurants.getMenuItems")

    let analysis = try await client.foodAnalysis.analyzePhoto(.init(image: burgerImageURL))
    #expect(!analysis.detections.isEmpty)
    pass("foodAnalysis.analyzePhoto")

    _ = try await client.foodAnalysis.correct(
        .init(analysis: analysis, instruction: "Rename the meal to January iOS SDK smoke test meal.")
    )
    pass("foodAnalysis.correct")

    let selectedFood = FoodSelection(
        id: food.id,
        serving: ServingSelection(id: servingID, quantity: 1)
    )
    var createdLogID: String?
    do {
        let created = try await client.foodLogs.create(
            foods: [selectedFood],
            timestampUTC: ISO8601DateFormatter().string(from: Date()),
            name: "January iOS SDK smoke \(UUID().uuidString)"
        )
        let logID = try #require(created.id)
        createdLogID = logID
        pass("foodLogs.create")

        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(byAdding: .day, value: -1, to: Date())!
        let end = calendar.date(byAdding: .day, value: 1, to: Date())!
        let listed = try await client.foodLogs.list(
            start: SelfDateFormatter.string(from: start),
            end: SelfDateFormatter.string(from: end)
        )
        #expect(listed.items.contains { $0.id == logID })
        pass("foodLogs.list")

        let fetched = try await client.foodLogs.get(id: logID)
        #expect(fetched.id == logID)
        pass("foodLogs.get")

        let updated = try await client.foodLogs.update(
            id: logID,
            name: "January iOS SDK smoke updated"
        )
        #expect(updated.name == "January iOS SDK smoke updated")
        pass("foodLogs.update")

        try await client.foodLogs.delete(id: logID)
        createdLogID = nil
        pass("foodLogs.delete")
    } catch {
        if let createdLogID { try? await client.foodLogs.delete(id: createdLogID) }
        throw error
    }

    let prediction = try await client.glucose.predict(.init(
        userProfile: .init(
            age: 35,
            sex: .male,
            height: .init(value: 70, unit: .inches),
            weight: .init(value: 175, unit: .pounds),
            activityLevel: .moderatelyActive,
            healthConditions: []
        ),
        foods: [selectedFood],
        startTime: Date(),
        timezone: timezone
    ))
    #expect(!prediction.prediction.isEmpty)
    pass("glucose.predict")
}

private let burgerImageURL = "https://friendlysrestaurants.com/assets/live/img/production/detail/menu/lunch-dinner_999-combohs_all-american-burger-fries.jpg"

private let SelfDateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter
}()

private func pass(_ operation: String) {
    print("PASS \(operation)")
}
