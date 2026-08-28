# Glucose prediction

Use the `glucose` resource to predict a personalized glucose curve for selected foods.

{% hint style="warning" %}
Glucose predictions and profile inputs are health data. Do not place request or response values in analytics, crash reports, or general-purpose logs.
{% endhint %}

## Create a prediction

Configure the client so the same identity and timezone are applied to each prediction:

```swift
let client = try JanuaryClient(
    endUserID: PartnerUserID(rawValue: partnerUserID),
    timezone: "America/New_York",
    clientTokenProvider: tokenProvider
)
```

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

The result contains:

* `curve` — predicted curve data
* `scoring` — low, medium, or high impact
* `minimum` — predicted minimum value
* `maximum` — predicted maximum value

You can optionally provide recent `CgmReading` values and `ConsumedHistoricalFood` entries when available.

`Height` accepts inches or centimeters; `Weight` accepts pounds or kilograms.
For imperial height, present separate feet and inches controls, then convert to
total inches for the request—for example, `feet * 12 + inches`. Let users toggle
between feet plus inches and centimeters, and between pounds and kilograms. Do
not present a single raw-inch field.

{% hint style="info" %}
Predictions are informational and must not be presented as diagnosis or medical treatment guidance.
{% endhint %}

With client-token authentication, January derives identity from the token and the SDK removes the `x-end-user-id` header. The configured client still applies the timezone.
