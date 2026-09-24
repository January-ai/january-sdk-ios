# Foods

Use `client.foods` to autocomplete and search the food database, look up a barcode, fetch a full food, and suggest alternatives. These examples use the `client` from [Authentication](../getting-started/authentication.md). [Food details and portions](../concepts/food-hydration-and-portions.md) explains how the steps fit together.

## Autocomplete

```swift
let suggestions = try await client.foods.autocomplete(.init(query: "ban", limit: 8))
```

A suggestion is search text, not a food with servings. When the user picks one, search for its name:

```swift
guard let name = suggestions.items.first?.name else { return }
let results = try await client.foods.search(.init(query: name, limit: 10))
```

Autocomplete's `category` filter takes `.generic` or `.branded`.

## Search by name

```swift
let results = try await client.foods.search(.init(query: "banana", category: .generic, limit: 10))
```

`category` is `.generic`, `.branded`, or `.recipe`; leave it out to search every category. Page with `offset`.

## Fetch the full food and compute a portion

```swift
guard let match = results.items.first else { return }

let food = try await client.foods.get(id: match.id)
let portion = try food.portion(quantity: 1.5)
print(portion.nutrition.calories?.value ?? 0)
```

## Look up a barcode

```swift
do {
    let results = try await client.foods.lookupBarcode(.init(upc: "049000006346"))
    showFoods(results.items)
} catch let error as JanuaryError where error.category == .notFound {
    offerTextSearch() // Not in the database.
}
```

A barcode is 6–14 digits. Coverage is US-only: a code issued elsewhere (for example GS1 prefixes 73, 64, 54, or 93) comes back as `.notFound`, so fall back to text search.

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

Leave out `dietRestrictions` and `dietPreferences`, or pass empty arrays, when none apply.

To analyze a meal description instead, see [Food analysis](photo-scanning.md#analyze-a-description). Input limits are in [Validation limits](../reference/validation.md).

Next: [Restaurants](restaurants.md).
