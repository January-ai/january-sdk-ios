# Photo scanning API

## Operations

```swift
public func scan(
    _ request: ScanFoodPhotoRequest
) async throws -> FoodScan

public func searchByNaturalLanguage(
    _ request: SearchFoodsByNaturalLanguageRequest
) async throws -> FoodScan

public func correct(
    _ request: CorrectPhotoScanRequest
) async throws -> FoodScan
```

`FoodsResource.searchByNaturalLanguage` and `PhotoScanningResource.searchByNaturalLanguage` expose the same Partner API workflow for convenience.

## Requests and defaults

```swift
public struct ScanFoodPhotoRequest: Hashable, Sendable {
    public init(image: String, endUserID: PartnerUserID? = nil)
    public init(
        imageData: Data,
        endUserID: PartnerUserID? = nil,
        maxDimension: Int = 1_000,
        compressionQuality: Double = 0.7
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

The string image can be a public URL string or data URI. The `Data` initializer normalizes orientation, preserves aspect ratio, bounds the longest edge, compresses to JPEG, and creates the data URI.

## Response models

`FoodScan.detections` is a nonoptional array. `mealName`, `totalNutrients`, and `glucoseImpact` are optional. Each `FoodDetection` contains a `DetectedFood` and optional `ConfidenceScore` (`high`, `medium`, or `low`).

## Errors

Scan maps 413 to `.validation` and 504 to `.timeout`; correction also maps 504 to `.timeout`. Both map 400, 401, 429, and other statuses to `JanuaryError`. Image preparation throws `PhotoScanImageError.invalidImage` or `.encodingFailed`.

The native scanner types are documented separately in [Native meal scanner](../guides/native-meal-scanner.md) because they are iOS-only.
