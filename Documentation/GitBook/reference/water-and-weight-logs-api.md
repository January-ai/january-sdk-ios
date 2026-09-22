# Water and Weight Logs API

## Operations

```swift
// JanuaryClient.waterLogs
public func create(_ request: CreateWaterLogRequest) async throws -> WaterLog
public func list(_ request: ListWaterLogsRequest) async throws -> ListWaterLogsResponse
public func delete(_ request: DeleteWaterLogRequest) async throws -> DeleteWaterLogResponse

// JanuaryClient.weightLogs
public func create(_ request: CreateWeightLogRequest) async throws -> WeightLog
public func list(_ request: ListWeightLogsRequest) async throws -> ListWeightLogsResponse
```

## Requests and defaults

```swift
public struct CreateWaterLogRequest: Hashable, Sendable {
    public init(amount: WaterAmount, consumedAtUTC: String? = nil, user: PartnerUserContext)
}

public struct ListWaterLogsRequest: Hashable, Sendable {
    public init(start: String, end: String, unit: VolumeUnit = .fluidOunces, user: PartnerUserContext)
}

public struct DeleteWaterLogRequest: Hashable, Sendable {
    public init(id: String, user: PartnerUserContext)
}

public struct CreateWeightLogRequest: Hashable, Sendable {
    public init(weight: Weight, measuredAtUTC: String? = nil, user: PartnerUserContext)
}

public struct ListWeightLogsRequest: Hashable, Sendable {
    public init(start: String, end: String, user: PartnerUserContext)
}
```

## Configured-client operations

```swift
public func create(amount: WaterAmount, consumedAtUTC: String? = nil) async throws -> WaterLog
public func list(start: String, end: String, unit: VolumeUnit = .fluidOunces) async throws -> ListWaterLogsResponse
public func delete(id: String) async throws -> DeleteWaterLogResponse

public func create(weight: Weight, measuredAtUTC: String? = nil) async throws -> WeightLog
public func list(start: String, end: String) async throws -> ListWeightLogsResponse
```

These methods are on `JanuaryClient.waterLogs` and `JanuaryClient.weightLogs`
and automatically reuse the client's configured context.

## Responses

`WaterLog` contains `id`, the `amount` (`WaterAmount`: `value` and `VolumeUnit`)
as logged, and `consumedAtUTC`. `ListWaterLogsResponse.items` is
`[DailyWaterTotal]`: a local `date` and a `total` (`Volume`, rounded to one
decimal place) in the requested unit, oldest first. Delete returns nothing.

`WeightLog` contains the `weight` (`Weight`: `value` and `WeightUnit`) as logged
and `measuredAtUTC`. `ListWeightLogsResponse.items` is `[DailyWeight]`: a local
`date` and that day's latest `weight`, in the unit it was logged in, oldest
first.

Timestamps in responses are ISO 8601 in UTC with milliseconds. Dates are
`yyyy-MM-dd` in the request's timezone.

## Errors

Create validates the amount or weight range and an optional ISO-8601 timestamp
before transport. Operations map declared 400, 401, 403, and 429 responses plus
other HTTP, transport, and decoding failures to `JanuaryError`. A response that
carries an unknown unit is reported as a `.decoding` error. The API's
`daily_water_limit_exceeded` and `date_range_too_large` codes arrive as
`.validation` errors with `code` set.
