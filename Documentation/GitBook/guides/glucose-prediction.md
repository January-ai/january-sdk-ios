# Glucose prediction

Use `client.glucose` to predict a user's glucose curve after a meal. These examples use the `client` from [Authentication](../getting-started/authentication.md); each prediction uses the client's timezone.

{% hint style="warning" %}
Glucose predictions and profile inputs are health data. Keep request and response values out of analytics, crash reports, and general-purpose logs.
{% endhint %}

## Predict

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
    startTime: Date()
)

let prediction = try await client.glucose.predict(request)
```

`foods` takes the `FoodSelection` from a [portion](../concepts/food-hydration-and-portions.md) or an [analyzed meal](food-logs.md#log-an-analyzed-meal). You can also pass recent `cgmData` (`CgmReading`) and `consumedFoods` (`ConsumedHistoricalFood`).

## Read the result

* `prediction`: one `GlucosePredictionPoint` every 15 minutes from `startTime`, with `minutes` after `startTime` and the predicted glucose `value` in mg/dL.
* `impact`: a `GlucoseImpact?`, such as `.lowImpact`, `.mediumImpact`, or `.highImpact`. It can be `nil`, or a value added in a later release, so don't assume those three are the only ones.
* `chart.min` and `chart.max`: suggested y-axis bounds in mg/dL, not the lowest or highest point of the curve. They mark a fixed target range; `chart.max` is 180 when `healthConditions` includes `.type2Diabetes`, and 140 otherwise.

```swift
for point in prediction.prediction {
    print(point.minutes, point.value) // minutes after startTime, mg/dL
}
if prediction.impact == .highImpact {
    showHighImpactNote()
}
```

`curve`, `scoring`, `minimum`, and `maximum` are older aliases for `prediction`, `impact`, `chart.min`, and `chart.max`.

## Height and weight

`Height` takes inches or centimeters, and `Weight` takes pounds or kilograms. For imperial height, show separate feet and inches fields and send the total in inches (`feet * 12 + inches`), not a single inches field. Let users switch between feet and inches and centimeters, and between pounds and kilograms.

{% hint style="info" %}
Predictions are informational. Don't present them as a diagnosis or as treatment guidance.
{% endhint %}

Next: [Voice capture](voice-capture.md).
