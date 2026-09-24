import Testing
@_spi(JanuaryDevelopment) @testable import January

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
    // The API reads the selection's quantity as a count of servings, so 200 g of
    // the "100 g" serving is sent as 2, not 200.
    #expect(portion.selection == FoodSelection(
        id: FoodID(rawValue: 70_381_819),
        serving: ServingSelection(id: ServingID(rawValue: 2), quantity: 2)
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

// One "6 oz" serving is 100 kcal, like the API's greek yogurt 70376084.
private let greekYogurt = FoodSearchItem(
    id: FoodID(rawValue: 70_376_084),
    name: "greek yogurt",
    nutrients: NutritionFacts(
        calories: NutrientAmount(value: 100, unit: "cal"),
        protein: NutrientAmount(value: 17, unit: "g")
    ),
    servings: [
        ServingOption(
            id: ServingID(rawValue: 34_157_706), quantity: 6, unit: "oz",
            scalingFactor: 1, weightGrams: 170, isPrimary: true
        ),
        ServingOption(
            id: ServingID(rawValue: 34_157_707), quantity: 1, unit: "cup",
            scalingFactor: 1.5, weightGrams: 255, isPrimary: false
        )
    ]
)

@Test
func foodPortionSelectionSendsOneServingByDefault() throws {
    let portion = try greekYogurt.portion()

    #expect(portion.quantity == 6)
    #expect(portion.selection == FoodSelection(
        id: FoodID(rawValue: 70_376_084),
        serving: ServingSelection(id: ServingID(rawValue: 34_157_706), quantity: 1)
    ))
    #expect(portion.nutrition.calories?.value == 100)
    #expect(portion.nutrition.protein?.value == 17)
    #expect(portion.totalWeightGrams == 170)
}

@Test
func foodPortionSelectionSendsTheAmountInServings() throws {
    let portion = try greekYogurt.portion(quantity: 12)

    #expect(portion.quantity == 12)
    #expect(portion.selection.serving.quantity == 2)
    #expect(portion.nutrition.calories?.value == 200)
    #expect(portion.nutrition.protein?.value == 34)
    #expect(portion.totalWeightGrams == 340)
}

@Test
func foodPortionSelectionOfAOneUnitServingKeepsTheQuantity() throws {
    let portion = try greekYogurt.portion(servingID: ServingID(rawValue: 34_157_707), quantity: 1.5)

    #expect(portion.selection == FoodSelection(
        id: FoodID(rawValue: 70_376_084),
        serving: ServingSelection(id: ServingID(rawValue: 34_157_707), quantity: 1.5)
    ))
    #expect(abs((portion.nutrition.calories?.value ?? 0) - 225) < 0.001)
    #expect(portion.totalWeightGrams == 382.5)
}

@Test
func foodPortionSelectionOfAGramServingSendsServings() throws {
    let portion = try banana.portion(servingID: ServingID(rawValue: 2), quantity: 150)

    #expect(portion.quantity == 150)
    #expect(portion.selection.serving.quantity == 1.5)
    // Nutrition is still scaled from the amount: 150 g of banana.
    #expect(abs((portion.nutrition.calories?.value ?? 0) - 133.5) < 0.001)
    #expect(abs((portion.nutrition.carbohydrates?.value ?? 0) - 34.26) < 0.001)
    #expect(portion.totalWeightGrams == 150)
}
