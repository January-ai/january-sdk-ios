import Foundation
import JanuaryPartnerTransport

public struct GlucoseResource: Sendable {
    private let client: Client
    private let userContext: PartnerUserContext?
    internal init(client: Client, userContext: PartnerUserContext? = nil) {
        self.client = client
        self.userContext = userContext
    }

    public func predict(_ request: PredictGlucoseRequest) async throws -> GlucosePrediction {
        try await performTransportRequest {
            let body = Components.Schemas.PredictGlucoseBody(
                userProfile: try ModelBridge.convert(request.userProfile),
                timezone: userContext?.timezone.identifier ?? request.timezone?.identifier ?? "UTC",
                foods: request.foods.map {
                    .init(
                        foodId: $0.id.rawValue,
                        servingId: $0.serving.id.rawValue,
                        quantity: $0.serving.quantity
                    )
                },
                startTime: request.startTime,
                cgmData: try request.cgmData?.map {
                    .init(timestamp: try parseTimestamp($0.timestamp), value: $0.value)
                },
                consumedFoods: try request.consumedFoods?.map {
                    .init(
                        timestamp: try parseTimestamp($0.timestamp),
                        foodId: $0.id.rawValue,
                        servingId: $0.serving.id.rawValue,
                        quantity: $0.serving.quantity
                    )
                }
            )
            let output = try await client.predictGlucose(
                .init(
                    body: .json(body)
                )
            )
            switch output {
            case .ok(let response):
                let value = try response.body.json
                return GlucosePrediction(
                    prediction: value.points.map { .init(minutes: Double($0.minutes), value: $0.value) },
                    impact: value.impactScore.map { GlucoseImpact(rawValue: $0) },
                    chart: .init(min: value.chart.min, max: value.chart.max)
                )
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .gatewayTimeout(let response): throw apiError(.timeout, status: 504, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    private func parseTimestamp(_ value: String) throws -> Date {
        let standard = ISO8601DateFormatter()
        if let date = standard.date(from: value) { return date }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }

        throw JanuaryError(
            category: .validation,
            message: "CGM and consumed-food timestamps must be ISO-8601 date-times."
        )
    }
}
