import Foundation
import JanuaryPartnerTransport

/// Water intake logs for a partner-owned user.
public struct WaterLogsResource: Sendable {
    private let client: Client
    private let userContext: PartnerUserContext?
    internal init(client: Client, userContext: PartnerUserContext? = nil) {
        self.client = client
        self.userContext = userContext
    }

    /// Logs one amount of water for the user configured on ``JanuaryClient``.
    public func create(amount: WaterAmount, consumedAtUTC: String? = nil) async throws -> WaterLog {
        try await create(.init(amount: amount, consumedAtUTC: consumedAtUTC, user: configuredUser()))
    }

    /// Lists daily water totals for the user configured on ``JanuaryClient``.
    public func list(start: String, end: String, unit: VolumeUnit = .fluidOunces) async throws -> ListWaterLogsResponse {
        try await list(.init(start: start, end: end, unit: unit, user: configuredUser()))
    }

    /// Deletes a water log for the user configured on ``JanuaryClient``. Deleting an unknown log also succeeds.
    public func delete(id: String) async throws -> DeleteWaterLogResponse {
        try await delete(.init(id: id, user: configuredUser()))
    }

    public func create(_ request: CreateWaterLogRequest) async throws -> WaterLog {
        var request = request
        request.user = resolvedUser(request.user)
        try validate(request.amount)
        return try await performTransportRequest {
            let body = Components.Schemas.CreateWaterLogBody(
                amount: .init(value: request.amount.value, unit: request.amount.unit.rawValue),
                consumedAt: try ISO8601Timestamp.parse(request.consumedAtUTC, field: "consumedAtUTC")
            )
            let output = try await client.createWaterLog(
                .init(headers: .init(januaryEndUserID: request.user.endUserID?.rawValue), body: .json(body))
            )
            switch output {
            case .created(let response): return try mapWaterLog(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, let response): throw apiError(errorCategory(for: status), status: status, response: try? response.body.json)
            }
        }
    }

    public func list(_ request: ListWaterLogsRequest) async throws -> ListWaterLogsResponse {
        var request = request
        request.user = resolvedUser(request.user)
        return try await performTransportRequest {
            let output = try await client.listWaterLogs(
                .init(
                    query: .init(
                        startDate: request.start,
                        endDate: request.end,
                        timezone: request.user.timezone.identifier,
                        unit: request.unit.rawValue
                    ),
                    headers: .init(januaryEndUserID: request.user.endUserID?.rawValue)
                )
            )
            switch output {
            case .ok(let response):
                let value = try response.body.json
                return ListWaterLogsResponse(items: try value.items.map { item in
                    DailyWaterTotal(date: item.date, total: .init(value: item.total.value, unit: try volumeUnit(item.total.unit)))
                })
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, let response): throw apiError(errorCategory(for: status), status: status, response: try? response.body.json)
            }
        }
    }

    public func delete(_ request: DeleteWaterLogRequest) async throws -> DeleteWaterLogResponse {
        var request = request
        request.user = resolvedUser(request.user)
        return try await performTransportRequest {
            let output = try await client.deleteWaterLog(
                .init(
                    path: .init(logId: request.id),
                    headers: .init(januaryEndUserID: request.user.endUserID?.rawValue)
                )
            )
            switch output {
            case .noContent: return ()
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, let response): throw apiError(errorCategory(for: status), status: status, response: try? response.body.json)
            }
        }
    }

    private func validate(_ amount: WaterAmount) throws {
        let range: ClosedRange<Double> = switch amount.unit {
        case .fluidOunces: 1...811.5
        case .milliliters: 30...24_000
        case .cups: 0.125...101.4
        }
        guard amount.value.isFinite, range.contains(amount.value) else {
            throw JanuaryError(
                category: .validation,
                message: "amount.value must be between \(range.lowerBound.formatted()) and \(range.upperBound.formatted()) \(amount.unit.rawValue)."
            )
        }
    }

    private func mapWaterLog(_ value: Components.Schemas.WaterLog) throws -> WaterLog {
        WaterLog(
            id: value.id,
            amount: .init(value: value.amount.value, unit: try volumeUnit(value.amount.unit)),
            consumedAtUTC: ISO8601Timestamp.format(value.consumedAt)
        )
    }

    private func volumeUnit(_ raw: String) throws -> VolumeUnit {
        guard let unit = VolumeUnit(rawValue: raw) else {
            throw JanuaryError(category: .decoding, message: "The January API returned an unknown volume unit \"\(raw)\".")
        }
        return unit
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
