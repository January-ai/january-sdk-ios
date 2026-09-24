# Client and resources

`JanuaryClient` is the SDK's entry point.

## Create a client

```swift
let client = try JanuaryClient(
    endUserID: endUserID,
    timezone: TimeZone.current,
    clientTokenProvider: tokenProvider
)
```

## Initializers

| Parameters | Use |
| --- | --- |
| `endUserID, timezone?, clientTokenProvider: any JanuaryTokenProvider, tokenRetryPolicy?` | Production: a named provider type that calls your token endpoint |
| `endUserID, timezone?, clientTokenProvider: JanuaryClientTokenProvider, tokenRetryPolicy?` | Production: the same, as an `async` closure |
| `clientToken, endUserID, timezone?` | One token your app manages; create a new client to replace it |
| `developmentAPIKey, endUserID, timezone?` | Local Debug builds only ([local development](../getting-started/authentication.md#local-development)) |

Every initializer requires a non-empty `endUserID`; a blank one throws an `.authentication` error with the code `invalid_end_user_id`. [User identity and timezone](../concepts/user-identity-and-timezone.md) covers `endUserID` and `timezone`.

Every initializer targets `https://partners.january.ai`. There's no public base-URL or token-endpoint override.

## Resource methods

These are the methods on a `JanuaryClient`'s resources. Each resource also has request-value forms, such as `create(_ request: CreateFoodLogRequest)`; the resource pages list them.

| Resource | Method | Purpose |
| --- | --- | --- |
| `foods` | `autocomplete(_:)` | Type-ahead suggestions |
| `foods` | `search(_:)` | Search foods by name |
| `foods` | `lookupBarcode(_:)` | Look up a UPC, EAN, or GTIN barcode |
| `foods` | `get(id:)` | Fetch the full food with every serving |
| `foods` | `suggestAlternatives(_:)` | Find alternatives that fit dietary needs |
| `restaurants` | `search(_:)` | Find nearby restaurants |
| `restaurants` | `searchMenuItems(_:)` | Find nearby menu items |
| `restaurants` | `getMenuItems(_:)` | Load a restaurant's menu by the ID from a restaurant search |
| `foodAnalysis` | `analyzePhoto(_:)` | Analyze a meal photo |
| `foodAnalysis` | `analyzeDescription(_:)` | Analyze a meal description |
| `foodAnalysis` | `correct(_:)` | Correct an analysis with a text instruction |
| `foodLogs` | `create(foods:timestampUTC:name:)` | Create a food log |
| `foodLogs` | `list(start:end:)` | List food logs for a date range |
| `foodLogs` | `getSummary(start:end:groupBy:weekStart:)` | Summarize food logs per day or week |
| `foodLogs` | `get(id:)` | Get one food log |
| `foodLogs` | `update(id:foods:timestampUTC:name:)` | Update a food log |
| `foodLogs` | `delete(id:)` | Delete a food log |
| `waterLogs` | `create(amount:consumedAtUTC:)` | Log an amount of water |
| `waterLogs` | `list(start:end:unit:)` | Daily water totals for a date range |
| `waterLogs` | `delete(id:)` | Delete a water log |
| `weightLogs` | `create(weight:measuredAtUTC:)` | Log a weight |
| `weightLogs` | `list(start:end:)` | Each day's latest weight for a date range |
| `glucose` | `predict(_:)` | Predict a glucose curve |

Every method is `async throws`. It throws `JanuaryError`, or `CancellationError` when its task is canceled ([Errors](error-handling.md)).

## Identifiers

The SDK wraps identifiers in types so they can't be mixed up: `PartnerUserID`, `FoodID`, and `ServingID`.

## Response types

| Operation | Response |
| --- | --- |
| Food autocomplete | `AutocompleteFoodsResponse` |
| Food search or barcode lookup | `FoodSearchResults` |
| Full food (`foods.get`) | `FoodSearchItem` |
| Food analysis: photo, description, or correction | `FoodScan` |
| Food alternatives | `SuggestFoodAlternativesResponse` |
| Restaurant search | `SearchRestaurantsResponse` |
| Menu-item search | `SearchRestaurantMenuItemsResponse` |
| Restaurant menu | `GetRestaurantMenuItemsResponse` |
| Food-log create, get, or update | `FoodLog` |
| Food-log list | `ListFoodLogsResponse` |
| Food-log summary | `FoodLogSummary` |
| Water-log create | `WaterLog` |
| Water-log list | `ListWaterLogsResponse` |
| Weight-log create | `WeightLog` |
| Weight-log list | `ListWeightLogsResponse` |
| Glucose prediction | `GlucosePrediction` |
