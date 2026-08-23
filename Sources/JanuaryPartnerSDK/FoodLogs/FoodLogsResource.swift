import JanuaryPartnerTransport

public struct FoodLogsResource: Sendable {
    private let client: Client
    internal init(client: Client) { self.client = client }

    public func create(_ request: CreateFoodLogRequest) async throws -> FoodLog {
        try await performTransportRequest {
            let body: Components.Schemas.CreateFoodLogBody = try ModelBridge.convert(
                CreateBody(foods: request.foods, timestampUTC: request.timestampUTC, name: request.name)
            )
            let output = try await client.createFoodLog(
                .init(
                    headers: headers(request.user),
                    body: .json(body)
                )
            )
            switch output {
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, message: try response.body.json.message)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, message: try response.body.json.message)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, message: try response.body.json.message)
            case .undocumented(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    public func list(_ request: ListFoodLogsRequest) async throws -> ListFoodLogsResponse {
        try await performTransportRequest {
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
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, message: try response.body.json.message)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, message: try response.body.json.message)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, message: try response.body.json.message)
            case .undocumented(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    public func update(_ request: UpdateFoodLogRequest) async throws -> FoodLog {
        try await performTransportRequest {
            let body: Components.Schemas.UpdateFoodLogBody = try ModelBridge.convert(
                UpdateBody(foods: request.foods, timestampUTC: request.timestampUTC, name: request.name)
            )
            let output = try await client.updateFoodLog(
                .init(path: .init(logId: request.id), headers: updateHeaders(request.user), body: .json(body))
            )
            switch output {
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, message: try response.body.json.message)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, message: try response.body.json.message)
            case .notFound(let response): throw apiError(.notFound, status: 404, message: try response.body.json.message)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, message: try response.body.json.message)
            case .undocumented(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    public func delete(_ request: DeleteFoodLogRequest) async throws -> DeleteFoodLogResponse {
        try await performTransportRequest {
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
            case .badRequest(let response): throw apiError(.validation, status: 400, message: try response.body.json.message)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, message: try response.body.json.message)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, message: try response.body.json.message)
            case .undocumented(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    private func headers(_ user: FoodLogUserContext) -> Operations.CreateFoodLog.Input.Headers {
        .init(xEndUserId: user.endUserID.rawValue, xEndUserTimezone: user.timezone)
    }

    private func updateHeaders(_ user: FoodLogUserContext) -> Operations.UpdateFoodLog.Input.Headers {
        .init(xEndUserId: user.endUserID.rawValue, xEndUserTimezone: user.timezone)
    }
}

private struct CreateBody: Codable {
    let foods: [FoodSelection]; let timestampUTC: String?; let name: String?
    enum CodingKeys: String, CodingKey { case foods, name; case timestampUTC = "timestamp_utc" }
}

private struct UpdateBody: Codable {
    let foods: [FoodSelection]?; let timestampUTC: String?; let name: String?
    enum CodingKeys: String, CodingKey { case foods, name; case timestampUTC = "timestamp_utc" }
}

