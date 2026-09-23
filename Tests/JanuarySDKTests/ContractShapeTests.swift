import Foundation
import JanuaryPartnerTransport
import Testing
@_spi(JanuaryDevelopment) @testable import January

/// Decodes responses captured from the live Partner API after the September 2026 contract change.
private actor ShapeTransport: ClientTransport {
    private let bodies: [String: String]
    private var captured: [(HTTPRequest, Data?)] = []
    init(bodies: [String: String]) { self.bodies = bodies }

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        var data: Data?
        if let body { data = try await Data(collecting: body, upTo: 3_000_000) }
        captured.append((request, data))
        var response = HTTPResponse(status: .ok)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(bodies[operationID] ?? #"{}"#))
    }

    func requests() -> [(HTTPRequest, Data?)] { captured }
}

private let textAnalysis = #"{"meal_name": null, "total_nutrients": {"calories": {"value": 206.8, "unit": "kcal"}, "protein": {"value": 14.58, "unit": "g"}, "carbohydrates": {"value": 12.72, "unit": "g"}, "total_fat": {"value": 10.39, "unit": "g"}}, "detections": [{"confidence": null, "food": {"id": "70382174", "name": "eggs", "brand_name": null, "nutrients": {"calories": {"value": 143, "unit": "kcal"}, "protein": {"value": 12.6, "unit": "g"}, "carbohydrates": {"value": 0.72, "unit": "g"}, "total_fat": {"value": 9.51, "unit": "g"}}, "quantity": 2, "serving": {"id": "34073350", "quantity": 1, "unit": "large"}}}]}"#

private let summary = #"{"group_by": "day", "week_start": null, "timezone": "America/Chicago", "start_date": "2026-09-14", "end_date": "2026-09-14", "buckets": [{"start_date": "2026-09-14", "end_date": "2026-09-14", "logs_count": 1, "days_with_logs": 1, "nutrients": {"calories": {"value": 1853.06, "unit": "kcal"}, "protein": {"value": 79.8822, "unit": "g"}, "carbohydrates": {"value": 199.5376, "unit": "g"}, "total_fat": {"value": 83.5442, "unit": "g"}}}], "totals": {"logs_count": 3, "days_with_logs": 2, "nutrients": {"calories": {"value": 3656.4883824999997, "unit": "kcal"}, "protein": {"value": 160.916828855, "unit": "g"}, "carbohydrates": {"value": 315.50554525, "unit": "g"}, "total_fat": {"value": 192.22509300000002, "unit": "g"}}}, "average_per_logged_day": {"nutrients": {"calories": {"value": 1828.2441912499999, "unit": "kcal"}, "protein": {"value": 80.4584144275, "unit": "g"}, "carbohydrates": {"value": 157.752772625, "unit": "g"}, "total_fat": {"value": 96.11254650000001, "unit": "g"}}}}"#

/// Answers every request with one status and JSON body.
private struct StatusTransport: ClientTransport {
    let status: Int
    let body: String

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        var response = HTTPResponse(status: .init(code: status))
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(self.body))
    }
}

private func makeClient(_ transport: some ClientTransport) throws -> JanuaryClient {
    try JanuaryClient(
        developmentAPIKey: "fixture-api-key",
        userContext: PartnerUserContext(
            endUserID: PartnerUserID(rawValue: "fixture-user"),
            timezone: TimeZone(identifier: "America/Chicago")!
        ),
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport
    )
}

private func json(_ data: Data?) throws -> [String: Any] {
    let payload = try #require(data)
    let object = try JSONSerialization.jsonObject(with: payload) as? [String: Any]
    return try #require(object)
}

