# Foods API

All methods are `async throws`. Declared API errors map to `JanuaryError`; task cancellation remains `CancellationError`.

## Operations

```swift
public func autocomplete(
    _ request: AutocompleteFoodsRequest
) async throws -> AutocompleteFoodsResponse

public func getFood(
    _ request: GetFoodRequest
) async throws -> FoodSearchItem

public func search(
    _ request: SearchFoodsRequest
) async throws -> FoodSearchResults

public func lookupByBarcode(
    _ request: LookupFoodByBarcodeRequest
) async throws -> FoodSearchResults

public func searchByNaturalLanguage(
    _ request: SearchFoodsByNaturalLanguageRequest
) async throws -> FoodScan

public func suggestAlternatives(
    _ request: SuggestFoodAlternativesRequest
) async throws -> SuggestFoodAlternativesResponse
```

## Requests and defaults

| Request | Required | Defaults |
| --- | --- | --- |
| `AutocompleteFoodsRequest` | `query` | `category: nil`, `limit: 8`, `endUserID: nil` |
| `GetFoodRequest` | `foodID` | `endUserID: nil` |
| `SearchFoodsRequest` | `query` | `category: nil`, `limit: 10`, `endUserID: nil` |
| `LookupFoodByBarcodeRequest` | `upc` | `endUserID: nil` |
| `SearchFoodsByNaturalLanguageRequest` | `query` | `endUserID: nil` |
| `SuggestFoodAlternativesRequest` | `foodID` | empty restriction/preference arrays, `endUserID: nil` |

## Responses

`AutocompleteFoodsResponse.items` contains `FoodSuggestion` values with `id`, `name`, optional brand/image/nutrition. `FoodSearchResults` contains `totalCount` and `[FoodSearchItem]`. `getFood` returns one complete `FoodSearchItem` with all servings.

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

Local validation covers query, limit, natural-language length, and barcode shape. API responses may map 400 to `.validation`, 401 to `.authentication`, 404 to `.notFound` where declared, 429 to `.rateLimited`, and other statuses through the stable category mapper.

Always use `getFood` after selecting a discovery result and before presenting servings.
