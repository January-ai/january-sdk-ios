# Foods

Use the `foods` resource to autocomplete and search the food database, retrieve a full food record, look up a barcode, parse a meal description, or request alternatives.

Configure the signed-in user's stable ID once when creating the client:

```swift
let client = try JanuaryClient(
    endUserID: PartnerUserID(rawValue: partnerUserID),
    clientTokenProvider: tokenProvider
)
```

With client-token authentication, January derives the end-user identity from the token. The configured client keeps call sites consistent, while the SDK removes the `x-end-user-id` header before sending the request.

## Autocomplete

```swift
let suggestions = try await client.foods.autocomplete(
    .init(query: "ban", limit: 8)
)
```

Autocomplete returns lightweight query suggestions for type-ahead interfaces.
Selecting one should place its name in the search field and run `search`. Search
results are discovery records; call `getFood(_:)` before opening
a serving picker so the selected food contains every available serving.

```swift
if let suggestion = suggestions.items.first {
    let results = try await client.foods.search(
        .init(query: suggestion.name, limit: 10)
    )
    // Render `results`; do not open a serving picker from the suggestion itself.
}
```

Autocomplete accepts only `.general` and `.branded`. Name search additionally supports `.recipe`.

## Search by name

```swift
let results = try await client.foods.search(
    .init(
        query: "banana",
        limit: 10
    )
)
```

Filter with `.general`, `.branded`, or `.recipe` through the request's `category` property.

## Get servings and calculate a portion

```swift
guard let match = results.items.first else { return }

let food = try await client.foods.getFood(
    .init(foodID: match.id)
)
let portion = try food.portion(quantity: 1.5)

print(portion.nutrition.calories?.value ?? 0)
```

The full food record contains every available serving. `FoodPortion` validates
the selected serving and quantity, scales every nutrient, weight, and glycemic
load locally, and exposes `selection` for food-log and glucose-prediction
requests. Macronutrients do not require another network request when the user
changes the serving or quantity.

## Look up a barcode

```swift
let results = try await client.foods.lookupByBarcode(
    .init(upc: "049000006346")
)
```

The barcode must contain 6–14 ASCII digits.

## Parse natural language

```swift
let meal = try await client.foods.searchByNaturalLanguage(
    .init(
        query: "one banana and a bowl of oatmeal"
    )
)
```

The response contains detections and, when available, total nutrients for the described meal.

## Suggest alternatives

```swift
let response = try await client.foods.suggestAlternatives(
    .init(
        foodID: food.id,
        dietRestrictions: [.gluten],
        dietPreferences: [.highProtein]
    )
)
```

When no restrictions or preferences apply, omit them or pass empty arrays.

See [Validation limits](../reference/validation.md) for query and barcode constraints.
