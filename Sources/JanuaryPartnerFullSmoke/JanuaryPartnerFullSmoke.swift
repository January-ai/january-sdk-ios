import Foundation
import JanuaryPartnerSDK

@main
struct JanuaryPartnerFullSmoke {
    static func main() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let apiKey = environment["JANUARY_API_KEY"], !apiKey.isEmpty else {
            throw SmokeError("JANUARY_API_KEY is not configured.")
        }
        guard let rawUserID = environment["JANUARY_END_USER_ID"], !rawUserID.isEmpty else {
            throw SmokeError("JANUARY_END_USER_ID is not configured.")
        }
        let client = try JanuaryPartnerClient(developmentAPIKey: apiKey)
        try await run(client: client, userID: PartnerUserID(rawValue: rawUserID))
        print("PASS all Partner API v1.2 operations through the public Swift SDK")
    }

    private static func run(client: JanuaryPartnerClient, userID: PartnerUserID) async throws {
        let results = try await client.foods.search(.init(query: "banana", limit: 3, endUserID: userID))
        guard let food = results.items.first, let serving = food.servings.first else {
            throw SmokeError("foods.search returned no food with a serving.")
        }
        pass("foods.search", "\(results.items.count) items")

        let natural = try await client.foods.searchByNaturalLanguage(
            .init(query: "one banana and a bowl of oatmeal", endUserID: userID)
        )
        pass("foods.searchByNaturalLanguage", "\(natural.detections.count) detections")

        let alternatives = try await client.foods.suggestAlternatives(.init(foodID: food.id, endUserID: userID))
        pass("foods.suggestAlternatives", "\(alternatives.alternatives.count) alternatives")

        let barcode = try await client.foods.lookupByBarcode(.init(upc: "049000006346", endUserID: userID))
        pass("foods.lookupByBarcode", "\(barcode.items.count) items")

        let restaurants = try await client.restaurants.search(
            .init(query: "mcdonalds", latitude: 37.7749, longitude: -122.4194, limit: 3, endUserID: userID)
        )
        pass("restaurants.search", "\(restaurants.items.count) items")

        let menuItems = try await client.restaurants.searchMenuItems(
            .init(query: "burger", latitude: 37.7749, longitude: -122.4194, limit: 3, endUserID: userID)
        )
        pass("restaurants.searchMenuItems", "\(menuItems.items.count) items")

        let scan = try await client.photoScanning.scan(
            .init(image: burgerImageURL, endUserID: userID)
        )
        guard let mealName = scan.mealName, let detections = scan.detections, !detections.isEmpty else {
            throw SmokeError("photoScanning.scan returned no correctable detections.")
        }
        pass("photoScanning.scan", "\(detections.count) detections")

        let fixtureURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Tests/JanuaryPartnerSDKTests/Fixtures/PhotoScanning/burger-and-fries.png")
        let fixture = try Data(contentsOf: fixtureURL)
        let base64Scan = try await client.photoScanning.scan(
            .init(
                image: "data:image/png;base64,\(fixture.base64EncodedString())",
                endUserID: userID
            )
        )
        guard
            let base64MealName = base64Scan.mealName,
            !base64MealName.isEmpty,
            let base64Detections = base64Scan.detections,
            !base64Detections.isEmpty
        else {
            throw SmokeError("photoScanning.scan returned no detections for the base64 fixture.")
        }
        pass("photoScanning.scan base64", "\(base64Detections.count) detections")

        _ = try await client.photoScanning.correct(
            .init(
                mealName: mealName, detections: detections,
                userInput: "Rename the meal to January Swift SDK smoke test meal.", endUserID: userID
            )
        )
        pass("photoScanning.correct")

        let selectedFood = FoodSelection(id: food.id, serving: .init(id: serving.id, quantity: 1))
        let user = FoodLogUserContext(endUserID: userID, timezone: timezone)
        var createdLogID: String?
        do {
            let created = try await client.foodLogs.create(
                .init(
                    foods: [selectedFood], timestampUTC: ISO8601DateFormatter().string(from: Date()),
                    name: "January Swift SDK smoke \(UUID().uuidString)", user: user
                )
            )
            createdLogID = created.id
            pass("foodLogs.create")

            let range = dateRangeAroundToday()
            let listed = try await client.foodLogs.list(.init(start: range.start, end: range.end, user: user))
            guard listed.items.contains(where: { $0.id == created.id }) else {
                throw SmokeError("foodLogs.list did not return the created log.")
            }
            pass("foodLogs.list")

            let updated = try await client.foodLogs.update(
                .init(id: created.id, name: "January Swift SDK smoke updated", user: user)
            )
            guard updated.name == "January Swift SDK smoke updated" else {
                throw SmokeError("foodLogs.update did not persist the name.")
            }
            pass("foodLogs.update")

            let deleted = try await client.foodLogs.delete(.init(id: created.id, user: user))
            guard deleted.status == "deleted" else { throw SmokeError("foodLogs.delete returned \(deleted.status).") }
            createdLogID = nil
            pass("foodLogs.delete")
        } catch {
            if let createdLogID { _ = try? await client.foodLogs.delete(.init(id: createdLogID, user: user)) }
            throw error
        }

        let prediction = try await client.glucose.predict(
            .init(
                userProfile: .init(
                    age: 35, gender: .male, height: 70, weight: 175,
                    activityLevel: .moderatelyActive, healthConditions: [.noneOfTheAbove]
                ),
                foods: [selectedFood], startTime: Date(), endUserID: userID, timezone: timezone
            )
        )
        guard !prediction.curve.isEmpty else { throw SmokeError("glucose.predict returned no points.") }
        pass("glucose.predict", "\(prediction.curve.count) points")
    }

    private static let timezone = "America/New_York"
    private static let burgerImageURL = "https://friendlysrestaurants.com/assets/live/img/production/detail/menu/lunch-dinner_999-combohs_all-american-burger-fries.jpg"

    private static func dateRangeAroundToday() -> (start: String, end: String) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        let today = Date()
        return (
            formatter.string(from: calendar.date(byAdding: .day, value: -1, to: today)!),
            formatter.string(from: calendar.date(byAdding: .day, value: 1, to: today)!)
        )
    }

    private static func pass(_ operation: String, _ detail: String? = nil) {
        print("PASS \(operation)\(detail.map { " (\($0))" } ?? "")")
    }
}

private struct SmokeError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
