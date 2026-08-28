# Models and enums

## Typed identifiers

```swift
public struct FoodID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: Int64
    public init(rawValue: Int64)
}

public struct ServingID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: Int64
    public init(rawValue: Int64)
}

public struct PartnerUserID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String)
}
```

## Serving and selection

| Type | Public fields |
| --- | --- |
| `ServingOption` | `id`, `quantity`, `unit`, `scalingFactor`, `weightGrams`, `isPrimary` |
| `ServingSelection` | `id`, `quantity` |
| `FoodSelection` | `id`, `serving` |
| `FoodPortion` | `foodID`, `serving`, `quantity`, `nutrition`, `totalWeightGrams`, `glycemicIndex`, `glycemicLoad`, `selection` |

```swift
public extension FoodSearchItem {
    func portion(
        servingID: ServingID? = nil,
        quantity: Double? = nil
    ) throws -> FoodPortion
}
```

Without a serving ID, portion selection uses the primary serving or the first serving. Without a quantity, it uses that serving's declared quantity.

## Nutrition

`NutrientAmount` contains `value: Double` and `unit: String`. `NutritionFacts` exposes optional calories, protein, carbohydrates, net carbohydrates, total fat, trans fat, saturated fat, fiber, total/added sugars, cholesterol, calcium, iron, potassium, sodium, and vitamin D.

`CompleteScanNutritionFacts` is the scan-oriented subset: calories, protein, carbohydrates, net carbohydrates, total fat, saturated fat, fiber, total/added sugars, and sodium.

## Food models

`FoodSearchItem` includes typed ID, name, optional brand, optional structured and compatibility nutrition fields, glycemic values, optional photo URL, and `[ServingOption]`. `FoodSuggestion` is deliberately smaller. `DetectedFood` represents scan/meal parsing results and may not have a database ID.

## Dietary enums

`DietRestriction` values: `gluten`, `lactose`, `yeast`, `treeNuts`, `peanuts`, `dairy`, `eggs`, `sulfites`, `soy`, `wheat`, `shellfish`, `fish`, `mushrooms`, `sesame`, `monosodiumGlutamate`, `caffeine`, `fodmaps`.

`DietPreference` values: `vegetarian`, `vegan`, `keto`, `paleo`, `pescatarian`, `lowCarbohydrate`, `highProtein`, `kosher`, `halal`.

## Glucose enums and units

| Type | Values |
| --- | --- |
| `Sex` | `male`, `female` |
| `HeightUnit` | `inches`, `centimeters` |
| `WeightUnit` | `pounds`, `kilograms` |
| `ActivityLevel` | `sedentary`, `lightlyActive`, `moderatelyActive`, `veryActive` |
| `MedicalCondition` | `type2Diabetes`, `prediabetes` |

Use `Sex` for the profile's biological-sex field. Omit `healthConditions` or
pass an empty array when no medical conditions apply.

## Error categories

`ErrorCategory` values are `authentication`, `authorization`, `validation`, `notFound`, `rateLimited`, `server`, `transport`, `timeout`, and `decoding`.

`JanuaryError` exposes `category`, optional `code`, `message`, optional `httpStatus`, optional `requestID`, and optional `retryAfterSeconds`.

## Scanner types

On iOS, `JanuaryFoodScannerMode` has `photo` and `barcode`. `JanuaryFoodScannerConfiguration` defaults to both modes, photo first, maximum dimension 1,000, and compression quality 0.7. `JanuaryFoodScannerResult` is either `.photo(image:analysis:)` or `.barcode(value:food:)`.
