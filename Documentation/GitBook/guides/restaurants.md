# Restaurants

Use the `restaurants` resource to discover nearby restaurants or search their menu items.

Configure the signed-in user once on the client:

```swift
let client = try JanuaryClient(
    endUserID: partnerUserID,
    clientTokenProvider: tokenProvider
)
```

With client-token authentication, January derives identity from the token and the SDK removes the `x-end-user-id` header.

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
    print(restaurant.name, restaurant.distance as Any)
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

Menu-item results may include nutrition, serving choices, photos, restaurant names, and distance.

## Load one restaurant's menu

Use the ID returned by restaurant search to load that restaurant's menu without
repeating the search text or location:

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

    if page.items.isEmpty || offset >= page.totalCount {
        break
    }
} while true
```

An unknown restaurant returns `404`. An existing restaurant with no menu
returns an empty `items` array.

## Input limits

* Restaurant ID: nonblank
* Query: 1–256 characters
* Latitude: −90 through 90
* Longitude: −180 through 180
* Radius: 1–17,000
* Limit: 1–100
* Menu offset: 0 or greater

Coordinate values are decimal degrees, and radius is expressed in meters. Both request types default to `8_000` meters (approximately 5 miles) when `radius` is omitted. The current SDK accepts values from 1 through 17,000 meters.
