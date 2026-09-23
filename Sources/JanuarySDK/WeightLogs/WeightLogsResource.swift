import Foundation
import JanuaryPartnerTransport

/// Body-weight logs for a partner-owned user.
public struct WeightLogsResource: Sendable {
    private let client: Client
    private let userContext: PartnerUserContext?
    internal init(client: Client, userContext: PartnerUserContext? = nil) {
        self.client = client
        self.userContext = userContext
    }

    /// Logs one weight measurement for the user configured on ``JanuaryClient``.
    public func create(weight: Weight, measuredAtUTC: String? = nil) async throws -> WeightLog {
        try await create(.init(weight: weight, measuredAtUTC: measuredAtUTC, user: configuredUser()))
    }

    /// Lists the latest weight per day for the user configured on ``JanuaryClient``.
    public func list(start: String, end: String) async throws -> ListWeightLogsResponse {
        try await list(.init(start: start, end: end, user: configuredUser()))
    }

    public func create(_ request: CreateWeightLogRequest) async throws -> WeightLog {
        var request = request
        request.user = resolvedUser(request.user)
        try validate(request.weight)
        return try await performTransportRequest {
            let body = Components.Schemas.CreateWeightLogBody(
                weight: .init(value: request.weight.value, unit: request.weight.unit.rawValue),
                createdAt: try ISO8601Timestamp.parse(request.measuredAtUTC, field: "measuredAtUTC")
            )
            let output = try await client.createWeightLog(
                .init(headers: .init(januaryEndUserID: request.user.endUserID?.rawValue), body: .json(body))
            )
            switch output {
            case .created(let response):
                let value = try response.body.json
                return WeightLog(weight: try mapWeight(value.weight), measuredAtUTC: ISO8601Timestamp.format(value.createdAt))
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, let response): throw apiError(errorCategory(for: status), status: status, response: try? response.body.json)
            }
        }
    }

    public func list(_ request: ListWeightLogsRequest) async throws -> ListWeightLogsResponse {
        var request = request
        request.user = resolvedUser(request.user)
        return try await performTransportRequest {
            let output = try await client.listWeightLogs(
                .init(
                    query: .init(
                        startDate: request.start,
                        endDate: request.end,
                        timezone: request.user.timezone.identifier
                    ),
                    headers: .init(januaryEndUserID: request.user.endUserID?.rawValue)
                )
            )
            switch output {
            case .ok(let response):
                let value = try response.body.json
                return ListWeightLogsResponse(items: try value.items.map { item in
                    DailyWeight(date: item.date, weight: try mapWeight(item.weight))
                })
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, let response): throw apiError(errorCategory(for: status), status: status, response: try? response.body.json)
            }
        }
    }

    private func validate(_ weight: Weight) throws {
        let range: ClosedRange<Double> = switch weight.unit {
        case .pounds: 10...1_000
        case .kilograms: 4.5...453.6
        }
        guard weight.value.isFinite, range.contains(weight.value) else {
            throw JanuaryError(
                category: .validation,
                message: "weight.value must be between \(range.lowerBound.formatted()) and \(range.upperBound.formatted()) \(weight.unit.rawValue)."
            )
        }
    }

    private func mapWeight(_ value: Components.Schemas.Weight) throws -> Weight {
        guard let unit = WeightUnit(rawValue: value.unit) else {
            throw JanuaryError(category: .decoding, message: "The January API returned an unknown weight unit \"\(value.unit)\".")
        }
        return Weight(value: value.value, unit: unit)
    }

    private func configuredUser() -> PartnerUserContext {
        userContext ?? PartnerUserContext()
    }

    private func resolvedUser(_ requestUser: PartnerUserContext) -> PartnerUserContext {
        guard let userContext else { return requestUser }
        return PartnerUserContext(
            endUserID: userContext.endUserID ?? requestUser.endUserID,
            timezone: userContext.timezone
        )
    }
}
