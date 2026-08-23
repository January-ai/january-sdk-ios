import Foundation

public struct FoodLogUserContext: Hashable, Sendable {
    public var endUserID: PartnerUserID
    public var timezone: String?
    public init(endUserID: PartnerUserID, timezone: String? = nil) { self.endUserID = endUserID; self.timezone = timezone }
}

public struct CreateFoodLogRequest: Hashable, Sendable {
    public var foods: [FoodSelection]
    public var timestampUTC: String?
    public var name: String?
    public var user: FoodLogUserContext
    public init(foods: [FoodSelection], timestampUTC: String? = nil, name: String? = nil, user: FoodLogUserContext) {
        self.foods = foods; self.timestampUTC = timestampUTC; self.name = name; self.user = user
    }
}

public struct UpdateFoodLogRequest: Hashable, Sendable {
    public var id: String
    public var foods: [FoodSelection]?
    public var timestampUTC: String?
    public var name: String?
    public var user: FoodLogUserContext
    public init(id: String, foods: [FoodSelection]? = nil, timestampUTC: String? = nil, name: String? = nil, user: FoodLogUserContext) {
        self.id = id; self.foods = foods; self.timestampUTC = timestampUTC; self.name = name; self.user = user
    }
}

public struct ListFoodLogsRequest: Hashable, Sendable {
    public var start: String; public var end: String; public var user: FoodLogUserContext
    public init(start: String, end: String, user: FoodLogUserContext) { self.start = start; self.end = end; self.user = user }
}

public struct DeleteFoodLogRequest: Hashable, Sendable {
    public var id: String; public var user: FoodLogUserContext
    public init(id: String, user: FoodLogUserContext) { self.id = id; self.user = user }
}

public struct ConsumedServing: Codable, Hashable, Sendable {
    public var id: ServingID; public var quantity: Double
    public init(id: ServingID, quantity: Double) { self.id = id; self.quantity = quantity }
}

public struct ServingDetails: Codable, Hashable, Sendable {
    public var id: ServingID; public var quantity: Double; public var unit: String; public var weightGrams: Double?
    public init(id: ServingID, quantity: Double, unit: String, weightGrams: Double? = nil) {
        self.id = id; self.quantity = quantity; self.unit = unit; self.weightGrams = weightGrams
    }
    enum CodingKeys: String, CodingKey { case id, quantity, unit; case weightGrams = "weight_grams" }
}

public struct LoggedFood: Codable, Hashable, Sendable {
    public var id: FoodID; public var name: String; public var brandName: String?; public var imageURL: String?
    public var glycemicIndex: Double?; public var glycemicLoad: Double?; public var nutrients: NutritionFacts
    public var consumedServing: ConsumedServing; public var servingDetails: ServingDetails
    enum CodingKeys: String, CodingKey {
        case id, name, nutrients; case brandName = "brand_name"; case imageURL = "image_url"
        case glycemicIndex = "glycemic_index"; case glycemicLoad = "glycemic_load"
        case consumedServing = "consumed_serving"; case servingDetails = "serving_details"
    }
}

public struct FoodLog: Codable, Hashable, Sendable {
    public var id: String; public var foods: [LoggedFood]; public var timestampUTC: String; public var name: String?
    public init(id: String, foods: [LoggedFood], timestampUTC: String, name: String? = nil) {
        self.id = id; self.foods = foods; self.timestampUTC = timestampUTC; self.name = name
    }
    enum CodingKeys: String, CodingKey { case id, foods, name; case timestampUTC = "timestamp_utc" }
}

public struct ListFoodLogsResponse: Codable, Hashable, Sendable {
    public var totalCount: Int; public var items: [FoodLog]
    public init(totalCount: Int, items: [FoodLog]) { self.totalCount = totalCount; self.items = items }
    enum CodingKeys: String, CodingKey { case items; case totalCount = "total_count" }
}

public struct DeleteFoodLogResponse: Codable, Hashable, Sendable {
    public var status: String
    public init(status: String) { self.status = status }
}
