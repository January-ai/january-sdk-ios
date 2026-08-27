# Foods

Use `client.foods` to autocomplete and search the food database, retrieve a full food record, look up a barcode, parse a meal description, or request alternatives.

## Autocomplete

```swift
let suggestions = try await client.foods.autocomplete(
    .init(query: "ban", limit: 8, endUserID: userID)
)
```

Autocomplete returns lightweight query suggestions for type-ahead interfaces.
Selecting one should place its name in the search field and run `search`. Search
results are also lightweight; call ``FoodsResource/getFood(_:)`` before opening
a serving picker so the selected food contains every available serving.

## Search by name

```swift
let results = try await client.foods.search(
    .init(
        query: "banana",
        limit: 10,
        endUserID: userID
    )
)
```

Filter with `.general`, `.branded`, or `.recipe` through the request's `category` property.

## Get servings and calculate a portion

```swift
let food = try await client.foods.getFood(
    .init(foodID: results.items[0].id, endUserID: userID)
)

let portion = try food.portion(
    servingID: food.servings[1].id,
    quantity: 1.5
)

print(portion.nutrition.calories?.value ?? 0)
```

The full food record contains every available serving. ``FoodPortion`` validates
the selected serving and quantity, scales every nutrient, weight, and glycemic
load locally, and exposes `selection` for food-log and glucose-prediction
requests. Macronutrients do not require another network request when the user
changes the serving or quantity.

## Look up a barcode

```swift
let results = try await client.foods.lookupByBarcode(
    .init(upc: "049000006346", endUserID: userID)
)
```

The barcode must contain 6–14 ASCII digits.

## Parse natural language

```swift
let meal = try await client.foods.searchByNaturalLanguage(
    .init(
        query: "one banana and a bowl of oatmeal",
        endUserID: userID
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
        dietPreferences: [.highProtein],
        endUserID: userID
    )
)
```

When no restrictions or preferences apply, omit them or pass empty arrays.
