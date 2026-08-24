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

@available(*, deprecated, renamed: "FoodScan")
public typealias SearchFoodsByNaturalLanguageResponse = FoodScan

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

public struct DetectedServing: Codable, Hashable, Sendable {
    public var id: ServingID
    public var quantity: Double?
    public var unit: String
    public init(id: ServingID, quantity: Double? = nil, unit: String) { self.id = id; self.quantity = quantity; self.unit = unit }
}

public struct DetectedFood: Codable, Hashable, Sendable {
    public var id: FoodID?
    public var name: String
    public var brandName: String?
    public var nutrients: CompleteScanNutritionFacts
    public var servings: [DetectedServing]?
    public init(id: FoodID? = nil, name: String, brandName: String? = nil, nutrients: CompleteScanNutritionFacts, servings: [DetectedServing]? = nil) {
        self.id = id; self.name = name; self.brandName = brandName; self.nutrients = nutrients; self.servings = servings
    }
    enum CodingKeys: String, CodingKey { case id, name, nutrients, servings; case brandName = "brand_name" }
}

public struct FoodAlternative: Codable, Hashable, Sendable {
    public var food: DetectedFood
    public init(food: DetectedFood) { self.food = food }
}

public struct SuggestFoodAlternativesResponse: Codable, Hashable, Sendable {
    public var alternatives: [FoodAlternative]
    public init(alternatives: [FoodAlternative]) { self.alternatives = alternatives }
}
