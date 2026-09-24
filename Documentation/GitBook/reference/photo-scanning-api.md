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
    public init(analysis: FoodScan, instruction: String, endUserID: PartnerUserID? = nil)
}
```

The `image` string is a public URL or a data URI. The `imageData` initializer orients the image, scales its longest edge down to `maxDimension`, compresses it to JPEG, and builds the data URI; `PhotoScanImage.jpegData(from:)` and `PhotoScanImage.dataURI(from:)` do the same preparation on their own. When `reasoningEffort` is `nil`, the request leaves the choice to the API, which uses the reasoning-based analyzer. `.none` selects the standard analyzer, and `.xhigh` asks for the reasoning-based one explicitly. Both return the same result shape at the same cost.

`CorrectPhotoScanRequest` takes the complete prior `FoodScan`, unchanged, and a plain-language `instruction`. The `init(mealName:detections:userInput:endUserID:)` initializer is deprecated.

## Response models

`FoodScan.detections` is a nonoptional array. `mealName` is optional; `totalNutrients` is not. `glucoseImpact` is deprecated and always `nil`; use `glucose.predict` for a glucose impact. Each `FoodDetection` contains a `DetectedFood` and optional `ConfidenceScore` (`high`, `medium`, or `low`).

`DetectedFood` has `id`, `name`, `brandName`, `nutrients`, `serving`, and `quantity`. `serving` is the selected catalog serving (`ServingSummary` with `id`, `quantity`, `unit`, where `quantity` is the size of one serving) and `quantity` is how many of that serving were eaten. `id`, `serving.id`, and `quantity` are optionals in Swift; unwrap them and pass `FoodSelection(id: id, serving: ServingSelection(id: servingID, quantity: quantity))` to log the detection as is (see [Food logs](../guides/food-logs.md#log-an-analyzed-meal)). `nutrients` are already scaled to `quantity`.

Food alternatives (`foods.suggestAlternatives`) return `AlternativeFood` values with `servings: [ServingSummary]` to read the nutrition against.

## Errors

Photo analysis maps 413 to `.validation`, and every operation maps 504 to `.timeout`. Other API errors map to `JanuaryError` by status. Image preparation throws `PhotoScanImageError.invalidImage` or `.encodingFailed`.

The camera scanner types are on the [Native food scanner](../guides/native-meal-scanner.md) page and in [Models and enums](models-and-enums.md#scanner-types).
