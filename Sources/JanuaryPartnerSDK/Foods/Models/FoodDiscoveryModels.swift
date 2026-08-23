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

public struct NaturalLanguageServing: Codable, Hashable, Sendable {
    public var id: ServingID
    public var unit: String
    public var quantity: Double?
    public var selectedQuantity: Double?
    public init(id: ServingID, unit: String, quantity: Double? = nil, selectedQuantity: Double? = nil) {
        self.id = id; self.unit = unit; self.quantity = quantity; self.selectedQuantity = selectedQuantity
    }
    enum CodingKeys: String, CodingKey { case id, unit, quantity; case selectedQuantity = "selected_quantity" }
}

public struct NaturalLanguageFood: Codable, Hashable, Sendable {
    public var id: FoodID?
    public var name: String
    public var brandName: String?
    public var nutrients: CompleteScanNutritionFacts
    public var servings: [NaturalLanguageServing]?
    public init(id: FoodID? = nil, name: String, brandName: String? = nil, nutrients: CompleteScanNutritionFacts, servings: [NaturalLanguageServing]? = nil) {
        self.id = id; self.name = name; self.brandName = brandName; self.nutrients = nutrients; self.servings = servings
    }
    enum CodingKeys: String, CodingKey { case id, name, nutrients, servings; case brandName = "brand_name" }
}

public struct NaturalLanguageFoodDetection: Codable, Hashable, Sendable {
    public var food: NaturalLanguageFood
    public init(food: NaturalLanguageFood) { self.food = food }
}

public struct SearchFoodsByNaturalLanguageResponse: Codable, Hashable, Sendable {
    public var totalNutrients: CompleteScanNutritionFacts?
    public var detections: [NaturalLanguageFoodDetection]
    public init(totalNutrients: CompleteScanNutritionFacts? = nil, detections: [NaturalLanguageFoodDetection]) {
        self.totalNutrients = totalNutrients; self.detections = detections
    }
    enum CodingKeys: String, CodingKey { case detections; case totalNutrients = "total_nutrients" }
}

public enum DietRestriction: String, Codable, Hashable, Sendable, CaseIterable {
    case none = "None", gluten = "Gluten", lactose = "Lactose", yeast = "Yeast"
    case treeNuts = "Tree nuts", peanuts = "Peanuts", dairy = "Dairy", eggs = "Eggs"
    case sulfites = "Sulfites", soy = "Soy", wheat = "Wheat", shellfish = "Shellfish"
    case fish = "Fish", mushrooms = "Mushrooms", sesame = "Sesame"
    case monosodiumGlutamate = "Monosodium glutamate (MSG)", caffeine = "Caffeine", fodmaps = "FODMAPs"
}

public enum DietPreference: String, Codable, Hashable, Sendable, CaseIterable {
    case none = "None", vegetarian = "Vegetarian", vegan = "Vegan", keto = "Keto", paleo = "Paleo"
    case pescatarian = "Pescatarian", lowCarbohydrate = "Low carbohydrate", highProtein = "High protein"
    case kosher = "Kosher", halal = "Halal"
}

public struct SuggestFoodAlternativesRequest: Codable, Hashable, Sendable {
    public var foodID: FoodID
    public var dietRestrictions: [DietRestriction]
    public var dietPreferences: [DietPreference]
    public var endUserID: PartnerUserID?
    public init(foodID: FoodID, dietRestrictions: [DietRestriction] = [.none], dietPreferences: [DietPreference] = [.none], endUserID: PartnerUserID? = nil) {
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
