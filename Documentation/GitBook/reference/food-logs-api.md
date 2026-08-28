# Food Logs API

## Operations

```swift
public func create(_ request: CreateFoodLogRequest) async throws -> FoodLog
public func list(_ request: ListFoodLogsRequest) async throws -> ListFoodLogsResponse
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

public struct DeleteFoodLogRequest: Hashable, Sendable {
    public init(id: String, user: PartnerUserContext)
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

public func update(
    id: String,
    foods: [FoodSelection]? = nil,
    timestampUTC: String? = nil,
    name: String? = nil
) async throws -> FoodLog

public func delete(id: String) async throws -> DeleteFoodLogResponse
```

These methods are on `JanuaryClient.foodLogs` and automatically reuse the
client's configured context.

## Responses

`FoodLog` contains `id`, `[LoggedFood]`, `timestampUTC`, and optional `name`. Logged foods include nutrition, consumed serving, and serving details. `ListFoodLogsResponse` contains `totalCount` and `items`; delete returns a status string.

## Errors

Create validates an optional timestamp as ISO 8601 before transport. Update returns `.notFound` for a declared 404. Operations map declared 400, 401, and 429 responses plus other HTTP/transport/decoding failures to `JanuaryError`.
