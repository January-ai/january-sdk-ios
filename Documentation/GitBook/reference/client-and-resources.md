# Client and resources

`JanuaryClient` is the public SDK entry point. Its generated OpenAPI transport remains package-private.

## Create a client

```swift
let client = try JanuaryClient(clientTokenProvider: tokenProvider)
```

## Public initializers

| Initializer | Use |
| --- | --- |
| `clientTokenProvider: JanuaryClientTokenProvider` | Automatic refresh through an async closure |
| `clientTokenProvider: JanuaryTokenProvider` | Automatic refresh through a named provider |
| `clientToken: String` | App-managed fixed client token; recreate the client to replace it |
| `developmentAPIKey: String, endUserID: PartnerUserID` | Deprecated local-development authentication only; never ship an API key in an app |

Public initializers target `https://partners.january.ai`. There is no public base-URL or token-endpoint override.

Production integrations should prefer `JanuaryTokenProvider`, which obtains
short-lived client tokens from the app's authenticated backend. The
`developmentAPIKey` initializer exists only for local testing, emits compile-time
and runtime warnings, and still requires one stable `PartnerUserID`. It must not
be used in a production or distributed build.

## Resource methods

| Resource | Method | Purpose |
| --- | --- | --- |
| `foods` | `search(_:)` | Search foods by name |
| `foods` | `autocomplete(_:)` | Return type-ahead suggestions |
| `foods` | `getFood(_:)` | Hydrate a food with all servings |
| `foods` | `lookupByBarcode(_:)` | Look up UPC/EAN/GTIN codes |
| `foods` | `searchByNaturalLanguage(_:)` | Parse meal descriptions |
| `foods` | `suggestAlternatives(_:)` | Find dietary alternatives |
| `restaurants` | `search(_:)` | Find nearby restaurants |
| `restaurants` | `searchMenuItems(_:)` | Find nearby menu items |
| `photoScanning` | `scan(_:)` | Analyze a meal image |
| `photoScanning` | `correct(_:)` | Correct a scan with text feedback |
| `foodLogs` | `create(_:)` | Create a food log |
| `foodLogs` | `list(_:)` | List food logs for a date range |
| `foodLogs` | `update(_:)` | Update a food log |
| `foodLogs` | `delete(_:)` | Delete a food log |
| `glucose` | `predict(_:)` | Predict glucose impact |

All resource calls use Swift concurrency, are `async throws`, and may throw `JanuaryError` or preserve `CancellationError`.

`client.forUser(...)` returns a lightweight `JanuaryUserClient` whose `foods`,
`restaurants`, `photoScanning`, `foodLogs`, and `glucose` resources automatically
reuse one `PartnerUserContext`. Set the active user once, then use the scoped
client for every operation. The public client always targets January production
and exposes no API-origin override.

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
| Food-log create/update | `FoodLog` |
| Food-log list | `ListFoodLogsResponse` |
| Glucose prediction | `GlucosePrediction` |
