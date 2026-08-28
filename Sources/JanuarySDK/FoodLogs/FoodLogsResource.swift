import Foundation
import JanuaryPartnerTransport

public struct FoodLogsResource: Sendable {
    private let client: Client
    private let userContext: PartnerUserContext?
    internal init(client: Client, userContext: PartnerUserContext? = nil) {
        self.client = client
        self.userContext = userContext
    }

    /// Creates a food log for the user configured on ``JanuaryClient``.
    public func create(
        foods: [FoodSelection],
        timestampUTC: String? = nil,
        name: String? = nil
    ) async throws -> FoodLog {
        try await create(.init(
            foods: foods,
            timestampUTC: timestampUTC,
            name: name,
            user: try configuredUser()
        ))
    }

    /// Lists food logs for the user configured on ``JanuaryClient``.
    public func list(start: String, end: String) async throws -> ListFoodLogsResponse {
        try await list(.init(start: start, end: end, user: try configuredUser()))
    }

    /// Updates a food log for the user configured on ``JanuaryClient``.
    public func update(
        id: String,
        foods: [FoodSelection]? = nil,
        timestampUTC: String? = nil,
        name: String? = nil
    ) async throws -> FoodLog {
        try await update(.init(
            id: id,
            foods: foods,
            timestampUTC: timestampUTC,
            name: name,
            user: try configuredUser()
        ))
    }

    /// Deletes a food log for the user configured on ``JanuaryClient``.
    public func delete(id: String) async throws -> DeleteFoodLogResponse {
        try await delete(.init(id: id, user: try configuredUser()))
    }

    public func create(_ request: CreateFoodLogRequest) async throws -> FoodLog {
        var request = request
        if let userContext { request.user = userContext }
        return try await performTransportRequest {
            let body = Components.Schemas.CreateFoodLogBody(
                foods: try ModelBridge.convert(request.foods),
                timestampUtc: try parseTimestamp(request.timestampUTC),
                name: request.name
            )
            let output = try await client.createFoodLog(
                .init(
                    headers: headers(request.user),
                    body: .json(body)
                )
            )
            switch output {
            case .ok(let response): return try mapFoodLog(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    public func list(_ request: ListFoodLogsRequest) async throws -> ListFoodLogsResponse {
        var request = request
        if let userContext { request.user = userContext }
        return try await performTransportRequest {
            let output = try await client.listFoodLogs(
                .init(
                    query: .init(start: request.start, end: request.end),
                    headers: .init(
                        xEndUserId: request.user.endUserID.rawValue,
                        xEndUserTimezone: request.user.timezone
                    )
                )
            )
            switch output {
            case .ok(let response):
                let value = try response.body.json
                return ListFoodLogsResponse(
                    totalCount: Int(value.totalCount),
                    items: try value.items.map(mapFoodLog)
                )
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    public func update(_ request: UpdateFoodLogRequest) async throws -> FoodLog {
        var request = request
        if let userContext { request.user = userContext }
        return try await performTransportRequest {
            let body = Components.Schemas.UpdateFoodLogBody(
                foods: try request.foods.map {
                    try ModelBridge.convert($0, to: [Components.Schemas.FoodLogInputFood].self)
                },
                timestampUtc: request.timestampUTC,
                name: request.name
            )
            let output = try await client.updateFoodLog(
                .init(path: .init(logId: request.id), headers: updateHeaders(request.user), body: .json(body))
            )
            switch output {
            case .ok(let response): return try mapFoodLog(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .notFound(let response): throw apiError(.notFound, status: 404, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    public func delete(_ request: DeleteFoodLogRequest) async throws -> DeleteFoodLogResponse {
        var request = request
        if let userContext { request.user = userContext }
        return try await performTransportRequest {
            let output = try await client.deleteFoodLog(
                .init(
                    path: .init(logId: request.id),
                    headers: .init(
                        xEndUserId: request.user.endUserID.rawValue,
                        xEndUserTimezone: request.user.timezone
                    )
                )
            )
            switch output {
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    private func headers(_ user: FoodLogUserContext) -> Operations.CreateFoodLog.Input.Headers {
        .init(xEndUserId: user.endUserID.rawValue, xEndUserTimezone: user.timezone)
    }

    private func configuredUser() throws -> PartnerUserContext {
        guard let userContext else {
            throw JanuaryError(
                category: .validation,
                code: "missing_user_context",
                message: "Configure an end-user ID on JanuaryClient before using Food Logs."
            )
        }
        return userContext
    }

    private func updateHeaders(_ user: FoodLogUserContext) -> Operations.UpdateFoodLog.Input.Headers {
        .init(xEndUserId: user.endUserID.rawValue, xEndUserTimezone: user.timezone)
    }

    private func mapFoodLog(_ value: Components.Schemas.FoodLog) throws -> FoodLog {
        FoodLog(
            id: value.id,
            foods: try ModelBridge.convert(value.foods),
            timestampUTC: value.timestampUtc,
            name: value.name
        )
    }

    private func parseTimestamp(_ value: String?) throws -> Date? {
        guard let value else { return nil }
        let standard = ISO8601DateFormatter()
        if let date = standard.date(from: value) { return date }

        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }

        throw JanuaryError(
            category: .validation,
            message: "timestampUTC must be an ISO-8601 date-time."
        )
    }
}
