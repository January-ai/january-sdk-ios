# Restaurants

Use `client.restaurants` to discover nearby restaurants or search their menu items.

## Search restaurants

```swift
let restaurants = try await client.restaurants.search(
    .init(
        query: "mediterranean",
        latitude: 37.7749,
        longitude: -122.4194,
        radius: 8_000,
        limit: 10,
        endUserID: userID
    )
)
```

## Search menu items

```swift
let menuItems = try await client.restaurants.searchMenuItems(
    .init(
        query: "grilled chicken",
        latitude: 37.7749,
        longitude: -122.4194,
        endUserID: userID
    )
)
```

Menu-item results may include nutrition, serving choices, photos, restaurant names, and distance.

## Input limits

* Query: 1–256 characters
* Latitude: −90 through 90
* Longitude: −180 through 180
* Radius: 1–17,000
* Limit: 1–100

