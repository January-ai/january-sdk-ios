# Glucose API

## Operation

```swift
public func predict(
    _ request: PredictGlucoseRequest
) async throws -> GlucosePrediction
```

## Request and defaults

```swift
public struct PredictGlucoseRequest: Hashable, Sendable {
    public init(
        userProfile: GlucosePredictionProfile,
        foods: [FoodSelection],
        startTime: Date,
        cgmData: [CgmReading]? = nil,
        consumedFoods: [ConsumedHistoricalFood]? = nil,
        endUserID: PartnerUserID? = nil,
        timezone: TimeZone? = nil
    )
}
```

`JanuaryClient.glucose` sends the client's timezone and ignores the request's `endUserID` and `timezone`.

## Profile

```swift
public struct GlucosePredictionProfile: Codable, Hashable, Sendable {
    public init(
        age: Double,
        sex: Sex,
        height: Height,
        weight: Weight,
        activityLevel: ActivityLevel? = nil,
        healthConditions: [MedicalCondition]? = nil
    )
}
```

The legacy `gender:height:weight:` initializer interprets raw height as inches and raw weight as pounds. Prefer the typed initializer.

## Optional history

`CgmReading` requires an ISO 8601 timestamp string and a numeric value. `ConsumedHistoricalFood` requires timestamp, `FoodID`, and `ConsumedHistoricalServing`. Invalid timestamp strings fail locally with `.validation`.

## Response

`GlucosePrediction` exposes:

* `prediction: [GlucosePredictionPoint]`;
* `impact: GlucoseImpact?`;
* `chart: GlucoseChart`;
* the older aliases `curve`, `scoring`, `minimum`, and `maximum`.

`GlucosePredictionPoint` has `minutes` after `startTime` and the predicted `value` in mg/dL. `GlucoseChart` has optional `min` and `max`: suggested y-axis bounds in mg/dL, not the curve's lowest and highest points. `GlucoseImpact` is a `RawRepresentable` struct that can carry values added later; compare against `.lowImpact`, `.mediumImpact`, and `.highImpact` without assuming they're the only ones. See [Read the result](../guides/glucose-prediction.md#read-the-result).

## Errors

Predict checks that `age` is a whole number and that history timestamps are ISO 8601 before sending. It maps 400 to `.validation`, 401 to `.authentication`, 403 to `.authorization`, 429 to `.rateLimited`, and 504 to `.timeout`; other API errors map to `JanuaryError` by status.
