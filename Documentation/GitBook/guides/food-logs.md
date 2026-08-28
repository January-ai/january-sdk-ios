# Food logs

Use the `foodLogs` resource to create, list, update, and delete entries for a partner-owned user.

Provide the signed-in user's stable ID once. The SDK passes it to the token
provider and defaults the timezone to the device's current identifier:

```swift
let client = try JanuaryClient(
    endUserID: partnerUserID,
    clientTokenProvider: tokenProvider
)

let logs = try await client.foodLogs.list(start: "2026-08-01", end: "2026-08-31")
```

With client-token authentication, the token supplies the end-user identity and the SDK removes the `x-end-user-id` header. The client sends the configured `TimeZone` or `TimeZone.current` when none was supplied. With local development-key authentication, any configured ID and the resolved timezone are sent.

## Select a food and serving

Search returns discovery records. Hydrate the selected food with `get(id:)`, then create a validated portion from one of its servings:

```swift
let food = try await client.foods.get(id: selectedFoodID)
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
