# Photo scanning

Use `client.photoScanning` to analyze a meal image and submit natural-language corrections.

{% hint style="warning" %}
Meal images and inferred nutrition may be sensitive user data. Obtain appropriate consent, minimize retention, and never write image contents or results to application logs.
{% endhint %}

## Scan a public image URL

```swift
let scan = try await client.photoScanning.scan(
    .init(image: publicImageURL, endUserID: userID)
)
```

## Scan image data

Use `PhotoScanImage` to normalize orientation, preserve aspect ratio, limit the
longest edge to 1,000 pixels, compress to JPEG, and create a data URI:

```swift
let dataURI = try PhotoScanImage.dataURI(from: imageData)

let scan = try await client.photoScanning.scan(
    .init(image: dataURI, endUserID: userID)
)
```

For a ready-made native SwiftUI flow, present `JanuaryMealScannerView`. It
supports photo and barcode modes and returns hydrated scan or food results.

The response can contain a meal name, detected foods, total nutrients, confidence values, and glucose impact.

## Correct a result

```swift
guard
    let mealName = scan.mealName,
    let detections = scan.detections
else { return }

let corrected = try await client.photoScanning.correct(
    .init(
        mealName: mealName,
        detections: detections,
        userInput: "Remove the fries and rename this grilled chicken sandwich.",
        endUserID: userID
    )
)
```
