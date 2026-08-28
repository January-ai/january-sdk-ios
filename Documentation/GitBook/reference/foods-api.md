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
| `SearchFoodsRequest` | `query` | `category: nil`, `limit: 10`, `endUserID: nil` |
| `LookupFoodByBarcodeRequest` | `upc` | `endUserID: nil` |
| `SuggestFoodAlternativesRequest` | `foodID` | empty restriction/preference arrays, `endUserID: nil` |

## Responses

`AutocompleteFoodsResponse.items` contains `FoodSuggestion` values with `id`, `name`, optional brand/image/nutrition. `FoodSearchResults` contains `totalCount` and `[FoodSearchItem]`. `get` returns one complete `FoodSearchItem` with all servings.

`FoodScan` contains optional meal name, optional total nutrients, `[FoodDetection]`, and optional glucose impact. Alternatives return `[FoodAlternative]`.

## Categories

```swift
public enum AutocompleteFoodCategory: String, Codable, Sendable {
    case general, branded
}

public enum FoodCategory: String, Codable, CaseIterable, Sendable {
    case general, branded, recipe
}
```

## Errors

Local validation covers query, limit, and barcode shape. API responses may map 400 to `.validation`, 401 to `.authentication`, 404 to `.notFound` where declared, 429 to `.rateLimited`, and other statuses through the stable category mapper.

Always use `get` after selecting a discovery result and before presenting servings.
