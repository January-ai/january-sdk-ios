# Restaurants API

## Operations

```swift
public func search(
    _ request: SearchRestaurantsRequest
) async throws -> SearchRestaurantsResponse

public func searchMenuItems(
    _ request: SearchRestaurantMenuItemsRequest
) async throws -> SearchRestaurantMenuItemsResponse
```

## Requests and defaults

Both request types require `query`, `latitude`, and `longitude`. Both default to `radius: 8000`, `limit: 10`, and `endUserID: nil`.

```swift
public struct SearchRestaurantsRequest: Hashable, Sendable {
    public init(
        query: String,
        latitude: Double,
        longitude: Double,
        radius: Double = 8000,
        limit: Int = 10,
        endUserID: PartnerUserID? = nil
    )
}
```

`SearchRestaurantMenuItemsRequest` has the same initializer shape.

## Responses

`SearchRestaurantsResponse` has `totalCount: Int` and `items: [Restaurant]`. A `Restaurant` exposes type, ID, name, optional chain flag, distance, city, and address fields.

`SearchRestaurantMenuItemsResponse` has `totalCount: Int` and `items: [RestaurantMenuItem]`. Menu items include ID/name, restaurant name, optional nutrition, image, glycemic data, distance, and `[ServingOption]`.

## Errors

The SDK validates query length, coordinates, radius, and limit before transport. API responses map 400, 401, 429, and other status codes to `JanuaryError`. See [Validation limits](validation.md).
