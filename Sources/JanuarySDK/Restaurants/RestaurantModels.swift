import Foundation

public struct GetRestaurantMenuItemsRequest: Hashable, Sendable {
    public var restaurantID: String
    public var limit: Int
    public var offset: Int
    public var endUserID: PartnerUserID?
    public init(restaurantID: String, limit: Int = 100, offset: Int = 0, endUserID: PartnerUserID? = nil) {
        self.restaurantID = restaurantID; self.limit = limit; self.offset = offset; self.endUserID = endUserID
    }
}

public struct SearchRestaurantsRequest: Hashable, Sendable {
    public var query: String
    public var latitude: Double
    public var longitude: Double
    public var radius: Double
    public var limit: Int
    public var endUserID: PartnerUserID?
    public init(query: String, latitude: Double, longitude: Double, radius: Double = 8000, limit: Int = 10, endUserID: PartnerUserID? = nil) {
        self.query = query; self.latitude = latitude; self.longitude = longitude
        self.radius = radius; self.limit = limit; self.endUserID = endUserID
    }
}

public struct SearchRestaurantMenuItemsRequest: Hashable, Sendable {
    public var query: String
    public var latitude: Double
    public var longitude: Double
    public var radius: Double
    public var limit: Int
    public var endUserID: PartnerUserID?
    public init(query: String, latitude: Double, longitude: Double, radius: Double = 8000, limit: Int = 10, endUserID: PartnerUserID? = nil) {
        self.query = query; self.latitude = latitude; self.longitude = longitude
        self.radius = radius; self.limit = limit; self.endUserID = endUserID
    }
}

public enum RestaurantResultType: String, Codable, Hashable, Sendable { case restaurant; case menuItem = "menu_item" }

public struct Restaurant: Codable, Hashable, Sendable {
    public var type: RestaurantResultType
    public var id: String
    public var name: String?
    public var isChain: Bool?
    public var distance: Double?
    public var city: String?
    public var address1: String?
    public var address2: String?
    public init(type: RestaurantResultType, id: String, name: String?, isChain: Bool? = nil, distance: Double? = nil, city: String? = nil, address1: String? = nil, address2: String? = nil) {
        self.type = type; self.id = id; self.name = name; self.isChain = isChain; self.distance = distance
        self.city = city; self.address1 = address1; self.address2 = address2
    }
    enum CodingKeys: String, CodingKey { case type, id, name, distance, city, address1, address2; case isChain = "is_chain" }
}

public struct SearchRestaurantsResponse: Codable, Hashable, Sendable {
    public var totalCount: Int
    public var items: [Restaurant]
    public init(totalCount: Int, items: [Restaurant]) { self.totalCount = totalCount; self.items = items }
    enum CodingKeys: String, CodingKey { case items; case totalCount = "total_count" }
}

public struct RestaurantMenuItem: Codable, Hashable, Sendable {
    public var type: String
    public var id: String
    public var name: String?
    public var restaurantName: String?
    public var isChain: Bool?
    public var calories: Double?
    public var protein: Double?
    public var carbohydrates: Double?
    public var netCarbohydrates: Double?
    public var totalFat: Double?
    public var fiber: Double?
    public var totalSugars: Double?
    public var addedSugars: Double?
    public var glycemicIndex: Double?
    public var glycemicLoad: Double?
    public var photoURL: String?
    public var distance: Double?
    public var servings: [ServingOption]

    public init(
        type: String = "menu_item", id: String, name: String?, restaurantName: String?,
        isChain: Bool? = nil, calories: Double? = nil, protein: Double? = nil,
        carbohydrates: Double? = nil, netCarbohydrates: Double? = nil,
        totalFat: Double? = nil, fiber: Double? = nil, totalSugars: Double? = nil,
        addedSugars: Double? = nil, glycemicIndex: Double? = nil,
        glycemicLoad: Double? = nil, photoURL: String? = nil,
        distance: Double? = nil, servings: [ServingOption]
    ) {
        self.type = type; self.id = id; self.name = name; self.restaurantName = restaurantName
        self.isChain = isChain; self.calories = calories; self.protein = protein
        self.carbohydrates = carbohydrates; self.netCarbohydrates = netCarbohydrates
        self.totalFat = totalFat; self.fiber = fiber; self.totalSugars = totalSugars
        self.addedSugars = addedSugars; self.glycemicIndex = glycemicIndex
        self.glycemicLoad = glycemicLoad; self.photoURL = photoURL
        self.distance = distance; self.servings = servings
    }

    enum CodingKeys: String, CodingKey {
        case type, id, name, protein, fiber, distance, servings
        case restaurantName = "restaurant_name"; case isChain = "is_chain"; case calories = "energy"
        case carbohydrates = "carbs"; case netCarbohydrates = "net_carbs"; case totalFat = "fat"
        case totalSugars = "sugars"; case addedSugars = "added_sugars"; case glycemicIndex = "gi"
        case glycemicLoad = "gl"; case photoURL = "photo_url"
    }
}

public struct RestaurantMenuEntry: Codable, Hashable, Sendable {
    public var id: String?
    public var name: String?
    public var calories: Double?
    public var protein: Double?
    public var carbohydrates: Double?
    public var netCarbohydrates: Double?
    public var totalFat: Double?
    public var fiber: Double?
    public var totalSugars: Double?
    public var addedSugars: Double?
    public var glycemicIndex: Double?
    public var glycemicLoad: Double?
    public var servings: [ServingOption]
}

public struct GetRestaurantMenuItemsResponse: Codable, Hashable, Sendable {
    public var items: [RestaurantMenuEntry]
    public init(items: [RestaurantMenuEntry]) { self.items = items }
}

public struct SearchRestaurantMenuItemsResponse: Codable, Hashable, Sendable {
    public var totalCount: Int
    public var items: [RestaurantMenuItem]
    public init(totalCount: Int, items: [RestaurantMenuItem]) { self.totalCount = totalCount; self.items = items }
    enum CodingKeys: String, CodingKey { case items; case totalCount = "total_count" }
}
