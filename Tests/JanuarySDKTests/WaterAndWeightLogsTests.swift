import Foundation
import JanuaryPartnerTransport
import Testing
@_spi(JanuaryDevelopment) @testable import January

private struct LogRequest: Sendable {
    let operationID: String
    let path: String
    let endUserID: String?
    let body: [String: Any]?
}

private actor LogTransport: ClientTransport {
    private let status: Int?
    private let bodies: [String: String]
    private var recorded: [LogRequest] = []

    init(status: Int? = nil, bodies: [String: String] = [:]) {
        self.status = status
        self.bodies = bodies
    }

    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        var decoded: [String: Any]?
        if let body {
            let data = try await Data(collecting: body, upTo: 1_000_000)
            decoded = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        }
        recorded.append(LogRequest(
            operationID: operationID,
            path: request.path ?? "",
            endUserID: request.headerFields[HTTPField.Name("January-End-User-ID")!],
            body: decoded
        ))
        let code = status ?? (["createWaterLog", "createWeightLog"].contains(operationID) ? 201 : operationID == "deleteWaterLog" ? 204 : 200)
        var response = HTTPResponse(status: .init(code: code))
        let json = code >= 400
            ? #"{"code":"daily_water_limit_exceeded","message":"fixture failure"}"#
            : bodies[operationID] ?? Self.defaultBody(for: operationID)
        if code == 204 { return (response, nil) }
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(json))
    }

    func requests() -> [LogRequest] { recorded }

    private static func defaultBody(for operationID: String) -> String {
        switch operationID {
        case "createWaterLog":
            #"{"id":"9c1f2a3b-4d5e-4f60-8a71-b2c3d4e5f607","amount":{"value":8,"unit":"fl_oz"},"consumed_at":"2026-09-10T14:30:15.123Z"}"#
        case "listWaterLogs":
            #"{"items":[{"date":"2026-09-09","total":{"value":48.5,"unit":"fl_oz"}},{"date":"2026-09-10","total":{"value":64,"unit":"fl_oz"}}]}"#
        case "createWeightLog":
            #"{"weight":{"value":150,"unit":"lb"},"measured_at":"2026-09-10T14:30:15.123Z"}"#
        case "listWeightLogs":
            #"{"items":[{"date":"2026-09-08","weight":{"value":151.2,"unit":"lb"}},{"date":"2026-09-10","weight":{"value":68.2,"unit":"kg"}}]}"#
        default:
            "{}"
        }
    }
}

private let user = PartnerUserContext(endUserID: .init(rawValue: "oren-sdk-test"), timezone: TimeZone(identifier: "America/Los_Angeles")!)

private func client(_ transport: LogTransport, userContext: PartnerUserContext? = nil) throws -> JanuaryClient {
    try JanuaryClient(
        developmentAPIKey: "fixture-api-key",
        userContext: userContext,
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport
    )
}

@Test
func waterLogCreateSendsTheDocumentedBodyAndMapsTheResponse() async throws {
    let transport = LogTransport()
    let log = try await client(transport).waterLogs.create(.init(
        amount: .init(value: 8, unit: .fluidOunces), consumedAtUTC: "2026-09-10T07:30:15-07:00", user: user
    ))

    let request = try #require(await transport.requests().first)
    #expect(request.operationID == "createWaterLog")
    #expect(request.path == "/v1.2/water-logs")
    #expect(request.endUserID == "oren-sdk-test")
    #expect((request.body?["amount"] as? [String: Any])?["unit"] as? String == "fl_oz")
    #expect((request.body?["amount"] as? [String: Any])?["value"] as? Double == 8)
    #expect(request.body?["consumed_at"] as? String == "2026-09-10T14:30:15Z")
    #expect(log == WaterLog(id: "9c1f2a3b-4d5e-4f60-8a71-b2c3d4e5f607", amount: .init(value: 8, unit: .fluidOunces), consumedAtUTC: "2026-09-10T14:30:15.123Z"))
}

