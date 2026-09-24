# Client and resources

`JanuaryClient` is the public SDK entry point. Its generated OpenAPI transport remains package-private.

## Create a client

```swift
let client = try JanuaryClient(
    endUserID: signedInUser.id,
    clientTokenProvider: tokenProvider
)
```

## Public initializers

| Initializer | Use |
| --- | --- |
| `endUserID: String, clientTokenProvider: JanuaryClientTokenProvider, timezone?` | Automatic refresh through an async closure for the required user |
| `endUserID: String, clientTokenProvider: JanuaryTokenProvider, timezone?` | Automatic refresh through a named provider for the required user |
| `clientToken, endUserID: String, timezone?` | App-managed fixed token for the required user; recreate the client to replace it |
| `developmentAPIKey, endUserID: String, timezone?` | Supported local-development authentication only; never ship an API key in an app |

Public initializers target `https://partners.january.ai`. There is no public base-URL or token-endpoint override.

Production integrations should prefer `JanuaryTokenProvider`, which obtains
short-lived client tokens from the app's authenticated backend. The
`developmentAPIKey` initializer exists only for local testing and emits a runtime
warning when initialized with a nonempty key. Release builds reject it at compile
time. It must not be used in a production or distributed build.

Every public initializer requires the signed-in user's stable `endUserID`.

All initializers resolve an omitted or blank timezone to
`TimeZone.current`. The SDK converts the value to its identifier for requests.

## Resource methods

| Resource | Method | Purpose |
| --- | --- | --- |
| `foods` | `search(_:)` | Search foods by name |
| `foods` | `autocomplete(_:)` | Return type-ahead suggestions |
| `foods` | `get(id:endUserID:)` | Hydrate a food with all servings |
| `foods` | `lookupBarcode(_:)` | Look up UPC/EAN/GTIN codes |
| `foods` | `suggestAlternatives(_:)` | Find dietary alternatives |
| `restaurants` | `search(_:)` | Find nearby restaurants |
| `restaurants` | `searchMenuItems(_:)` | Find nearby menu items |
| `restaurants` | `getMenuItems(_:)` | Load a restaurant's menu by its search-result ID |
| `foodAnalysis` | `analyzePhoto(_:)` | Analyze a food image |
| `foodAnalysis` | `analyzeDescription(_:)` | Analyze a meal description |
| `foodAnalysis` | `correct(_:)` | Correct a scan with text feedback |
| `foodLogs` | `create(_:)` | Create a food log |
| `foodLogs` | `list(_:)` | List food logs for a date range |
| `foodLogs` | `getSummary(_:)` | Summarize food logs per day or week |
| `foodLogs` | `get(_:)` | Get one food log by ID |
| `foodLogs` | `update(_:)` | Update a food log |
| `foodLogs` | `delete(_:)` | Delete a food log |
| `glucose` | `predict(_:)` | Predict glucose impact |
| `waterLogs` | `create(_:)` | Log an amount of water |
| `waterLogs` | `list(_:)` | Daily water totals for a date range |
| `waterLogs` | `delete(_:)` | Delete a water log |
| `weightLogs` | `create(_:)` | Log a weight measurement |
| `weightLogs` | `list(_:)` | Latest weight per day for a date range |

All resource calls use Swift concurrency, are `async throws`, and may throw `JanuaryError` or preserve `CancellationError`.

`JanuaryClient` applies its configured `PartnerUserContext` automatically to
`foods`, `restaurants`, `foodAnalysis`, `foodLogs`, `glucose`, `waterLogs`, and
`weightLogs`. There is no
second user-client object and no need to repeat the ID in individual requests.
The public client always targets January production and exposes no API-origin
override.

## Identifiers

The SDK uses typed wrappers to prevent identifier mixups:

* `PartnerUserID`
* `FoodID`
* `ServingID`

## Principal response types

| Operation | Response |
| --- | --- |
| Food autocomplete | `AutocompleteFoodsResponse` |
| Food search or barcode | `FoodSearchResults` |
| Food hydration | `FoodSearchItem` |
| Natural-language meal or photo scan | `FoodScan` |
| Restaurant search | `SearchRestaurantsResponse` |
| Menu-item search | `SearchRestaurantMenuItemsResponse` |
| Restaurant menu lookup | `GetRestaurantMenuItemsResponse` |
| Food-log create/get/update | `FoodLog` |
| Food-log list | `ListFoodLogsResponse` |
| Food-log summary | `FoodLogSummary` |
| Glucose prediction | `GlucosePrediction` |
| Water-log create | `WaterLog` |
| Water-log list | `ListWaterLogsResponse` |
| Weight-log create | `WeightLog` |
| Weight-log list | `ListWeightLogsResponse` |
