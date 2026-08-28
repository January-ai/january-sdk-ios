# Restaurants

Use the `restaurants` resource to discover nearby restaurants or search their menu items.

Create a scoped client once for the signed-in user:

```swift
let user = client.forUser(PartnerUserID(rawValue: partnerUserID))
```

With client-token authentication, January derives identity from the token and the SDK removes the `x-end-user-id` header.

## Search restaurants

```swift
let restaurants = try await user.restaurants.search(
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
let menuItems = try await user.restaurants.searchMenuItems(
    .init(
        query: "grilled chicken",
        latitude: 37.7749,
        longitude: -122.4194
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

Coordinate values are decimal degrees, and radius is expressed in meters. Both request types default to `8_000` meters (approximately 5 miles) when `radius` is omitted. The current SDK accepts values from 1 through 17,000 meters.
