# Glucose prediction

Use `client.glucose` to predict a personalized glucose curve for selected foods.

{% hint style="warning" %}
Glucose predictions and profile inputs are health data. Do not place request or response values in analytics, crash reports, or general-purpose logs.
{% endhint %}

## Create a prediction

```swift
let request = PredictGlucoseRequest(
    userProfile: GlucosePredictionProfile(
        age: 35,
        gender: .male,
        height: 70,
        weight: 175,
        activityLevel: .moderatelyActive,
        healthConditions: [.noneOfTheAbove]
    ),
    foods: [selectedFood],
    startTime: Date(),
    endUserID: userID,
    timezone: "America/New_York"
)

let prediction = try await client.glucose.predict(request)
```

The result contains:

* `curve` — predicted curve data
* `scoring` — low, medium, or high impact
* `minimum` — predicted minimum value
* `maximum` — predicted maximum value

You can optionally provide recent `CgmReading` values and `ConsumedHistoricalFood` entries when available.

{% hint style="info" %}
Predictions are informational and must not be presented as diagnosis or medical treatment guidance.
{% endhint %}

