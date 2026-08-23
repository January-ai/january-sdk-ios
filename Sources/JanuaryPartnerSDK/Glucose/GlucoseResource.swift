import Foundation
import JanuaryPartnerTransport

public struct GlucoseResource: Sendable {
    private let client: Client
    internal init(client: Client) { self.client = client }

    public func predict(_ request: PredictGlucoseRequest) async throws -> GlucosePrediction {
        try await performTransportRequest {
            let body: Components.Schemas.PredictGlucoseBody = try ModelBridge.convert(
                PredictBody(
                    userProfile: request.userProfile,
                    foods: request.foods,
                    startTime: request.startTime,
                    cgmData: request.cgmData,
                    consumedFoods: request.consumedFoods
                )
            )
            let output = try await client.predictGlucose(
                .init(
                    headers: .init(
                        xEndUserId: request.endUserID?.rawValue,
                        xEndUserTimezone: request.timezone
                    ),
                    body: .json(body)
                )
            )
            switch output {
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .gatewayTimeout(let response): throw apiError(.timeout, status: 504, response: try response.body.json)
            case .undocumented(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }
}

private struct PredictBody: Codable {
    let userProfile: GlucosePredictionProfile
    let foods: [FoodSelection]
    let startTime: Date
    let cgmData: [CgmReading]?
    let consumedFoods: [ConsumedHistoricalFood]?
    enum CodingKeys: String, CodingKey {
        case foods; case userProfile = "user_profile"; case startTime = "start_time"
        case cgmData = "cgm_data"; case consumedFoods = "consumed_foods"
    }
}
