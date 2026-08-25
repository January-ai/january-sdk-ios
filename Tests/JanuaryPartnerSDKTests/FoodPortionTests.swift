import Testing
@testable import JanuaryPartnerSDK

private let banana = FoodSearchItem(
    id: FoodID(rawValue: 70_381_819),
    name: "banana",
    nutrients: NutritionFacts(
        calories: NutrientAmount(value: 105.02, unit: "cal"),
        protein: NutrientAmount(value: 1.2862, unit: "g"),
        carbohydrates: NutrientAmount(value: 26.9512, unit: "g"),
        potassium: NutrientAmount(value: 422, unit: "mg")
    ),
    glycemicIndex: 51,
    glycemicLoad: 12,
    servings: [
        ServingOption(
            id: ServingID(rawValue: 1), quantity: 1, unit: "medium",
            scalingFactor: 1, weightGrams: 118, isPrimary: true
        ),
        ServingOption(
            id: ServingID(rawValue: 2), quantity: 100, unit: "g",
            scalingFactor: 0.8474576271, weightGrams: 100, isPrimary: false
        )
    ]
)

@Test
func foodPortionScalesEveryNutrientAndBuildsTheWireSelection() throws {
    let portion = try FoodPortion.from(banana, servingID: ServingID(rawValue: 2), quantity: 200)

    #expect(abs((portion.nutrition.calories?.value ?? 0) - 178) < 0.001)
    #expect(abs((portion.nutrition.protein?.value ?? 0) - 2.18) < 0.001)
    #expect(abs((portion.nutrition.carbohydrates?.value ?? 0) - 45.68) < 0.001)
    #expect(abs((portion.nutrition.potassium?.value ?? 0) - 715.254) < 0.001)
    #expect(portion.nutrition.potassium?.unit == "mg")
    #expect(portion.totalWeightGrams == 200)
    #expect(portion.glycemicIndex == 51)
    #expect(abs((portion.glycemicLoad ?? 0) - 20.3389) < 0.001)
    #expect(portion.selection == FoodSelection(
        id: FoodID(rawValue: 70_381_819),
        serving: ServingSelection(id: ServingID(rawValue: 2), quantity: 200)
    ))
}

@Test
func foodPortionDefaultsToPrimaryServingAndRejectsUnsafeInput() throws {
    let portion = try banana.portion()
    #expect(portion.serving.id == ServingID(rawValue: 1))
    #expect(portion.quantity == 1)

    #expect(throws: FoodPortionError.invalidQuantity) {
        try banana.portion(quantity: 0)
    }
    #expect(throws: FoodPortionError.invalidQuantity) {
        try banana.portion(quantity: .infinity)
    }
    #expect(throws: FoodPortionError.servingNotFound(ServingID(rawValue: 99))) {
        try banana.portion(servingID: ServingID(rawValue: 99))
    }
}