@Test
func detectionCarriesSelectedServingAndQuantity() async throws {
    let client = try makeClient(ShapeTransport(bodies: ["searchFoodsByNaturalLanguage": textAnalysis]))

    let scan = try await client.foodAnalysis.analyzeDescription(.init(query: "three eggs"))

    let food = try #require(scan.detections.first?.food)
    #expect(food.name == "eggs")
    #expect(food.quantity == 2)
    #expect(food.serving.id == ServingID(rawValue: "34073350"))
    #expect(food.serving.quantity == 1)
    #expect(food.serving.unit == "large")
    #expect(food.nutrients.calories?.value == 143)
    #expect(scan.totalNutrients.calories?.value == 206.8)
    let foodID = try #require(food.id)
    let servingID = try #require(food.serving.id)
    let quantity = try #require(food.quantity)
    let selection = FoodSelection(id: foodID, serving: .init(id: servingID, quantity: quantity))
    #expect(selection == FoodSelection(id: FoodID(rawValue: "70382174"), serving: .init(id: ServingID(rawValue: "34073350"), quantity: 2)))
}

@Test
func correctionRoundTripsServingAndQuantity() async throws {
    let transport = ShapeTransport(bodies: ["searchFoodsByNaturalLanguage": textAnalysis, "correctPhotoScan": textAnalysis])
    let client = try makeClient(transport)
    let scan = try await client.foodAnalysis.analyzeDescription(.init(query: "three eggs"))

    _ = try await client.foodAnalysis.correct(.init(analysis: scan, instruction: "make it two eggs"))

    let requests = await transport.requests()
    let body = try json(requests[1].1)
    let analysis = try #require(body["analysis"] as? [String: Any])
    let food = try #require((analysis["detections"] as? [[String: Any]])?.first?["food"] as? [String: Any])
    #expect(food["quantity"] as? Double == 2)
    #expect((food["serving"] as? [String: Any])?["unit"] as? String == "large")
    #expect(food["servings"] == nil)
}

@Test
func photoScanSendsReasoningEffortOnlyWhenAsked() async throws {
    let empty = #"{"meal_name":null,"total_nutrients":{},"detections":[]}"#
    let transport = ShapeTransport(bodies: ["scanFoodPhoto": empty])
    let client = try makeClient(transport)

    _ = try await client.foodAnalysis.analyzePhoto(.init(image: "https://example.com/meal.jpg"))
    _ = try await client.foodAnalysis.analyzePhoto(.init(image: "https://example.com/meal.jpg", reasoningEffort: .xhigh))
    _ = try await client.foodAnalysis.analyzePhoto(.init(image: "https://example.com/meal.jpg", reasoningEffort: AnalysisEffort.none))

    // Without a choice the request leaves `reasoning` out, and the API uses its default,
    // the reasoning-based analyzer; the SDK never fills in an effort of its own.
    let requests = await transport.requests()
    #expect(try json(requests[0].1)["reasoning"] == nil)
    #expect((try json(requests[1].1)["reasoning"] as? [String: Any])?["effort"] as? String == "xhigh")
    #expect((try json(requests[2].1)["reasoning"] as? [String: Any])?["effort"] as? String == "none")
}

@Test
func aConflictKeepsTheAPIsCodeAndMessageAsAValidationError() async throws {
    let body = #"{"code":"conflict","message":"This Idempotency-Key was already used with different files."}"#
    let client = try makeClient(StatusTransport(status: 409, body: body))

    let error = await #expect(throws: JanuaryError.self) {
        _ = try await client.foodAnalysis.analyzePhoto(.init(image: "https://example.com/meal.jpg"))
    }

    #expect(error?.category == .validation)
    #expect(error?.code == "conflict")
    #expect(error?.httpStatus == 409)
    #expect(error?.message == "This Idempotency-Key was already used with different files.")
    // A status the operation does not list, without an error body, still reports the status.
    let bare = apiError(errorCategory(for: 409), status: 409, response: nil)
    #expect(bare.category == .validation)
    #expect(bare.code == nil)
    #expect(bare.message == "The January API returned HTTP 409.")
}

