import Foundation
import JanuaryPartnerSDK

@main
struct JanuaryPartnerFullSmoke {
    static func main() async {
        do {
            let environment = ProcessInfo.processInfo.environment
            guard let apiKey = environment["JANUARY_API_KEY"], !apiKey.isEmpty else {
                throw SmokeError("JANUARY_API_KEY is not configured.")
            }
            guard let rawUserID = environment["JANUARY_END_USER_ID"], !rawUserID.isEmpty else {
                throw SmokeError("JANUARY_END_USER_ID is not configured.")
            }
            let client = try JanuaryPartnerClient(developmentAPIKey: apiKey)
            try await run(client: client, userID: PartnerUserID(rawValue: rawUserID))
            writeLine("PASS all independently runnable Partner API v1.2 checks through the public Swift SDK")
        } catch {
            writeLine("FAIL live Partner API v1.2 smoke:\n\(error)")
            exit(1)
        }
    }

    private static func run(client: JanuaryPartnerClient, userID: PartnerUserID) async throws {
        let report = SmokeReport()
        let results = await report.attempt("foods.search") {
            let value = try await client.foods.search(.init(query: "banana", limit: 3, endUserID: userID))
            guard value.items.contains(where: { !$0.servings.isEmpty }) else {
                throw SmokeError("returned no food with a serving")
            }
            return value
        }

        _ = await report.attempt("foods.searchByNaturalLanguage") {
            try await client.foods.searchByNaturalLanguage(
                .init(query: "one banana and a bowl of oatmeal", endUserID: userID)
            )
        }

        _ = await report.attempt("foods.lookupByBarcode") {
            try await client.foods.lookupByBarcode(.init(upc: "049000006346", endUserID: userID))
        }

        if let food = results?.items.first(where: { !$0.servings.isEmpty }) {
            _ = await report.attempt("foods.suggestAlternatives") {
                try await client.foods.suggestAlternatives(.init(foodID: food.id, endUserID: userID))
            }
        } else {
            await report.blocked("foods.suggestAlternatives", by: "foods.search")
        }

        _ = await report.attempt("restaurants.search") {
            try await client.restaurants.search(
                .init(query: "mcdonalds", latitude: 37.7749, longitude: -122.4194, limit: 3, endUserID: userID)
            )
        }

        _ = await report.attempt("restaurants.searchMenuItems") {
            try await client.restaurants.searchMenuItems(
                .init(query: "burger", latitude: 37.7749, longitude: -122.4194, limit: 3, endUserID: userID)
            )
        }

        let scan = await report.attempt("photoScanning.scan URL") {
            let value = try await client.photoScanning.scan(.init(image: burgerImageURL, endUserID: userID))
            guard value.mealName?.isEmpty == false, value.detections?.isEmpty == false else {
                throw SmokeError("returned no correctable detections")
            }
            return value
        }

        let fixtureURL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Tests/JanuaryPartnerSDKTests/Fixtures/PhotoScanning/burger-and-fries.png")
        _ = await report.attempt("photoScanning.scan base64") {
            let fixture = try Data(contentsOf: fixtureURL)
            let value = try await client.photoScanning.scan(
                .init(image: "data:image/png;base64,\(fixture.base64EncodedString())", endUserID: userID)
            )
            guard value.mealName?.isEmpty == false, value.detections?.isEmpty == false else {
                throw SmokeError("returned no detections for the base64 fixture")
            }
            return value
        }

        if let mealName = scan?.mealName, let detections = scan?.detections, !detections.isEmpty {
            _ = await report.attempt("photoScanning.correct") {
                try await client.photoScanning.correct(
                    .init(
                        mealName: mealName, detections: detections,
                        userInput: "Rename the meal to January Swift SDK smoke test meal.", endUserID: userID
                    )
                )
            }
        } else {
            await report.blocked("photoScanning.correct", by: "photoScanning.scan URL")
        }

        let user = FoodLogUserContext(endUserID: userID, timezone: timezone)
        let range = dateRangeAroundToday()
        _ = await report.attempt("foodLogs.list") {
            try await client.foodLogs.list(.init(start: range.start, end: range.end, user: user))
        }

        _ = await report.attempt("foodLogs.delete idempotent") {
            try await client.foodLogs.delete(.init(id: UUID().uuidString, user: user))
        }

        guard let food = results?.items.first(where: { !$0.servings.isEmpty }), let serving = food.servings.first else {
            await report.blocked("foodLogs.create/update/delete", by: "foods.search")
            await report.blocked("glucose.predict", by: "foods.search")
            return try await report.finish()
        }
        let selectedFood = FoodSelection(id: food.id, serving: .init(id: serving.id, quantity: 1))
        var createdLogID: String?
        if let created = await report.attempt("foodLogs.create", {
            try await client.foodLogs.create(
                .init(
                    foods: [selectedFood], timestampUTC: ISO8601DateFormatter().string(from: Date()),
                    name: "January Swift SDK smoke \(UUID().uuidString)", user: user
                )
            )
        }) {
            createdLogID = created.id
            _ = await report.attempt("foodLogs.update") {
                let updated = try await client.foodLogs.update(
                    .init(id: created.id, name: "January Swift SDK smoke updated", user: user)
                )
                guard updated.name == "January Swift SDK smoke updated" else {
                    throw SmokeError("did not persist the updated name")
                }
                return updated
            }
            if await report.attempt("foodLogs.delete created", {
                try await client.foodLogs.delete(.init(id: created.id, user: user))
            }) != nil {
                createdLogID = nil
            }
        } else {
            await report.blocked("foodLogs.update", by: "foodLogs.create")
            await report.blocked("foodLogs.delete created", by: "foodLogs.create")
        }

        if let createdLogID { _ = try? await client.foodLogs.delete(.init(id: createdLogID, user: user)) }

        _ = await report.attempt("glucose.predict") {
            let prediction = try await client.glucose.predict(
                .init(
                    userProfile: .init(
                        age: 35, gender: .male, height: 70, weight: 175,
                        activityLevel: .moderatelyActive, healthConditions: [.noneOfTheAbove]
                    ),
                    foods: [selectedFood], startTime: Date(), endUserID: userID, timezone: timezone
                )
            )
            guard !prediction.curve.isEmpty else { throw SmokeError("returned no points") }
            return prediction
        }

        try await report.finish()
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

}

private actor SmokeReport {
    private var failures: [String] = []

    func attempt<Value: Sendable>(
        _ operation: String,
        _ body: @Sendable () async throws -> Value
    ) async -> Value? {
        do {
            let value = try await body()
            writeLine("PASS \(operation)")
            return value
        } catch {
            failures.append("\(operation): \(error)")
            writeLine("FAIL \(operation): \(error)")
            return nil
        }
    }

    func blocked(_ operation: String, by dependency: String) {
        let message = "\(operation): blocked by \(dependency)"
        failures.append(message)
        writeLine("BLOCKED \(message)")
    }

    func finish() throws {
        guard failures.isEmpty else {
            throw SmokeError("\(failures.count) live checks failed or were blocked:\n- \(failures.joined(separator: "\n- "))")
        }
    }
}

private func writeLine(_ value: String) {
    FileHandle.standardError.write(Data("\(value)\n".utf8))
}

private struct SmokeError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}
