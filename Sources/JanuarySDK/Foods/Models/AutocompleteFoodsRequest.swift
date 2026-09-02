/// Food categories supported by autocomplete.
public enum AutocompleteFoodCategory: String, Codable, Hashable, Sendable {
    case generic
    case branded
}

/// Inputs for food autocomplete.
public struct AutocompleteFoodsRequest: Hashable, Sendable {
    public var query: String
    public var category: AutocompleteFoodCategory?
    public var limit: Int
    public var endUserID: PartnerUserID?

    public init(
        query: String,
        category: AutocompleteFoodCategory? = nil,
        limit: Int = 8,
        endUserID: PartnerUserID? = nil
    ) {
        self.query = query
        self.category = category
        self.limit = limit
        self.endUserID = endUserID
    }
}

/// A lightweight food match returned while a user types.
public struct FoodSuggestion: Codable, Hashable, Sendable {
    public var id: FoodID
    public var name: String?
    public var brandName: String?
    public var imageURL: String?
    public var nutrients: NutritionFacts?

    public init(
        id: FoodID,
        name: String?,
        brandName: String? = nil,
        imageURL: String? = nil,
        nutrients: NutritionFacts? = nil
    ) {
        self.id = id
        self.name = name
        self.brandName = brandName
        self.imageURL = imageURL
        self.nutrients = nutrients
    }
}

public extension AutocompleteFoodCategory {
    @available(*, deprecated, renamed: "generic")
    static var general: Self { .generic }
}

/// Food matches returned by autocomplete.
public struct AutocompleteFoodsResponse: Codable, Hashable, Sendable {
    public var items: [FoodSuggestion]

    public init(items: [FoodSuggestion]) {
        self.items = items
    }
}