@Test
func servingsAndAlternativesRequireTheirIDs() throws {
    let decoder = JSONDecoder()
    let serving = #"{"id":"34113801","quantity":0.5,"unit":"cup"}"#
    #expect(try decoder.decode(ServingOption.self, from: Data(serving.utf8)).id == ServingID(rawValue: "34113801"))
    #expect(throws: DecodingError.self) {
        try decoder.decode(ServingOption.self, from: Data(serving.replacingOccurrences(of: #""id":"34113801","#, with: "").utf8))
    }
    let alternative = #"{"id":"70372230","name":"brown rice","nutrients":{"calories":{"value":108,"unit":"kcal"}},"servings":[]}"#
    #expect(try decoder.decode(AlternativeFood.self, from: Data(alternative.utf8)).id == FoodID(rawValue: "70372230"))
    #expect(throws: DecodingError.self) {
        try decoder.decode(AlternativeFood.self, from: Data(alternative.replacingOccurrences(of: #""id":"70372230","#, with: "").utf8))
    }
}

@Test
func alternativesKeepTheirServingList() async throws {
    let body = #"{"alternatives":[{"id":"70372230","name":"brown rice","brand_name":null,"nutrients":{"calories":{"value":108,"unit":"kcal"}},"servings":[{"id":"34113801","quantity":0.5,"unit":"cup"}]}]}"#
    let client = try makeClient(ShapeTransport(bodies: ["suggestFoodAlternatives": body]))

    let response = try await client.foods.suggestAlternatives(.init(foodID: FoodID(rawValue: "1")))
    let alternative = try #require(response.alternatives.first)

    #expect(alternative.name == "brown rice")
    #expect(alternative.servings.first?.unit == "cup")
    #expect(alternative.servings.first?.quantity == 0.5)
}

@Test
func foodLogSummaryDecodesAndSendsRangeParameters() async throws {
    let transport = ShapeTransport(bodies: ["getFoodLogSummary": summary])
    let client = try makeClient(transport)

    let result = try await client.foodLogs.getSummary(start: "2026-09-14", end: "2026-09-14")

    let requests = await transport.requests()
    let request = try #require(requests.first?.0)
    let components = try #require(URLComponents(string: "https://example.invalid\(request.path ?? "")"))
    let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
    #expect(components.path == "/v1.2/food-logs/summary")
    #expect(query == ["start_date": "2026-09-14", "end_date": "2026-09-14", "timezone": "America/Chicago", "group_by": "day", "week_start": "monday"])
    #expect(request.headerFields[.init("January-End-User-ID")!] == "fixture-user")

    #expect(result.groupBy == .day)
    #expect(result.weekStart == nil)
    #expect(result.timezone == "America/Chicago")
    let day = try #require(result.buckets.first)
    #expect(result.buckets.count == 1)
    #expect(day.startDate == "2026-09-14")
    #expect(day.logsCount == 1)
    #expect(day.nutrients.calories?.value == 1853.06)
    #expect(result.totals.logsCount == 3)
    #expect(result.totals.daysWithLogs == 2)
    #expect(abs((result.averagePerLoggedDay.nutrients.calories?.value ?? 0) - 1828.244) < 0.001)
}

@Test
func weeklySummaryUsesTheRequestedWeekStart() async throws {
    let weekly = summary.replacingOccurrences(of: #""group_by": "day", "week_start": null"#, with: #""group_by": "week", "week_start": "sunday""#)
    let transport = ShapeTransport(bodies: ["getFoodLogSummary": weekly])
    let client = try makeClient(transport)

    let result = try await client.foodLogs.getSummary(.init(
        start: "2026-09-01", end: "2026-09-30", groupBy: .week, weekStart: .sunday,
        user: PartnerUserContext(endUserID: PartnerUserID(rawValue: "fixture-user"), timezone: TimeZone(identifier: "America/Chicago")!)
    ))

    let requests = await transport.requests()
    let path = try #require(requests.first?.0.path)
    #expect(path.contains("group_by=week"))
    #expect(path.contains("week_start=sunday"))
    #expect(result.groupBy == .week)
    #expect(result.weekStart == .sunday)
}
