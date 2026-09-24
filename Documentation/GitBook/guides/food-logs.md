# Food logs

Use `client.foodLogs` to create, list, summarize, get, update, and delete a user's meals. These examples use the `client` from [Authentication](../getting-started/authentication.md).

Lists and summaries take inclusive `yyyy-MM-dd` dates in the client's timezone ([days and dates](../concepts/user-identity-and-timezone.md#days-and-dates)). A list covers at most 60 days and a summary at most 366; a longer range fails with the code `date_range_too_large`.

## Choose a food and serving

Fetch the full food, then build a portion from one of its servings:

```swift
let food = try await client.foods.get(id: selectedFoodID)
let portion = try food.portion(servingID: selectedServingID) // One serving
let selectedFood = portion.selection
```

`portion.selection` is the `FoodSelection` that food logs and glucose predictions take. Leave `quantity` out for one serving; any other amount is in the serving's unit ([Quantity and servings](../concepts/food-hydration-and-portions.md#quantity-and-servings)).

### Log an analyzed meal

A [food analysis](photo-scanning.md) detection has its food `id`, selected `serving`, and the `quantity` eaten, so it logs without another lookup. They're optionals in Swift; unwrap them:

```swift
let selections = scan.detections.compactMap { detection -> FoodSelection? in
    guard let id = detection.food.id,
          let servingID = detection.food.serving.id,
          let quantity = detection.food.quantity else { return nil }
    return FoodSelection(id: id, serving: ServingSelection(id: servingID, quantity: quantity))
}
```

## Create

```swift
let log = try await client.foodLogs.create(
    foods: [selectedFood],
    timestampUTC: ISO8601DateFormatter().string(from: eatenAt),
    name: "Breakfast"
)
```

`timestampUTC` is when the meal was eaten, as ISO 8601 with any offset; leave it out to mean now. Creates aren't idempotent: after a timed-out create, list the day before you retry ([retries](../reference/retries-and-concurrency.md#retrying-creates)).

## List

```swift
do {
    let logs = try await client.foodLogs.list(start: "2026-08-01", end: "2026-08-31")
    showLogs(logs.items)
} catch let error as JanuaryError where error.code == "date_range_too_large" {
    showInputError("Choose 60 days or fewer.")
}
```

## Summarize a range

Ask for a summary instead of adding up logs yourself when a screen shows daily or weekly totals:

```swift
let summary = try await client.foodLogs.getSummary(
    start: "2026-09-01", end: "2026-09-30", groupBy: .week
)
for week in summary.buckets {
    print(week.startDate, week.logsCount, week.nutrients.calories?.value ?? 0)
}
let dailyAverage = summary.averagePerLoggedDay.nutrients
```

## Get one log

`FoodLog.id` is optional in Swift, because a listed log can rarely have none. Unwrap it before you get, update, or delete the log:

```swift
guard let logID = log.id else { return }
let savedLog = try await client.foodLogs.get(id: logID)
```

## Update

Only the fields you pass change. An update that passes none fails with `.validation` before it's sent.

```swift
let updated = try await client.foodLogs.update(
    id: logID,
    name: "Post-workout breakfast"
)
```

## Delete

```swift
try await client.foodLogs.delete(id: logID)
```

A successful delete returns nothing.

Next: [Water and weight logs](water-and-weight-logs.md).
