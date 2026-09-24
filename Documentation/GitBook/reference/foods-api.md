# Foods API

All methods are `async throws`. Declared API errors map to `JanuaryError`; task cancellation remains `CancellationError`.

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
| `AutocompleteFoodsRequest` | `query` | `category: nil`, `limit: 8`, `endUserID: nil` |
| `SearchFoodsRequest` | `query` | `category: nil`, `limit: 10` (1–50), `offset: 0`, `endUserID: nil` |
| `LookupFoodByBarcodeRequest` | `upc` | `endUserID: nil` |
| `SuggestFoodAlternativesRequest` | `foodID` | empty restriction/preference arrays, `endUserID: nil` |

## Responses

`AutocompleteFoodsResponse.items` contains `FoodSuggestion` values with `id`, `name`, optional brand/image/nutrition. `FoodSearchResults` contains `totalCount` and `[FoodSearchItem]`. `get` returns one complete `FoodSearchItem` with all servings.

`FoodScan` exposes an optional meal name, total nutrients, a nonoptional
`[FoodDetection]`, and deprecated `glucoseImpact`, which is always `nil` because
food analysis no longer returns it. Alternatives return
`SuggestFoodAlternativesResponse.alternatives: [AlternativeFood]`.

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

Local validation covers query, limit, offset, and barcode shape. API responses may map 400 to `.validation`, 401 to `.authentication`, 404 to `.notFound` where declared, 429 to `.rateLimited`, and other statuses through the stable category mapper.

Always use `get` after selecting a discovery result and before presenting servings.
