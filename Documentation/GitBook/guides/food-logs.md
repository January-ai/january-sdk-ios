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

With client-token authentication, the token supplies the end-user identity and the SDK removes the `January-End-User-ID` header. The client sends the configured `TimeZone` or `TimeZone.current` when none was supplied. With local development-key authentication, any configured ID and the resolved timezone are sent.

## Select a food and serving

Search returns discovery records. Hydrate the selected food with `get(id:)`, then create a validated portion from one of its servings:

```swift
let food = try await client.foods.get(id: selectedFoodID)
let portion = try food.portion(servingID: selectedServingID, quantity: 1)
let selectedFood = portion.selection
```

`portion.selection` is the exact `FoodSelection` accepted by Food Logs and glucose prediction.

A photo or description analysis already returns a selected `serving` and the
`quantity` eaten, so a `DetectedFood` logs without another lookup:

```swift
let selections = scan.detections.compactMap { detection -> FoodSelection? in
    guard let id = detection.food.id, let servingID = detection.food.serving.id else { return nil }
    return FoodSelection(id: id, serving: ServingSelection(id: servingID, quantity: detection.food.quantity ?? 1))
}
```

## Create

```swift
let log = try await client.foodLogs.create(
    foods: [selectedFood],
    timestampUTC: ISO8601DateFormatter().string(from: Date()),
    name: "Breakfast"
)
```

## Summarize a range

Ask for a summary instead of paging through logs when a screen needs weekly or
daily totals:

```swift
let summary = try await client.foodLogs.getSummary(
    start: "2026-09-01", end: "2026-09-30", groupBy: .week
)
for week in summary.buckets {
    print(week.startDate, week.logsCount, week.nutrients.calories?.value ?? 0)
}
let dailyAverage = summary.averagePerLoggedDay.nutrients
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
