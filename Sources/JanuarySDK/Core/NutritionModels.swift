import Foundation

public struct NutrientAmount: Codable, Hashable, Sendable {
    public var value: Double
    public var unit: String
    public init(value: Double, unit: String) { self.value = value; self.unit = unit }
}

public struct CompleteScanNutritionFacts: Codable, Hashable, Sendable {
    public var calories: NutrientAmount?
    public var protein: NutrientAmount?
    public var carbohydrates: NutrientAmount?
    public var netCarbohydrates: NutrientAmount?
    public var totalFat: NutrientAmount?
    public var saturatedFat: NutrientAmount?
    public var fiber: NutrientAmount?
    public var totalSugars: NutrientAmount?
    public var addedSugars: NutrientAmount?
    public var sodium: NutrientAmount?

    public init(
        calories: NutrientAmount? = nil, protein: NutrientAmount? = nil,
        carbohydrates: NutrientAmount? = nil, netCarbohydrates: NutrientAmount? = nil,
        totalFat: NutrientAmount? = nil, saturatedFat: NutrientAmount? = nil,
        fiber: NutrientAmount? = nil, totalSugars: NutrientAmount? = nil,
        addedSugars: NutrientAmount? = nil, sodium: NutrientAmount? = nil
    ) {
        self.calories = calories; self.protein = protein; self.carbohydrates = carbohydrates
        self.netCarbohydrates = netCarbohydrates; self.totalFat = totalFat
        self.saturatedFat = saturatedFat; self.fiber = fiber; self.totalSugars = totalSugars
        self.addedSugars = addedSugars; self.sodium = sodium
    }

    enum CodingKeys: String, CodingKey {
        case calories, protein, carbohydrates, fiber, sodium
        case netCarbohydrates = "net_carbohydrates"
        case totalFat = "total_fat"
        case saturatedFat = "saturated_fat"
        case totalSugars = "total_sugars"
        case addedSugars = "added_sugars"
    }
}

public struct NutritionFacts: Codable, Hashable, Sendable {
    public var calories: NutrientAmount?
    public var protein: NutrientAmount?
    public var carbohydrates: NutrientAmount?
    public var netCarbohydrates: NutrientAmount?
    public var totalFat: NutrientAmount?
    public var transFat: NutrientAmount?
    public var saturatedFat: NutrientAmount?
    public var fiber: NutrientAmount?
    public var totalSugars: NutrientAmount?
    public var addedSugars: NutrientAmount?
    public var cholesterol: NutrientAmount?
    public var calcium: NutrientAmount?
    public var iron: NutrientAmount?
    public var potassium: NutrientAmount?
    public var sodium: NutrientAmount?
    public var vitaminD: NutrientAmount?

    public init(
        calories: NutrientAmount? = nil, protein: NutrientAmount? = nil,
        carbohydrates: NutrientAmount? = nil, netCarbohydrates: NutrientAmount? = nil,
        totalFat: NutrientAmount? = nil, transFat: NutrientAmount? = nil,
        saturatedFat: NutrientAmount? = nil, fiber: NutrientAmount? = nil,
        totalSugars: NutrientAmount? = nil, addedSugars: NutrientAmount? = nil,
        cholesterol: NutrientAmount? = nil, calcium: NutrientAmount? = nil,
        iron: NutrientAmount? = nil, potassium: NutrientAmount? = nil,
        sodium: NutrientAmount? = nil, vitaminD: NutrientAmount? = nil
    ) {
        self.calories = calories; self.protein = protein; self.carbohydrates = carbohydrates
        self.netCarbohydrates = netCarbohydrates; self.totalFat = totalFat; self.transFat = transFat
        self.saturatedFat = saturatedFat; self.fiber = fiber; self.totalSugars = totalSugars
        self.addedSugars = addedSugars; self.cholesterol = cholesterol; self.calcium = calcium
        self.iron = iron; self.potassium = potassium; self.sodium = sodium; self.vitaminD = vitaminD
    }

    enum CodingKeys: String, CodingKey {
        case calories, protein, carbohydrates, fiber, cholesterol, calcium, iron, potassium, sodium
        case netCarbohydrates = "net_carbohydrates"; case totalFat = "total_fat"
        case transFat = "trans_fat"; case saturatedFat = "saturated_fat"
        case totalSugars = "total_sugars"; case addedSugars = "added_sugars"
        case vitaminD = "vitamin_d"
    }
}

public struct ServingSelection: Codable, Hashable, Sendable {
    public var id: ServingID
    public var quantity: Double
    public init(id: ServingID, quantity: Double) { self.id = id; self.quantity = quantity }
}

public struct FoodSelection: Codable, Hashable, Sendable {
    public var id: FoodID
    public var serving: ServingSelection
    public init(id: FoodID, serving: ServingSelection) { self.id = id; self.serving = serving }
}