@Test
func waterLogCreateOmitsTheTimestampWhenNotSupplied() async throws {
    let transport = LogTransport()
    _ = try await client(transport, userContext: user).waterLogs.create(amount: .init(value: 250, unit: .milliliters))

    let request = try #require(await transport.requests().first)
    #expect(request.body?["consumed_at"] == nil)
    #expect((request.body?["amount"] as? [String: Any])?["unit"] as? String == "ml")
    #expect(request.endUserID == "oren-sdk-test")
}

@Test(arguments: [
    WaterAmount(value: 0.5, unit: .fluidOunces), WaterAmount(value: 812, unit: .fluidOunces),
    WaterAmount(value: 29, unit: .milliliters), WaterAmount(value: 24_001, unit: .milliliters),
    WaterAmount(value: 0.1, unit: .cups), WaterAmount(value: 101.5, unit: .cups),
    WaterAmount(value: .nan, unit: .milliliters),
])
func waterLogCreateRejectsAmountsOutsideTheDocumentedRanges(_ amount: WaterAmount) async throws {
    let transport = LogTransport()
    await #expect(throws: JanuaryError.self) {
        _ = try await client(transport).waterLogs.create(.init(amount: amount, user: user))
    }
    #expect(await transport.requests().isEmpty)
}

@Test
func waterLogCreateRejectsAMalformedTimestampBeforeTransport() async throws {
    let transport = LogTransport()
    let error = await #expect(throws: JanuaryError.self) {
        _ = try await client(transport).waterLogs.create(.init(amount: .init(value: 8, unit: .fluidOunces), consumedAtUTC: "yesterday", user: user))
    }
    #expect(error?.category == .validation)
    #expect(await transport.requests().isEmpty)
}

@Test
func waterLogListSendsRangeTimezoneAndUnitAndMapsDailyTotals() async throws {
    let transport = LogTransport()
    let totals = try await client(transport).waterLogs.list(.init(start: "2026-09-01", end: "2026-09-10", unit: .fluidOunces, user: user))

    let request = try #require(await transport.requests().first)
    #expect(request.operationID == "listWaterLogs")
    #expect(request.path.hasPrefix("/v1.2/water-logs?"))
    #expect(request.path.contains("start_date=2026-09-01"))
    #expect(request.path.contains("end_date=2026-09-10"))
    #expect(request.path.contains("timezone=America%2FLos_Angeles") || request.path.contains("timezone=America/Los_Angeles"))
    #expect(request.path.contains("unit=fl_oz"))
    #expect(totals.items == [
        DailyWaterTotal(date: "2026-09-09", total: .init(value: 48.5, unit: .fluidOunces)),
        DailyWaterTotal(date: "2026-09-10", total: .init(value: 64, unit: .fluidOunces)),
    ])
}

@Test(arguments: [0.125, 2, 101.4])
func waterLogsAcceptCupsAcrossTheDocumentedRange(_ value: Double) async throws {
    let transport = LogTransport(bodies: [
        "createWaterLog": #"{"id":"9c1f2a3b-4d5e-4f60-8a71-b2c3d4e5f607","amount":{"value":2,"unit":"cup"},"consumed_at":"2026-09-10T14:30:15.123Z"}"#,
        "listWaterLogs": #"{"items":[{"date":"2026-09-10","total":{"value":8,"unit":"cup"}}]}"#,
    ])
    let log = try await client(transport).waterLogs.create(.init(amount: .init(value: value, unit: .cups), user: user))
    let totals = try await client(transport).waterLogs.list(.init(start: "2026-09-10", end: "2026-09-10", unit: .cups, user: user))

    let requests = await transport.requests()
    #expect((requests[0].body?["amount"] as? [String: Any])?["unit"] as? String == "cup")
    #expect((requests[0].body?["amount"] as? [String: Any])?["value"] as? Double == value)
    #expect(requests[1].path.contains("unit=cup"))
    #expect(log.amount == .init(value: 2, unit: .cups))
    #expect(totals.items == [DailyWaterTotal(date: "2026-09-10", total: .init(value: 8, unit: .cups))])
}

