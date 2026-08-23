# Foods

Use `client.foods` to search the food database, look up a barcode, parse a meal description, or request alternatives.

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

When no restrictions or preferences apply, use the default `.none` values rather than empty arrays.

