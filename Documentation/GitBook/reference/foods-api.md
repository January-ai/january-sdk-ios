# Foods API

All methods are `async throws`. They throw `JanuaryError`, or `CancellationError` when the task is canceled.

## Operations

```swift
public func autocomplete(
    _ request: AutocompleteFoodsRequest
) async throws -> AutocompleteFoodsResponse

public func get(
    id: FoodID,
    endUserID: PartnerUserID? = nil
) async throws -> FoodSearchItem

public func search(
    _ request: SearchFoodsRequest
) async throws -> FoodSearchResults

public func lookupBarcode(
    _ request: LookupFoodByBarcodeRequest
) async throws -> FoodSearchResults

public func suggestAlternatives(
    _ request: SuggestFoodAlternativesRequest
) async throws -> SuggestFoodAlternativesResponse
```

## Requests and defaults

| Request | Required | Defaults |
| --- | --- | --- |
| `AutocompleteFoodsRequest` | `query` | `category: nil`, `limit: 8` (1–20), `endUserID: nil` |
| `SearchFoodsRequest` | `query` | `category: nil`, `limit: 10` (1–50), `offset: 0`, `endUserID: nil` |
| `LookupFoodByBarcodeRequest` | `upc` | `endUserID: nil` |
| `SuggestFoodAlternativesRequest` | `foodID` | empty restriction/preference arrays, `endUserID: nil` |

## Responses

`AutocompleteFoodsResponse.items` contains `FoodSuggestion` values with an `id` and an optional `name`, brand, image, and nutrition. `FoodSearchResults` contains `totalCount` and `[FoodSearchItem]`. `get` returns the full `FoodSearchItem`, with every serving. `name` is optional on both types.

Alternatives return `SuggestFoodAlternativesResponse.alternatives: [AlternativeFood]`. The `FoodScan` result of food analysis is on the [Food analysis API](photo-scanning-api.md#response-models) page.

## Categories

```swift
public enum AutocompleteFoodCategory: String, Codable, Sendable {
    case generic, branded
}

public enum FoodCategory: String, Codable, CaseIterable, Sendable {
    case generic, branded, recipe
}
```

`general` remains as a deprecated alias of `generic` on both enums.

## Errors

The SDK checks the query, limit, offset, and barcode before sending ([Validation limits](validation.md)). API errors map to categories by status: 400 to `.validation`, 401 to `.authentication`, 403 to `.authorization`, 404 to `.notFound` (`get` and barcode lookup), and 429 to `.rateLimited`.

Fetch the full food with `get` after the user picks a search result and before you show servings.
