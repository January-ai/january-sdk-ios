# Food logs

Use the `foodLogs` resource to create, list, update, and delete entries for a partner-owned user.

Configure identity and timezone once on the client so they cannot drift between
requests:

```swift
let client = try JanuaryClient(
    endUserID: PartnerUserID(rawValue: userID),
    timezone: "America/New_York",
    clientTokenProvider: tokenProvider
)

let logs = try await client.foodLogs.list(start: "2026-08-01", end: "2026-08-31")
```

With client-token authentication, the token supplies the end-user identity and the SDK removes the `x-end-user-id` header. The configured client still supplies the timezone. With local development-key authentication, the configured ID and timezone are sent.

## Select a food and serving

Search returns discovery records. Hydrate the selected food with `getFood(_:)`, then create a validated portion from one of its servings:

```swift
let food = try await client.foods.getFood(.init(foodID: selectedFoodID))
let portion = try food.portion(servingID: selectedServingID, quantity: 1)
let selectedFood = portion.selection
```

`portion.selection` is the exact `FoodSelection` accepted by Food Logs and glucose prediction.

## Create

```swift
let log = try await client.foodLogs.create(
    foods: [selectedFood],
    timestampUTC: ISO8601DateFormatter().string(from: Date()),
    name: "Breakfast"
)
```

## List

Dates use `yyyy-MM-dd`:

```swift
let logs = try await client.foodLogs.list(
    start: "2026-08-01",
    end: "2026-08-31"
)
```

The start and end dates are inclusive calendar dates in the supplied timezone. Timestamps use ISO 8601.

## Update

Only fields supplied in the request are changed.

```swift
let updated = try await client.foodLogs.update(
    id: log.id,
    name: "Post-workout breakfast"
)
```

## Delete

```swift
let result = try await client.foodLogs.delete(id: log.id)
```
