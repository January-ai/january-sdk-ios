# Food logs

Use `client.foodLogs` to create, list, update, and delete entries for a partner-owned user.

For repeated operations, prefer a scoped client so identity and timezone cannot
drift between requests:

```swift
let user = client.forUser(
    PartnerUserID(rawValue: userID),
    timezone: "America/New_York"
)

let logs = try await user.foodLogs.list(start: "2026-08-01", end: "2026-08-31")
```

With client-token authentication, the token supplies the end-user identity and the SDK removes the `x-end-user-id` header. The context still carries the timezone. With development-key authentication, both ID and timezone are sent.

## Build user context

Food-log operations require an end-user ID. Provide an IANA timezone when available.

```swift
let user = FoodLogUserContext(
    endUserID: PartnerUserID(rawValue: userID),
    timezone: "America/New_York"
)
```

## Select a food and serving

Use identifiers returned by food or menu search:

```swift
let selectedFood = FoodSelection(
    id: food.id,
    serving: ServingSelection(
        id: serving.id,
        quantity: 1
    )
)
```

## Create

```swift
let log = try await client.foodLogs.create(
    .init(
        foods: [selectedFood],
        timestampUTC: ISO8601DateFormatter().string(from: Date()),
        name: "Breakfast",
        user: user
    )
)
```

## List

Dates use `yyyy-MM-dd`:

```swift
let logs = try await client.foodLogs.list(
    .init(
        start: "2026-08-01",
        end: "2026-08-31",
        user: user
    )
)
```

The start and end dates are inclusive calendar dates in the supplied timezone. Timestamps use ISO 8601.

## Update

Only fields supplied in the request are changed.

```swift
let updated = try await client.foodLogs.update(
    .init(id: log.id, name: "Post-workout breakfast", user: user)
)
```

## Delete

```swift
let result = try await client.foodLogs.delete(
    .init(id: log.id, user: user)
)
```