@Test
func waterLogListDefaultsToFluidOuncesOnTheConfiguredClient() async throws {
    let transport = LogTransport()
    _ = try await client(transport, userContext: user).waterLogs.list(start: "2026-09-01", end: "2026-09-10")
    let request = try #require(await transport.requests().first)
    #expect(request.path.contains("unit=fl_oz"))
    #expect(request.endUserID == "oren-sdk-test")
}

@Test
func waterLogDeleteTargetsTheLogAndReturnsOnNoContent() async throws {
    let transport = LogTransport()
    try await client(transport).waterLogs.delete(.init(id: "9c1f2a3b-4d5e-4f60-8a71-b2c3d4e5f607", user: user))
    let request = try #require(await transport.requests().first)
    #expect(request.operationID == "deleteWaterLog")
    #expect(request.path == "/v1.2/water-logs/9c1f2a3b-4d5e-4f60-8a71-b2c3d4e5f607")
    #expect(request.endUserID == "oren-sdk-test")
    #expect(request.body == nil)
}

@Test
func unknownVolumeUnitsAreReportedAsDecodingErrors() async throws {
    let transport = LogTransport(bodies: ["listWaterLogs": #"{"items":[{"date":"2026-09-09","total":{"value":1,"unit":"cups"}}]}"#])
    let error = await #expect(throws: JanuaryError.self) {
        _ = try await client(transport).waterLogs.list(.init(start: "2026-09-01", end: "2026-09-10", user: user))
    }
    #expect(error?.category == .decoding)
}

@Test
func weightLogCreateSendsTheDocumentedBodyAndMapsTheResponse() async throws {
    let transport = LogTransport()
    let log = try await client(transport).weightLogs.create(.init(
        weight: .init(value: 150, unit: .pounds), measuredAtUTC: "2026-09-10T14:30:15Z", user: user
    ))

    let request = try #require(await transport.requests().first)
    #expect(request.operationID == "createWeightLog")
    #expect(request.path == "/v1.2/weight-logs")
    #expect(request.endUserID == "oren-sdk-test")
    #expect((request.body?["weight"] as? [String: Any])?["unit"] as? String == "lb")
    #expect((request.body?["weight"] as? [String: Any])?["value"] as? Double == 150)
    #expect(request.body?["measured_at"] as? String == "2026-09-10T14:30:15Z")
    #expect(log == WeightLog(weight: .init(value: 150, unit: .pounds), measuredAtUTC: "2026-09-10T14:30:15.123Z"))
}

@Test(arguments: [
    Weight(value: 9.9, unit: .pounds), Weight(value: 1_001, unit: .pounds),
    Weight(value: 4.4, unit: .kilograms), Weight(value: 453.7, unit: .kilograms),
])
func weightLogCreateRejectsWeightsOutsideTheDocumentedRanges(_ weight: Weight) async throws {
    let transport = LogTransport()
    let error = await #expect(throws: JanuaryError.self) {
        _ = try await client(transport, userContext: user).weightLogs.create(weight: weight)
    }
    #expect(error?.category == .validation)
    #expect(await transport.requests().isEmpty)
}

@Test
func weightLogListSendsRangeAndTimezoneAndMapsDailyWeights() async throws {
    let transport = LogTransport()
    let weights = try await client(transport, userContext: user).weightLogs.list(start: "2026-09-01", end: "2026-09-10")

    let request = try #require(await transport.requests().first)
    #expect(request.operationID == "listWeightLogs")
    #expect(request.path.contains("start_date=2026-09-01"))
    #expect(request.path.contains("end_date=2026-09-10"))
    #expect(request.path.contains("timezone="))
    #expect(!request.path.contains("unit="))
    #expect(weights.items == [
        DailyWeight(date: "2026-09-08", weight: .init(value: 151.2, unit: .pounds)),
        DailyWeight(date: "2026-09-10", weight: .init(value: 68.2, unit: .kilograms)),
    ])
}

