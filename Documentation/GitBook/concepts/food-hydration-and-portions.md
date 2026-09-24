# Food details and portions

Finding a food and choosing how much was eaten are separate steps. These examples use the `client` from [Authentication](../getting-started/authentication.md).

```text
Autocomplete ─▶ Search ─▶ foods.get(id:) ─▶ Portion
search text     results    every serving    computed locally
```

## 1. Autocomplete suggests search text

Call autocomplete while the user types. A suggestion is text, not a food with servings: when the user picks one, search for its name.

```swift
let suggestions = try await client.foods.autocomplete(.init(query: "greek yog", limit: 8))
guard let name = suggestions.items.first?.name else { return }

let results = try await client.foods.search(.init(query: name, category: .branded))
```

## 2. Fetch the full food before showing servings

Search results are for choosing a food. When the user picks one, fetch the full food with `foods.get(id:)`; it includes every `ServingOption`:

```swift
guard let selected = results.items.first else { return }
let food = try await client.foods.get(id: selected.id)
```

## 3. Compute the portion locally

`portion(servingID:quantity:)` checks the serving and quantity, scales nutrition, weight, and glycemic load, and returns the `FoodSelection` that food logs and glucose predictions take:

```swift
// One primary serving.
let portion = try food.portion()
print(portion.serving.unit ?? "", portion.nutrition.calories?.value ?? 0)

let selection: FoodSelection = portion.selection

// With a "6 oz" primary serving: 9 oz, one and a half servings.
let larger = try food.portion(quantity: 9)
```

Without a `servingID`, it uses the primary serving (or the first one). Changing the serving or quantity needs no network call. `portion` throws `FoodPortionError` when the food has no servings, the serving isn't found, or the quantity is invalid.

### Quantity and servings

`quantity` is an amount in the serving's unit, not a number of servings. For a "6 oz" serving (`quantity` 6, `unit` "oz"), `quantity: 9` means 9 oz, and leaving `quantity` out means one serving (6 oz). `portion.selection` sends the number of servings, `quantity` divided by the serving's own quantity, so 9 oz of a "6 oz" serving is logged as 1.5 servings. Versions before 0.3.2 sent `quantity` itself as the number of servings, so food logs and glucose predictions got the wrong amount (a default "6 oz" portion was logged as 6 servings); upgrade to 0.3.2.

Next: [Foods](../guides/foods.md).
