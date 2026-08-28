import Foundation

/// A January client scoped to one partner-owned end-user identity.
///
/// Create this lightweight value from ``JanuaryClient/forUser(_:)``.
/// It reuses the underlying client and automatically applies the user ID across
/// every resource, plus the timezone where the API supports it.
public struct JanuaryUserClient: Sendable {
    public let context: PartnerUserContext
    public let foods: UserFoodsResource
    public let restaurants: UserRestaurantsResource
    public let photoScanning: UserPhotoScanningResource
    public let foodLogs: UserFoodLogsResource
    public let glucose: UserGlucoseResource

    internal init(client: JanuaryClient, context: PartnerUserContext) {
        self.context = context
        self.foods = UserFoodsResource(resource: client.foods, context: context)
        self.restaurants = UserRestaurantsResource(resource: client.restaurants, context: context)
        self.photoScanning = UserPhotoScanningResource(resource: client.photoScanning, context: context)
        self.foodLogs = UserFoodLogsResource(resource: client.foodLogs, context: context)
        self.glucose = UserGlucoseResource(resource: client.glucose, context: context)
    }
}

public extension JanuaryClient {
    /// Returns a lightweight client that reuses the supplied user context.
    func forUser(_ context: PartnerUserContext) -> JanuaryUserClient {
        JanuaryUserClient(client: self, context: context)
    }

    /// Returns a lightweight client scoped to an end user and optional timezone.
    func forUser(
        _ endUserID: PartnerUserID,
        timezone: String? = nil
    ) -> JanuaryUserClient {
        forUser(PartnerUserContext(endUserID: endUserID, timezone: timezone))
    }
}

/// Food operations that automatically reuse a ``PartnerUserContext``.
public struct UserFoodsResource: Sendable {
    private let resource: FoodsResource
    private let context: PartnerUserContext

    internal init(resource: FoodsResource, context: PartnerUserContext) {
        self.resource = resource
        self.context = context
    }

    public func autocomplete(
        _ request: AutocompleteFoodsRequest
    ) async throws -> AutocompleteFoodsResponse {
        var request = request
        request.endUserID = context.endUserID
        return try await resource.autocomplete(request)
    }

    public func getFood(_ request: GetFoodRequest) async throws -> FoodSearchItem {
        var request = request
        request.endUserID = context.endUserID
        return try await resource.getFood(request)
    }

    public func search(_ request: SearchFoodsRequest) async throws -> FoodSearchResults {
        var request = request
        request.endUserID = context.endUserID
        return try await resource.search(request)
    }

    public func lookupByBarcode(
        _ request: LookupFoodByBarcodeRequest
    ) async throws -> FoodSearchResults {
        var request = request
        request.endUserID = context.endUserID
        return try await resource.lookupByBarcode(request)
    }

    public func searchByNaturalLanguage(
        _ request: SearchFoodsByNaturalLanguageRequest
    ) async throws -> FoodScan {
        var request = request
        request.endUserID = context.endUserID
        return try await resource.searchByNaturalLanguage(request)
    }

    public func suggestAlternatives(
        _ request: SuggestFoodAlternativesRequest
    ) async throws -> SuggestFoodAlternativesResponse {
        var request = request
        request.endUserID = context.endUserID
        return try await resource.suggestAlternatives(request)
    }
}

/// Restaurant operations that automatically reuse a ``PartnerUserContext``.
public struct UserRestaurantsResource: Sendable {
    private let resource: RestaurantsResource
    private let context: PartnerUserContext

    internal init(resource: RestaurantsResource, context: PartnerUserContext) {
        self.resource = resource
        self.context = context
    }

    public func search(
        _ request: SearchRestaurantsRequest
    ) async throws -> SearchRestaurantsResponse {
        var request = request
        request.endUserID = context.endUserID
        return try await resource.search(request)
    }

    public func searchMenuItems(
        _ request: SearchRestaurantMenuItemsRequest
    ) async throws -> SearchRestaurantMenuItemsResponse {
        var request = request
        request.endUserID = context.endUserID
        return try await resource.searchMenuItems(request)
    }
}

/// Meal-scanning operations that automatically reuse a ``PartnerUserContext``.
public struct UserPhotoScanningResource: Sendable {
    private let resource: PhotoScanningResource
    private let context: PartnerUserContext

    internal init(resource: PhotoScanningResource, context: PartnerUserContext) {
        self.resource = resource
        self.context = context
    }

    public func scan(_ request: ScanFoodPhotoRequest) async throws -> FoodScan {
        var request = request
        request.endUserID = context.endUserID
        return try await resource.scan(request)
    }

    public func searchByNaturalLanguage(
        _ request: SearchFoodsByNaturalLanguageRequest
    ) async throws -> FoodScan {
        var request = request
        request.endUserID = context.endUserID
        return try await resource.searchByNaturalLanguage(request)
    }

    public func correct(_ request: CorrectPhotoScanRequest) async throws -> FoodScan {
        var request = request
        request.endUserID = context.endUserID
        return try await resource.correct(request)
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