@Test
func unknownWeightUnitsAreReportedAsDecodingErrors() async throws {
    let transport = LogTransport(bodies: ["createWeightLog": #"{"weight":{"value":10,"unit":"stone"},"measured_at":"2026-09-10T14:30:15.123Z"}"#])
    let error = await #expect(throws: JanuaryError.self) {
        _ = try await client(transport).weightLogs.create(.init(weight: .init(value: 150, unit: .pounds), user: user))
    }
    #expect(error?.category == .decoding)
}

@Test(arguments: [(400, ErrorCategory.validation), (401, .authentication), (403, .authorization), (429, .rateLimited), (500, .server), (418, .transport)])
func everyWaterAndWeightLogOperationMapsDeclaredAndUndocumentedStatuses(_ status: Int, _ category: ErrorCategory) async throws {
    let operations: [(JanuaryClient) async throws -> Void] = [
        { _ = try await $0.waterLogs.create(.init(amount: .init(value: 8, unit: .fluidOunces), user: user)) },
        { _ = try await $0.waterLogs.list(.init(start: "2026-09-01", end: "2026-09-10", user: user)) },
        { try await $0.waterLogs.delete(.init(id: UUID().uuidString, user: user)) },
        { _ = try await $0.weightLogs.create(.init(weight: .init(value: 70, unit: .kilograms), user: user)) },
        { _ = try await $0.weightLogs.list(.init(start: "2026-09-01", end: "2026-09-10", user: user)) },
    ]
    for operation in operations {
        let error = await #expect(throws: JanuaryError.self) {
            try await operation(try client(LogTransport(status: status)))
        }
        #expect(error?.category == category)
        #expect(error?.httpStatus == status)
        if status == 400 { #expect(error?.code == "daily_water_limit_exceeded") }
    }
}

@Test
func configuredClientIdentityOverridesTheRequestUserForLogs() async throws {
    let transport = LogTransport()
    let configured = PartnerUserContext(endUserID: .init(rawValue: "configured"), timezone: TimeZone(identifier: "Europe/Paris")!)
    let january = try client(transport, userContext: configured)
    _ = try await january.waterLogs.list(.init(start: "2026-09-01", end: "2026-09-10", user: user))
    _ = try await january.weightLogs.create(.init(weight: .init(value: 70, unit: .kilograms), user: user))
    let requests = await transport.requests()
    #expect(requests.map(\.endUserID) == ["configured", "configured"])
    #expect(requests[0].path.contains("Europe%2FParis") || requests[0].path.contains("Europe/Paris"))
}

@Test
func logModelsRoundTripTheirCodingKeys() throws {
    let water = WaterLog(id: "id", amount: .init(value: 8, unit: .fluidOunces), consumedAtUTC: "2026-09-10T14:30:15.123Z")
    let waterJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(water)) as? [String: Any]
    #expect(waterJSON?["consumed_at"] as? String == "2026-09-10T14:30:15.123Z")
    #expect(try JSONDecoder().decode(WaterLog.self, from: JSONEncoder().encode(water)) == water)

    let weight = WeightLog(weight: .init(value: 70, unit: .kilograms), measuredAtUTC: "2026-09-10T14:30:15.123Z")
    let weightJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(weight)) as? [String: Any]
    #expect(weightJSON?["measured_at"] as? String == "2026-09-10T14:30:15.123Z")
    #expect(try JSONDecoder().decode(WeightLog.self, from: JSONEncoder().encode(weight)) == weight)

    let summary = ServingSummary(id: .init(rawValue: "1"), quantity: 1, unit: "cup", weightGrams: 81)
    let summaryJSON = try JSONSerialization.jsonObject(with: JSONEncoder().encode(summary)) as? [String: Any]
    #expect(summaryJSON?["weight_grams"] as? Double == 81)
    #expect(VolumeUnit.allCases.map(\.rawValue) == ["fl_oz", "ml", "cup"])
    #expect(ListWaterLogsResponse(items: []) == ListWaterLogsResponse(items: []))
    #expect(ListWeightLogsResponse(items: []) == ListWeightLogsResponse(items: []))
}

