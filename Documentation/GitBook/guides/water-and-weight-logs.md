# Water and weight logs

Use the `waterLogs` and `weightLogs` resources to record water intake and body
weight for a partner-owned user and to read them back as one entry per local
calendar day.

Both resources take the same user context as food logs: provide the signed-in
user's stable ID once when creating the client, and the SDK sends it with every
request together with the configured timezone.

```swift
let client = try JanuaryClient(
    endUserID: partnerUserID,
    clientTokenProvider: tokenProvider
)
```

## Log water

An amount is 1–811.5 fluid ounces or 30–24,000 milliliters. The API caps an
end user at 24 liters per local day and refuses a log that would exceed it
with the `daily_water_limit_exceeded` error code (a `.validation` error).

```swift
let log = try await client.waterLogs.create(amount: WaterAmount(value: 8, unit: .fluidOunces))
// Keep log.id to delete this entry later.
```

`consumedAtUTC` accepts an ISO-8601 date-time with any offset and defaults to
now. The response reports `consumedAtUTC` in UTC with milliseconds.

## Daily water totals

Dates use `yyyy-MM-dd` and are inclusive local calendar dates in the user's
timezone. Ask for the unit every total should be returned in:

```swift
let totals = try await client.waterLogs.list(start: "2026-09-01", end: "2026-09-30", unit: .milliliters)
for day in totals.items {
    print(day.date, day.total.value, day.total.unit)
}
```

Days with nothing logged are absent, so an empty `items` array is a valid
result. At most 100 days are returned: when more match, the most recent 100.
`start` may be at most five years before today; an earlier date is refused
with the `date_range_too_large` error code.

## Delete a water log

```swift
try await client.waterLogs.delete(id: log.id)
```

Deleting an unknown or already-deleted log also succeeds, so a retry is safe.

## Log a weight

A weight is 10–1,000 pounds or 4.5–453.6 kilograms. Every measurement is
kept, and a day's listing shows the one with the latest `measuredAtUTC`, so
logging again later the same day replaces what that day shows.

```swift
let log = try await client.weightLogs.create(weight: Weight(value: 68.5, unit: .kilograms))
```

Creating a weight log is not idempotent: the SDK never retries it
automatically, and a retried request records a second measurement.

## Daily weights

```swift
let weights = try await client.weightLogs.list(start: "2026-09-01", end: "2026-09-30")
for day in weights.items {
    print(day.date, day.weight.value, day.weight.unit)
}
```

Each entry is in the unit it was logged in. Only days with a weight appear, at
most 100 days, oldest first.

## Explicit user context

Every operation also accepts a request value with an explicit
`PartnerUserContext`, matching the food-log resource:

```swift
let totals = try await client.waterLogs.list(
    .init(start: "2026-09-01", end: "2026-09-30", unit: .fluidOunces, user: context)
)
```
