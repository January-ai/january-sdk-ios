# Food analysis

Use `client.foodAnalysis` to analyze a meal photo or a description, and to correct a result. These examples use the `client` from [Authentication](../getting-started/authentication.md).

{% hint style="warning" %}
Meal photos and their nutrition can be sensitive. Get the user's consent, keep as little as you can, and never write image contents or results to logs.
{% endhint %}

An analysis can take tens of seconds. Show progress, and don't retry a `.timeout` automatically.

## Analyze a photo

Pass the image bytes. The request orients the image, scales its longest edge down to 1,000 pixels, and compresses it to JPEG:

```swift
let request = try ScanFoodPhotoRequest(imageData: imageData)
let scan = try await client.foodAnalysis.analyzePhoto(request)
```

To get `imageData` from the photo library, call `loadTransferable(type: Data.self)` on a `PhotosPicker` item (iOS 16 and later), or `loadDataRepresentation(forTypeIdentifier: UTType.image.identifier)` on a `PHPickerViewController` result's item provider (iOS 15).

For an image at a public URL, pass the URL string instead:

```swift
let scan = try await client.foodAnalysis.analyzePhoto(.init(image: imageURL.absoluteString))
```

For a ready-made camera screen, use the [native food scanner](native-meal-scanner.md).

## Analyze a description

```swift
let meal = try await client.foodAnalysis.analyzeDescription(
    .init(query: "one banana and a bowl of oatmeal")
)
```

## Read the result

Both calls return a `FoodScan`: `detections` (always an array, possibly empty), `totalNutrients`, and an optional `mealName`. Each detection's `food` has the food `id`, the selected `serving`, and the `quantity` eaten, so you can [log it](food-logs.md#log-an-analyzed-meal) without another lookup. Food analysis doesn't return a glucose impact; use [glucose prediction](glucose-prediction.md) for that.

## Correct a result

```swift
let corrected = try await client.foodAnalysis.correct(
    .init(analysis: scan, instruction: "Remove the fries and rename this grilled chicken sandwich.")
)
```

Pass the analysis back exactly as it was returned. The SDK rejects, before sending, a detection that's missing its food ID, serving ID, serving quantity, or quantity. A detection's serving `weightGrams` is sent when the API reported it.

Next: [Native food scanner](native-meal-scanner.md).
