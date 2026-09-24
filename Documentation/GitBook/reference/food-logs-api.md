# Food logs API

## Operations

```swift
public func create(_ request: CreateFoodLogRequest) async throws -> FoodLog
public func list(_ request: ListFoodLogsRequest) async throws -> ListFoodLogsResponse
public func getSummary(_ request: GetFoodLogSummaryRequest) async throws -> FoodLogSummary
public func get(_ request: GetFoodLogRequest) async throws -> FoodLog
public func update(_ request: UpdateFoodLogRequest) async throws -> FoodLog
public func delete(_ request: DeleteFoodLogRequest) async throws -> DeleteFoodLogResponse
```

## Requests and defaults

```swift
public struct CreateFoodLogRequest: Hashable, Sendable {
    public init(
        foods: [FoodSelection],
        timestampUTC: String? = nil,
        name: String? = nil,
        user: PartnerUserContext
    )
}

public struct UpdateFoodLogRequest: Hashable, Sendable {
    public init(
        id: String,
        foods: [FoodSelection]? = nil,
        timestampUTC: String? = nil,
        name: String? = nil,
        user: PartnerUserContext
    )
}

public struct ListFoodLogsRequest: Hashable, Sendable {
    public init(start: String, end: String, user: PartnerUserContext)
}

public struct GetFoodLogRequest: Hashable, Sendable {
    public init(id: String, user: PartnerUserContext)
}

public struct DeleteFoodLogRequest: Hashable, Sendable {
    public init(id: String, user: PartnerUserContext)
}

public struct GetFoodLogSummaryRequest: Hashable, Sendable {
    public init(
        start: String,
        end: String,
        groupBy: FoodLogSummaryGrouping = .day,
        weekStart: WeekStart = .monday,
        user: PartnerUserContext
    )
}
```

`FoodLogUserContext` is a public type alias for `PartnerUserContext`.

## Configured-client operations

```swift
public func create(
    foods: [FoodSelection],
    timestampUTC: String? = nil,
    name: String? = nil
) async throws -> FoodLog

public func list(start: String, end: String) async throws -> ListFoodLogsResponse

public func getSummary(
    start: String,
    end: String,
    groupBy: FoodLogSummaryGrouping = .day,
    weekStart: WeekStart = .monday
) async throws -> FoodLogSummary

public func get(id: String) async throws -> FoodLog

public func update(
    id: String,
    foods: [FoodSelection]? = nil,
    timestampUTC: String? = nil,
    name: String? = nil
) async throws -> FoodLog

public func delete(id: String) async throws -> DeleteFoodLogResponse
```

These methods are on `JanuaryClient.foodLogs` and use the client's end-user ID and timezone. The request-value forms above do too: the client's values replace the request's `user`.

## Responses

`FoodLog` contains an optional `id`, `[LoggedFood]`, `timestampUTC`, and optional
`name`. Logged foods include nutrition, consumed serving, and serving details.
`ListFoodLogsResponse` contains `totalCount` and `items`; `get` returns one
`FoodLog`; a successful delete returns no response body.
`DeleteFoodLogResponse` is a type alias for `Void`.

`list` covers at most 60 days. `getSummary` adds up the logs in the inclusive range (at most 366 days) into `buckets`, one per local calendar day or per week, each with `logsCount`, `daysWithLogs`, and summed `nutrients`. Empty periods are still returned with zero counts. `totals` covers the whole range and `averagePerLoggedDay` divides the totals by the number of days that have a log. `nutrients` is sparse: read `logsCount` to tell an empty bucket from one whose logs had no nutrition data. `weekStart` is `nil` when grouping by day.

## Errors

Create and update check an optional `timestampUTC` as ISO 8601, and update rejects an empty update, before sending. Get and update fail with `.notFound` for an unknown ID. A range that's too long fails with `.validation` and the code `date_range_too_large`. Other API errors map to `JanuaryError` by status.
