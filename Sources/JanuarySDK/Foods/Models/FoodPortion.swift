/// A validated serving and quantity with locally calculated nutrition.
public struct FoodPortion: Hashable, Sendable {
    public let foodID: FoodID
    public let serving: ServingOption
    public let quantity: Double
    public let nutrition: NutritionFacts
    public let totalWeightGrams: Double?
    public let glycemicIndex: Double?
    public let glycemicLoad: Double?

    /// The exact selection sent by food-log and glucose-prediction requests.
    public var selection: FoodSelection {
        FoodSelection(
            id: foodID,
            serving: ServingSelection(id: serving.id!, quantity: quantity)
        )
    }

    public static func from(
        _ food: FoodSearchItem,
        servingID: ServingID? = nil,
        quantity: Double? = nil
    ) throws -> FoodPortion {
        try FoodPortion(food: food, servingID: servingID, quantity: quantity)
    }

    public init(
        food: FoodSearchItem,
        servingID: ServingID? = nil,
        quantity: Double? = nil
    ) throws {
        guard !food.servings.isEmpty else { throw FoodPortionError.noServings }

        let selected: ServingOption
        if let servingID {
            guard let match = food.servings.first(where: { $0.id == servingID }) else {
                throw FoodPortionError.servingNotFound(servingID)
            }
            selected = match
        } else {
            selected = food.servings.first(where: { $0.isPrimary == true }) ?? food.servings[0]
        }

        guard selected.id != nil, let servingQuantity = selected.quantity,
              servingQuantity.isFinite, servingQuantity > 0,
              selected.scalingFactor.isFinite, selected.scalingFactor > 0 else {
            throw FoodPortionError.invalidServing(selected.id)
        }

        let requestedQuantity = quantity ?? servingQuantity
        guard requestedQuantity.isFinite, requestedQuantity > 0, requestedQuantity <= 10_000 else {
            throw FoodPortionError.invalidQuantity
        }

        let scale = requestedQuantity * selected.scalingFactor / servingQuantity
        let baseNutrition = food.nutrients ?? NutritionFacts.legacyValues(from: food)

        self.foodID = food.id
        self.serving = selected
        self.quantity = requestedQuantity
        self.nutrition = baseNutrition.scaled(by: scale)
        self.totalWeightGrams = selected.weightGrams.map {
            $0 * requestedQuantity / servingQuantity
        }
        self.glycemicIndex = food.glycemicIndex
        self.glycemicLoad = food.glycemicLoad.map { $0 * scale }
    }
}

public enum FoodPortionError: Error, Equatable, Sendable {
    case noServings
    case servingNotFound(ServingID)
    case invalidServing(ServingID?)
    case invalidQuantity
}

public extension FoodSearchItem {
    func portion(
        servingID: ServingID? = nil,
        quantity: Double? = nil
    ) throws -> FoodPortion {
        try FoodPortion.from(self, servingID: servingID, quantity: quantity)
    }
}

private extension NutrientAmount {
    func scaled(by scale: Double) -> NutrientAmount {
        NutrientAmount(value: value * scale, unit: unit)
    }
}

private extension NutritionFacts {
    func scaled(by scale: Double) -> NutritionFacts {
        NutritionFacts(
            calories: calories?.scaled(by: scale),
            protein: protein?.scaled(by: scale),
            carbohydrates: carbohydrates?.scaled(by: scale),
            netCarbohydrates: netCarbohydrates?.scaled(by: scale),
            totalFat: totalFat?.scaled(by: scale),
            transFat: transFat?.scaled(by: scale),
            saturatedFat: saturatedFat?.scaled(by: scale),
            fiber: fiber?.scaled(by: scale),
            totalSugars: totalSugars?.scaled(by: scale),
            addedSugars: addedSugars?.scaled(by: scale),
            cholesterol: cholesterol?.scaled(by: scale),
            calcium: calcium?.scaled(by: scale),
            iron: iron?.scaled(by: scale),
            potassium: potassium?.scaled(by: scale),
            sodium: sodium?.scaled(by: scale),
            vitaminD: vitaminD?.scaled(by: scale)
        )
    }

    static func legacyValues(from food: FoodSearchItem) -> NutritionFacts {
        NutritionFacts(
            calories: food.calories.map { NutrientAmount(value: $0, unit: "cal") },
            protein: food.protein.map { NutrientAmount(value: $0, unit: "g") },
            carbohydrates: food.carbohydrates.map { NutrientAmount(value: $0, unit: "g") },
            netCarbohydrates: food.netCarbohydrates.map { NutrientAmount(value: $0, unit: "g") },
            totalFat: food.totalFat.map { NutrientAmount(value: $0, unit: "g") },
            saturatedFat: food.saturatedFat.map { NutrientAmount(value: $0, unit: "g") },
            fiber: food.fiber.map { NutrientAmount(value: $0, unit: "g") },
            totalSugars: food.totalSugars.map { NutrientAmount(value: $0, unit: "g") },
            addedSugars: food.addedSugars.map { NutrientAmount(value: $0, unit: "g") },
            cholesterol: food.cholesterol.map { NutrientAmount(value: $0, unit: "mg") },
            potassium: food.potassium.map { NutrientAmount(value: $0, unit: "mg") },
            sodium: food.sodium.map { NutrientAmount(value: $0, unit: "mg") }
        )
    }
}
