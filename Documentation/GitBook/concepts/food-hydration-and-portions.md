# Food hydration and portions

Food discovery and serving selection are separate steps.

The examples below use the user context configured once on `JanuaryClient`.
With client-token authentication, the token remains authoritative for identity.

```text
Autocomplete suggestion ─▶ Search results ─▶ GET food/{id} ─▶ Portion
 lightweight text          discovery row      all servings     local scaling
```

## 1. Autocomplete is text discovery

Use autocomplete while the user types. When the user selects a suggestion, put its name into the search field and perform a normal search. A suggestion is not a serving-ready food.

```swift
let suggestions = try await client.foods.autocomplete(
    .init(query: "greek yog", limit: 8)
)
```

## 2. Search returns selectable results

```swift
guard let suggestion = suggestions.items.first else { return }

let results = try await client.foods.search(
    .init(query: suggestion.name, category: .branded)
)
```

## 3. Hydrate before showing servings

Always fetch the chosen food by ID before opening a serving picker:

```swift
guard let selected = results.items.first else { return }

let food = try await client.foods.get(id: selected.id)
```

`get` returns the complete `FoodSearchItem`, including every available `ServingOption`.

## 4. Calculate locally

`FoodPortion` validates the serving and quantity, scales nutrition, weight, and glycemic load locally, and produces the API selection:

```swift
let portion = try food.portion(quantity: 1.5)

print(portion.serving.unit)
print(portion.nutrition.calories?.value as Any)

let selection: FoodSelection = portion.selection
```

Changing the quantity or serving does not require another network request. Handle `FoodPortionError` when a food has no servings, an ID is unavailable, or a quantity is invalid.
