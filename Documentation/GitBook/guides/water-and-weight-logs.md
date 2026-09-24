# Water and weight logs

Use `client.waterLogs` and `client.weightLogs` to record water intake and body weight and read them back as one value per day. These examples use the `client` from [Authentication](../getting-started/authentication.md). Its token needs the `water_logs:read`, `water_logs:write`, `weight_logs:read`, and `weight_logs:write` [scopes](https://docs.january.ai/rest-api/authentication#client-token-scopes); without them, calls fail with an `.authorization` error whose code is `scope_insufficient`.

Lists take inclusive `yyyy-MM-dd` dates in the client's timezone ([days and dates](../concepts/user-identity-and-timezone.md#days-and-dates)). A list returns at most 100 days, the most recent ones when more match, and `start` can be at most five years before today; an earlier `start` fails with the code `date_range_too_large`. To chart a longer range, such as a year, request windows of 100 days or fewer and merge them.

Creates aren't idempotent: after a timed-out create, list the day before you retry, or the entry may be recorded twice ([retries](../reference/retries-and-concurrency.md#retrying-creates)).

## Log water

```swift
do {
    let log = try await client.waterLogs.create(
        amount: WaterAmount(value: 8, unit: .fluidOunces),
        consumedAtUTC: ISO8601DateFormatter().string(from: drankAt)
    )
    savedWaterLogIDs.append(log.id) // You need the ID to delete the entry.
} catch let error as JanuaryError where error.code == "daily_water_limit_exceeded" {
    showInputError("That would take today's water past 24 L.")
}
```

An amount is 1–811.5 fluid ounces (`.fluidOunces`), 0.1–101.4 US cups (`.cups`, 8 fluid ounces each), or 30–24,000 milliliters (`.milliliters`). Send the unit the user entered: the minimums don't convert evenly (1 fl oz ≈ 29.6 ml, below the 30 ml minimum). `consumedAtUTC` takes ISO 8601 with any offset and defaults to now.

Each user can log up to 24 L a day. The cap counts the UTC calendar day of `consumedAtUTC`, whatever offset you send, while lists group days in the client's timezone, so near midnight a listed day's total can differ from what the cap counted. A create over the cap fails with the code `daily_water_limit_exceeded` (a `.validation` error).

## Daily water totals

```swift
let totals = try await client.waterLogs.list(start: "2026-09-01", end: "2026-09-30", unit: .milliliters)
for day in totals.items {
    print(day.date, day.total.value, day.total.unit)
}
```

Totals are in the `unit` you ask for (fluid ounces by default), oldest day first. Days with no water are left out, so `items` can be empty.

## Delete a water log

```swift
try await client.waterLogs.delete(id: log.id)
```

Deleting an unknown or already deleted log also succeeds, so retrying a delete is safe.

## Log a weight

```swift
let weightLog = try await client.weightLogs.create(
    weight: Weight(value: 68.5, unit: .kilograms),
    measuredAtUTC: ISO8601DateFormatter().string(from: measuredAt)
)
```

A weight is 10–1,000 pounds or 4.5–453.6 kilograms. Weight logs have no ID and can't be updated or deleted. Every measurement is kept, and a day shows the one with the latest `measuredAtUTC`, so to change what a day shows, log a newer measurement for that day.

## Daily weights

```swift
let weights = try await client.weightLogs.list(start: "2026-09-01", end: "2026-09-30")
for day in weights.items {
    print(day.date, day.weight.value, day.weight.unit)
}
```

Each weight is in the unit it was logged in, oldest day first. Only days with a weight appear.

Next: [Glucose prediction](glucose-prediction.md).
