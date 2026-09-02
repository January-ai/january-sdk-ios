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
            user: configuredUser()
        ))
    }

    /// Lists food logs for the user configured on ``JanuaryClient``.
    public func list(start: String, end: String) async throws -> ListFoodLogsResponse {
        try await list(.init(start: start, end: end, user: configuredUser()))
    }

    /// Gets a single food log for the user configured on ``JanuaryClient``.
    public func get(id: String) async throws -> FoodLog {
        try await get(.init(id: id, user: configuredUser()))
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
            user: configuredUser()
        ))
    }

    /// Deletes a food log for the user configured on ``JanuaryClient``.
    public func delete(id: String) async throws -> DeleteFoodLogResponse {
        try await delete(.init(id: id, user: configuredUser()))
    }

    public func create(_ request: CreateFoodLogRequest) async throws -> FoodLog {
        var request = request
        request.user = resolvedUser(request.user)
        return try await performTransportRequest {
            let body = Components.Schemas.CreateFoodLogBody(
                foods: request.foods.map(mapSelection),
                eatenAt: try parseTimestamp(request.timestampUTC),
                name: request.name
            )
            let output = try await client.createFoodLog(
                .init(
                    headers: headers(request.user),
                    body: .json(body)
                )
            )
            switch output {
            case .created(let response): return try mapFoodLog(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    public func list(_ request: ListFoodLogsRequest) async throws -> ListFoodLogsResponse {
        var request = request
        request.user = resolvedUser(request.user)
        return try await performTransportRequest {
            let output = try await client.listFoodLogs(
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
                return ListFoodLogsResponse(
                    totalCount: value.items.count,
                    items: try value.items.map(mapFoodLog)
                )
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    public func get(_ request: GetFoodLogRequest) async throws -> FoodLog {
        var request = request
        request.user = resolvedUser(request.user)
        return try await performTransportRequest {
            let output = try await client.getFoodLog(.init(
                path: .init(logId: request.id),
                headers: .init(januaryEndUserID: request.user.endUserID?.rawValue)
            ))
            switch output {
            case .ok(let response): return try mapFoodLog(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .notFound(let response): throw apiError(.notFound, status: 404, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    public func update(_ request: UpdateFoodLogRequest) async throws -> FoodLog {
        var request = request
        request.user = resolvedUser(request.user)
        return try await performTransportRequest {
            let body = Components.Schemas.UpdateFoodLogBody(
                foods: request.foods?.map(mapSelection),
                eatenAt: try parseTimestamp(request.timestampUTC),
                name: request.name
            )
            let output = try await client.updateFoodLog(
                .init(path: .init(logId: request.id), headers: updateHeaders(request.user), body: .json(body))
            )
            switch output {
            case .ok(let response): return try mapFoodLog(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .notFound(let response): throw apiError(.notFound, status: 404, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    public func delete(_ request: DeleteFoodLogRequest) async throws -> DeleteFoodLogResponse {
        var request = request
        request.user = resolvedUser(request.user)
        return try await performTransportRequest {
            let output = try await client.deleteFoodLog(
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
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    private func headers(_ user: FoodLogUserContext) -> Operations.CreateFoodLog.Input.Headers {
        .init(januaryEndUserID: user.endUserID?.rawValue)
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

    private func updateHeaders(_ user: FoodLogUserContext) -> Operations.UpdateFoodLog.Input.Headers {
        .init(januaryEndUserID: user.endUserID?.rawValue)
    }

    private func mapFoodLog(_ value: Components.Schemas.FoodLog) throws -> FoodLog {
        FoodLog(
            id: value.id,
            foods: try value.foods.map { food in
                LoggedFood(
                    id: food.foodId.map { FoodID(rawValue: $0) },
                    name: food.name,
                    brandName: food.brandName,
                    imageURL: food.imageUrl,
                    glycemicIndex: food.glycemicIndex,
                    glycemicLoad: food.glycemicLoad,
                    nutrients: try ModelBridge.convert(food.nutrients),
                    consumedServing: .init(
                        id: food.serving.id.map { ServingID(rawValue: $0) },
                        quantity: food.quantity
                    ),
                    servingDetails: .init(
                        id: food.serving.id.map { ServingID(rawValue: $0) },
                        quantity: food.serving.quantity,
                        unit: food.serving.unit,
                        weightGrams: food.serving.weightGrams
                    )
                )
            },
            timestampUTC: formatTimestamp(value.eatenAt),
            name: value.name
        )
    }

    private func mapSelection(_ selection: FoodSelection) -> Components.Schemas.FoodLogInputFood {
        .init(
            foodId: selection.id.rawValue,
            servingId: selection.serving.id.rawValue,
            quantity: selection.serving.quantity
        )
    }

    private func formatTimestamp(_ value: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: value)
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
