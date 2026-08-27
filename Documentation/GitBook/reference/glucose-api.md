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
        timezone: String? = nil
    )
}
```

The user-scoped equivalent is:

```swift
public func predict(
    _ request: PredictGlucoseRequest
) async throws -> GlucosePrediction
```

`JanuaryUserClient.glucose` replaces the request's identity and timezone with its stored context.

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

`CgmReading` requires an ISO-8601 timestamp string and numeric value. `ConsumedHistoricalFood` requires timestamp, `FoodID`, and `ConsumedHistoricalServing`. Invalid timestamp strings fail locally with `.validation`.

## Response

`GlucosePrediction` exposes:

* `prediction: [GlucosePredictionPoint]`;
* `impact: GlucoseImpact`;
* `chart: GlucoseChart`;
* compatibility projections `curve`, `scoring`, `minimum`, and `maximum`.

`GlucoseImpact` is open to future server values through `RawRepresentable`; compare known constants `.lowImpact`, `.mediumImpact`, and `.highImpact` without assuming they are exhaustive.

## Errors

Predict maps declared 400 to `.validation`, 401 to `.authentication`, 429 to `.rateLimited`, and 504 to `.timeout`. Other statuses and transport/decoding failures map through `JanuaryError`.
