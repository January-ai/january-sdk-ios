# Restaurants API

## Operations

```swift
public func search(
    _ request: SearchRestaurantsRequest
) async throws -> SearchRestaurantsResponse

public func searchMenuItems(
    _ request: SearchRestaurantMenuItemsRequest
) async throws -> SearchRestaurantMenuItemsResponse

public func getMenuItems(
    _ request: GetRestaurantMenuItemsRequest
) async throws -> GetRestaurantMenuItemsResponse
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

`GetRestaurantMenuItemsRequest` loads a menu from a restaurant ID returned by
`search`. It defaults to a 100-item page, the SDK's maximum, and the first offset:

```swift
public struct GetRestaurantMenuItemsRequest: Hashable, Sendable {
    public init(
        restaurantID: String,
        limit: Int = 100,
        offset: Int = 0,
        endUserID: PartnerUserID? = nil
    )
}
```

## Responses

`SearchRestaurantsResponse` has `totalCount: Int` and `items: [Restaurant]`. A `Restaurant` exposes type, ID, name, optional chain flag, distance, city, and address fields.

`SearchRestaurantMenuItemsResponse` has `totalCount: Int` and `items: [RestaurantMenuItem]`. Menu items include ID/name, restaurant name, optional nutrition, image, glycemic data, distance, and `[ServingOption]`.

`GetRestaurantMenuItemsResponse` contains only `items: [RestaurantMenuEntry]`, with no `totalCount`; see [paging a menu](../guides/restaurants.md#load-a-restaurant-menu).

## Errors

The SDK checks the query length, coordinates, radius, limit, and offset before sending ([Validation limits](validation.md)). An unknown restaurant ID fails with `.notFound`. Other API errors map to `JanuaryError` by status.
