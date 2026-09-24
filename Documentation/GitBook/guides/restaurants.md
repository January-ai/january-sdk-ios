# Restaurants

Use `client.restaurants` to find nearby restaurants, search their menu items, and load one restaurant's menu. These examples use the `client` from [Authentication](../getting-started/authentication.md).

The SDK doesn't read the device location. Get coordinates from Core Location, which needs `NSLocationWhenInUseUsageDescription` in your `Info.plist`.

## Search restaurants

```swift
let restaurants = try await client.restaurants.search(
    .init(
        query: "mediterranean",
        latitude: 37.7749,
        longitude: -122.4194,
        radius: 8_000,
        limit: 10
    )
)

for restaurant in restaurants.items {
    print(restaurant.name ?? "", restaurant.distance as Any)
}
```

## Search menu items

```swift
let menuItems = try await client.restaurants.searchMenuItems(
    .init(
        query: "grilled chicken",
        latitude: 37.7749,
        longitude: -122.4194
    )
)
```

Menu-item results can include nutrition, serving choices, photos, restaurant names, and distance.

## Load a restaurant menu

Pass the ID from a restaurant search to `getMenuItems` to load that restaurant's menu without repeating the search text or location:

```swift
var offset = 0
let limit = 100

repeat {
    let page = try await client.restaurants.getMenuItems(
        .init(
            restaurantID: restaurant.id,
            limit: limit,
            offset: offset
        )
    )

    consume(page.items)
    offset += page.items.count

    if page.items.count < limit {
        break
    }
} while true
```

The response has only `items`, with no `totalCount`, so keep paging while full pages come back. An empty page ends the menu, including for a restaurant with no menu on record. An unknown restaurant fails with `.notFound`; in a discovery UI, fall back to `searchMenuItems` with the user's original query and location.

## Input limits

* Restaurant ID: not blank
* Query: 1–256 characters
* Latitude: −90 through 90; longitude: −180 through 180, in decimal degrees
* Radius: 1–50,000 meters; default 8,000 (about 5 miles)
* Limit: 1–100
* Menu offset: 0 or more

Next: [Food analysis](photo-scanning.md).