// MARK: - Contract changes shared with the existing resources

private let scanWithWeight = #"{"meal_name":"Breakfast Bowl","total_nutrients":{},"detections":[{"confidence":"high","food":{"id":"789012","name":"Oatmeal","brand_name":null,"quantity":1,"serving":{"id":"45678","quantity":1,"unit":"cup","weight_grams":81},"nutrients":{}}}]}"#

@Test
func correctionSendsThePriorScanFieldForFieldIncludingServingWeight() async throws {
    let transport = LogTransport(bodies: ["scanFoodPhoto": scanWithWeight, "correctPhotoScan": scanWithWeight])
    let january = try client(transport)
    let scan = try await january.foodAnalysis.analyzePhoto(.init(image: "data:image/jpeg;base64,AA=="))
    #expect(scan.detections.first?.food.serving.weightGrams == 81)

    _ = try await january.foodAnalysis.correct(.init(analysis: scan, instruction: "change oatmeal to steel-cut oats"))

    let correction = try #require(await transport.requests().last)
    let analysis = try #require(correction.body?["analysis"] as? [String: Any])
    #expect(analysis["meal_name"] as? String == "Breakfast Bowl")
    let detection = try #require((analysis["detections"] as? [[String: Any]])?.first)
    #expect(detection["confidence"] as? String == "high")
    let food = try #require(detection["food"] as? [String: Any])
    #expect(food["id"] as? String == "789012")
    #expect(food["quantity"] as? Double == 1)
    #expect(food["name"] as? String == "Oatmeal")
    let serving = try #require(food["serving"] as? [String: Any])
    #expect(serving["id"] as? String == "45678")
    #expect(serving["unit"] as? String == "cup")
    #expect(serving["weight_grams"] as? Double == 81)
    #expect(correction.body?["instruction"] as? String == "change oatmeal to steel-cut oats")
}

@Test
func correctionRejectsAHandBuiltDetectionWithoutTheRequiredIdentifiers() async throws {
    let transport = LogTransport()
    let detection = FoodDetection(food: DetectedFood(id: nil, name: "Banana", nutrients: .init(), serving: .init(id: nil, unit: "serving"), quantity: nil))
    let error = await #expect(throws: JanuaryError.self) {
        _ = try await client(transport).foodAnalysis.correct(.init(analysis: FoodScan(detections: [detection]), instruction: "add"))
    }
    #expect(error?.category == .validation)
    #expect(await transport.requests().isEmpty)
}

@Test
func foodLogUpdateRejectsAnEmptyPatchBeforeTransport() async throws {
    let transport = LogTransport()
    let error = await #expect(throws: JanuaryError.self) {
        _ = try await client(transport).foodLogs.update(.init(id: UUID().uuidString, user: user))
    }
    #expect(error?.category == .validation)
    #expect(await transport.requests().isEmpty)
}

@Test
func glucosePredictionRejectsAFractionalAgeBeforeTransport() async throws {
    let transport = LogTransport()
    let food = FoodSelection(id: .init(rawValue: 1), serving: .init(id: .init(rawValue: 2), quantity: 1))
    let error = await #expect(throws: JanuaryError.self) {
        _ = try await client(transport).glucose.predict(.init(userProfile: .init(age: 35.5, gender: .female, height: 65, weight: 140), foods: [food], startTime: Date()))
    }
    #expect(error?.category == .validation)
    #expect(await transport.requests().isEmpty)
}

@Test
func transportDecoderRejectsUnknownKeysForClosedSchemas() throws {
    let known = try JSONDecoder().decode(Components.Schemas.UpdateFoodLogBody.self, from: Data(#"{"name":"Meal"}"#.utf8))
    #expect(known.name == "Meal")
    #expect(throws: DecodingError.self) {
        _ = try JSONDecoder().decode(Components.Schemas.UpdateFoodLogBody.self, from: Data(#"{"name":"Meal","extra":1}"#.utf8))
    }
}
