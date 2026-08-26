import Foundation

/// A January client scoped to one partner-owned end-user identity.
///
/// Create this lightweight value from ``JanuaryPartnerClient/forUser(_:)``.
/// It reuses the underlying client and automatically applies the user ID and
/// timezone to Food Logs and Glucose requests.
public struct JanuaryPartnerUserClient: Sendable {
    public let context: PartnerUserContext
    public let foodLogs: UserFoodLogsResource
    public let glucose: UserGlucoseResource

    internal init(client: JanuaryPartnerClient, context: PartnerUserContext) {
        self.context = context
        self.foodLogs = UserFoodLogsResource(resource: client.foodLogs, context: context)
        self.glucose = UserGlucoseResource(resource: client.glucose, context: context)
    }
}

public extension JanuaryPartnerClient {
    /// Returns a lightweight client that reuses the supplied user context.
    func forUser(_ context: PartnerUserContext) -> JanuaryPartnerUserClient {
        JanuaryPartnerUserClient(client: self, context: context)
    }

    /// Returns a lightweight client scoped to an end user and optional timezone.
    func forUser(
        _ endUserID: PartnerUserID,
        timezone: String? = nil
    ) -> JanuaryPartnerUserClient {
        forUser(PartnerUserContext(endUserID: endUserID, timezone: timezone))
    }
}

/// Food Log operations that automatically reuse a ``PartnerUserContext``.
public struct UserFoodLogsResource: Sendable {
    private let resource: FoodLogsResource
    private let context: PartnerUserContext

    internal init(resource: FoodLogsResource, context: PartnerUserContext) {
        self.resource = resource
        self.context = context
    }

    public func create(
        foods: [FoodSelection],
        timestampUTC: String? = nil,
        name: String? = nil
    ) async throws -> FoodLog {
        try await resource.create(.init(
            foods: foods,
            timestampUTC: timestampUTC,
            name: name,
            user: context
        ))
    }

    public func list(start: String, end: String) async throws -> ListFoodLogsResponse {
        try await resource.list(.init(start: start, end: end, user: context))
    }

    public func update(
        id: String,
        foods: [FoodSelection]? = nil,
        timestampUTC: String? = nil,
        name: String? = nil
    ) async throws -> FoodLog {
        try await resource.update(.init(
            id: id,
            foods: foods,
            timestampUTC: timestampUTC,
            name: name,
            user: context
        ))
    }

    public func delete(id: String) async throws -> DeleteFoodLogResponse {
        try await resource.delete(.init(id: id, user: context))
    }
}

/// Glucose operations that automatically reuse a ``PartnerUserContext``.
public struct UserGlucoseResource: Sendable {
    private let resource: GlucoseResource
    private let context: PartnerUserContext

    internal init(resource: GlucoseResource, context: PartnerUserContext) {
        self.resource = resource
        self.context = context
    }

    /// Predicts glucose after replacing any identity fields on `request` with
    /// the identity attached to this scoped client.
    public func predict(_ request: PredictGlucoseRequest) async throws -> GlucosePrediction {
        var request = request
        request.endUserID = context.endUserID
        request.timezone = context.timezone
        return try await resource.predict(request)
    }
}
