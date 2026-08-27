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
        sex: .male,
        height: Height(value: 70, unit: .inches),
        weight: Weight(value: 175, unit: .pounds),
        activityLevel: .moderatelyActive,
        healthConditions: []
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

`Height` accepts inches or centimeters; `Weight` accepts pounds or kilograms.
The demo presents imperial height as feet plus inches and converts that display
to the typed request value. Do not present a single raw-inch field to users.

{% hint style="info" %}
Predictions are informational and must not be presented as diagnosis or medical treatment guidance.
{% endhint %}
