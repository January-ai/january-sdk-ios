# Food analysis API

## Operations

```swift
public func analyzePhoto(
    _ request: ScanFoodPhotoRequest
) async throws -> FoodScan

public func analyzeDescription(
    _ request: SearchFoodsByNaturalLanguageRequest
) async throws -> FoodScan

public func correct(
    _ request: CorrectPhotoScanRequest
) async throws -> FoodScan
```

## Requests and defaults

```swift
public struct ScanFoodPhotoRequest: Hashable, Sendable {
    public init(image: String, endUserID: PartnerUserID? = nil, reasoningEffort: AnalysisEffort? = nil)
    public init(
        imageData: Data,
        endUserID: PartnerUserID? = nil,
        maxDimension: Int = 1_000,
        compressionQuality: Double = 0.7,
        reasoningEffort: AnalysisEffort? = nil
    ) throws
}

public struct CorrectPhotoScanRequest: Hashable, Sendable {
    public init(
        mealName: String? = nil,
        detections: [FoodDetection],
        userInput: String,
        endUserID: PartnerUserID? = nil
    )
}
```

The string image can be a public URL string or data URI. The `Data` initializer normalizes orientation, preserves aspect ratio, bounds the longest edge, compresses to JPEG, and creates the data URI. When `reasoningEffort` is `nil`, the request leaves the choice to the API, which uses the reasoning-based analyzer. `.none` selects the standard analyzer, and `.xhigh` asks for the reasoning-based one explicitly. Both return the same result shape at the same cost.

## Response models

`FoodScan.detections` is a nonoptional array. `mealName` is optional. Each `FoodDetection` contains a `DetectedFood` and optional `ConfidenceScore` (`high`, `medium`, or `low`).

`DetectedFood` has `id`, `name`, `brandName`, `nutrients`, `serving`, and `quantity`. `serving` is the selected catalog serving (`ServingSummary` with `id`, `quantity`, `unit`, where `quantity` is the size of one serving) and `quantity` is how many of that serving were eaten, so `FoodSelection(id: food.id, serving: ServingSelection(id: food.serving.id, quantity: food.quantity))` logs the detection as is. `nutrients` are already scaled to `quantity`.

Food alternatives (`foods.suggestAlternatives`) return `AlternativeFood` values with `servings: [ServingSummary]` to read the nutrition against.

## Errors

Scan maps 413 to `.validation` and 504 to `.timeout`; correction also maps 504 to `.timeout`. Both map 400, 401, 429, and other statuses to `JanuaryError`. Image preparation throws `PhotoScanImageError.invalidImage` or `.encodingFailed`.

The native scanner types are documented separately in [Native food scanner](../guides/native-meal-scanner.md) because they are iOS-only.
