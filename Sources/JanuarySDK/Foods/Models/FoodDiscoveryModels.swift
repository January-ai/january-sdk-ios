import Foundation

public struct LookupFoodByBarcodeRequest: Hashable, Sendable {
    public var upc: String
    public var endUserID: PartnerUserID?
    public init(upc: String, endUserID: PartnerUserID? = nil) { self.upc = upc; self.endUserID = endUserID }
}

public struct SearchFoodsByNaturalLanguageRequest: Hashable, Sendable {
    public var query: String
    public var endUserID: PartnerUserID?
    public init(query: String, endUserID: PartnerUserID? = nil) { self.query = query; self.endUserID = endUserID }
}

public enum DietRestriction: String, Codable, Hashable, Sendable, CaseIterable {
    case gluten, lactose, yeast
    case treeNuts = "tree_nuts", peanuts, dairy, eggs
    case sulfites, soy, wheat, shellfish
    case fish, mushrooms, sesame
    case monosodiumGlutamate = "msg", caffeine, fodmaps
}

public enum DietPreference: String, Codable, Hashable, Sendable, CaseIterable {
    case vegetarian, vegan, keto, paleo
    case pescatarian, lowCarbohydrate = "low_carbohydrate", highProtein = "high_protein"
    case kosher, halal
}

public struct SuggestFoodAlternativesRequest: Codable, Hashable, Sendable {
    public var foodID: FoodID
    public var dietRestrictions: [DietRestriction]
    public var dietPreferences: [DietPreference]
    public var endUserID: PartnerUserID?
    public init(foodID: FoodID, dietRestrictions: [DietRestriction] = [], dietPreferences: [DietPreference] = [], endUserID: PartnerUserID? = nil) {
        self.foodID = foodID; self.dietRestrictions = dietRestrictions
        self.dietPreferences = dietPreferences; self.endUserID = endUserID
    }
}

/// The catalog serving a detected or alternative food is expressed in.
/// `quantity` is the size of one serving, not the amount eaten.
public struct ServingSummary: Codable, Hashable, Sendable {
    public var id: ServingID?
    public var quantity: Double?
    public var unit: String?
    public init(id: ServingID?, quantity: Double? = nil, unit: String?) {
        self.id = id; self.quantity = quantity; self.unit = unit
    }
}

@available(*, deprecated, renamed: "ServingSummary", message: "The amount eaten is now DetectedFood.quantity.")
public typealias DetectedServing = ServingSummary

/// A food recognized from a photo or a description.
///
/// `serving` is the selected catalog serving and `quantity` is how many of that serving were eaten
/// (`0.4` for 40 g of a 100 g serving); together they are ready to use as a food-log entry.
/// `nutrients` are already scaled to `quantity`. `quantity` is nil when no usable portion was found.
public struct DetectedFood: Codable, Hashable, Sendable {
    public var id: FoodID?
    public var name: String?
    public var brandName: String?
    public var nutrients: CompleteScanNutritionFacts
    public var serving: ServingSummary
    public var quantity: Double?
    public init(
        id: FoodID? = nil,
        name: String?,
        brandName: String? = nil,
        nutrients: CompleteScanNutritionFacts,
        serving: ServingSummary,
        quantity: Double? = nil
    ) {
        self.id = id; self.name = name; self.brandName = brandName
        self.nutrients = nutrients; self.serving = serving; self.quantity = quantity
    }
    enum CodingKeys: String, CodingKey { case id, name, nutrients, serving, quantity; case brandName = "brand_name" }
}

/// A healthier alternative to a food, with the servings its nutrition can be read against.
public struct AlternativeFood: Codable, Hashable, Sendable {
    public var id: FoodID?
    public var name: String?
    public var brandName: String?
    public var nutrients: CompleteScanNutritionFacts
    public var servings: [ServingSummary]
    public init(id: FoodID? = nil, name: String?, brandName: String? = nil, nutrients: CompleteScanNutritionFacts, servings: [ServingSummary] = []) {
        self.id = id; self.name = name; self.brandName = brandName; self.nutrients = nutrients; self.servings = servings
    }
    enum CodingKeys: String, CodingKey { case id, name, nutrients, servings; case brandName = "brand_name" }
}

public typealias FoodAlternative = AlternativeFood

public struct SuggestFoodAlternativesResponse: Codable, Hashable, Sendable {
    public var alternatives: [AlternativeFood]
    public init(alternatives: [AlternativeFood]) { self.alternatives = alternatives }
}
