# Photo scanning

Use the `photoScanning` resource to analyze a meal image and submit natural-language corrections.

{% hint style="warning" %}
Meal images and inferred nutrition may be sensitive user data. Obtain appropriate consent, minimize retention, and never write image contents or results to application logs.
{% endhint %}

Configure the signed-in user once on the client:

```swift
let client = try JanuaryClient(
    endUserID: PartnerUserID(rawValue: partnerUserID),
    clientTokenProvider: tokenProvider
)
```

With client-token authentication, January derives identity from the token and the SDK removes the `x-end-user-id` header.

## Scan a public image URL

```swift
let scan = try await client.photoScanning.scan(
    .init(image: publicImageURL.absoluteString)
)
```

## Scan image data

Use `PhotoScanImage` to normalize orientation, preserve aspect ratio, limit the
longest edge to 1,000 pixels, compress to JPEG, and create a data URI:

```swift
let dataURI = try PhotoScanImage.dataURI(from: imageData)

let scan = try await client.photoScanning.scan(
    .init(image: dataURI)
)
```

For a ready-made native SwiftUI flow, present `JanuaryMealScannerView`. It
supports photo and barcode modes and returns analyzed meal images or fully hydrated barcode food records. See [Native meal scanner](native-meal-scanner.md).

The response can contain a meal name, detected foods, total nutrients, confidence values, and glucose impact.

## Correct a result

```swift
let corrected = try await client.photoScanning.correct(
    .init(
        mealName: scan.mealName,
        detections: scan.detections,
        userInput: "Remove the fries and rename this grilled chicken sandwich."
    )
)
```

`detections` is always an array; it may be empty. `mealName`, total nutrients, and glucose impact are optional.
