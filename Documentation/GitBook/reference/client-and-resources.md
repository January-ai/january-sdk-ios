# Client and resources

`JanuaryPartnerClient` is the public SDK entry point. Its generated OpenAPI transport remains package-private.

## Create a client

```swift
let client = try JanuaryPartnerClient(clientTokenProvider: tokenProvider)
```

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

All resource calls use Swift concurrency and can throw `JanuaryError`.

`client.forUser(...)` returns a lightweight `JanuaryPartnerUserClient` whose
`foodLogs` and `glucose` resources automatically reuse one `PartnerUserContext`.
The public client always targets January production; API-origin overrides are
restricted to January-owned development tooling.

## Identifiers

The SDK uses typed wrappers to prevent identifier mixups:

* `PartnerUserID`
* `FoodID`
* `ServingID`
