# Water and weight logs

Use the `waterLogs` and `weightLogs` resources to record water intake and body
weight for a partner-owned user and to read them back as one entry per local
calendar day.

Both resources use the client's configured user context, as food logs do:
provide the signed-in user's stable ID once when creating the client. The SDK
passes it to your token provider, and list requests use the configured timezone
(or `TimeZone.current`) to define local calendar days.

```swift
let client = try JanuaryClient(
    endUserID: partnerUserID,
    clientTokenProvider: tokenProvider
)
```

## Log water

An amount is 1–811.5 fluid ounces (`.fluidOunces`), 0.1–101.4 US cups
(`.cups`, 8 fluid ounces each), or 30–24,000 milliliters (`.milliliters`). The
API caps an end user's total at 24 liters (about 811 fluid ounces) per day,
counted against the day of the entry's `consumedAtUTC`, and refuses a log that
would exceed it with the `daily_water_limit_exceeded` error code (a
`.validation` error).

```swift
let log = try await client.waterLogs.create(amount: WaterAmount(value: 8, unit: .fluidOunces))
// Keep log.id to delete this entry later.
let glass = try await client.waterLogs.create(amount: WaterAmount(value: 1.5, unit: .cups))
```

`consumedAtUTC` accepts an ISO-8601 date-time with any offset and defaults to
now. The response reports `consumedAtUTC` in UTC with milliseconds.

Creating a water log is not idempotent: a retried create records the water
twice and counts twice toward the daily cap, so check `list` before retrying a
timed-out create.

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
let weightLog = try await client.weightLogs.create(weight: Weight(value: 68.5, unit: .kilograms))
```

Creating a weight log is not idempotent: a retried request records a second
measurement, so the SDK does not retry a failed create. The one exception is
the standard replay after a `401 token_expired` response, which the API
refused before recording anything (see
[Retries and concurrency](../reference/retries-and-concurrency.md#january-api-replay)).

## Daily weights

```swift
let weights = try await client.weightLogs.list(start: "2026-09-01", end: "2026-09-30")
for day in weights.items {
    print(day.date, day.weight.value, day.weight.unit)
}
```

Each entry is in the unit it was logged in. Only days with a weight appear,
oldest first. When more than 100 days have a weight, the most recent 100 are
returned; `start` may be at most five years before today.

## Scopes

Client tokens need the `water_logs:read`, `water_logs:write`,
`weight_logs:read`, and `weight_logs:write` scopes for these operations.

## Request values

Each operation also has a request-value form (`CreateWaterLogRequest`,
`ListWaterLogsRequest`, `DeleteWaterLogRequest`, `CreateWeightLogRequest`,
`ListWeightLogsRequest`). On a `JanuaryClient`, the client's configured
end-user ID and timezone replace the request's `user`; create a new client to
act for a different user or timezone.
