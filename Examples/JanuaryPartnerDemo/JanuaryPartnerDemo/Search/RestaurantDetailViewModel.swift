import January
import SwiftUI

@MainActor
final class RestaurantDetailViewModel: ObservableObject {
    @Published private(set) var menuItems: [RestaurantMenuItem] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?

    private let client: JanuaryClient
    private let restaurant: Restaurant
    private let latitude: Double
    private let longitude: Double
    private let radius: Double
    private let resultLimit: Int
    private let endUserID: PartnerUserID?
    private var hasLoaded = false

    init(
        client: JanuaryClient,
        restaurant: Restaurant,
        latitude: Double,
        longitude: Double,
        radius: Double,
        resultLimit: Int,
        endUserID: PartnerUserID?
    ) {
        self.client = client
        self.restaurant = restaurant
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.resultLimit = resultLimit
        self.endUserID = endUserID
    }

    var showsInitialLoading: Bool {
        isLoading && menuItems.isEmpty
    }

    func loadIfNeeded() async {
        guard !hasLoaded else { return }
        await load()
    }

    func retry() async {
        await load()
    }

    private func load() async {
        guard !isLoading else { return }
        hasLoaded = true
        isLoading = true
        error = nil

        do {
            do {
                var items: [RestaurantMenuItem] = []
                while true {
                    let page = try await client.restaurants.getMenuItems(.init(
                        restaurantID: restaurant.id, offset: items.count, endUserID: endUserID
                    ))
                    items.append(contentsOf: page.items)
                    if page.items.isEmpty || items.count >= page.totalCount { break }
                }
                menuItems = items
            } catch let failure as JanuaryError where isMissingRestaurantMenuRoute(failure) {
                let page = try await client.restaurants.searchMenuItems(.init(
                    query: restaurant.name,
                    latitude: latitude,
                    longitude: longitude,
                    radius: radius,
                    limit: min(max(resultLimit, 1), 100),
                    endUserID: endUserID
                ))
                let selectedName = normalizedRestaurantName(restaurant.name)
                menuItems = page.items.filter {
                    normalizedRestaurantName($0.restaurantName) == selectedName
                }
            }
        } catch {
            self.error = error
        }

        isLoading = false
    }

    private func isMissingRestaurantMenuRoute(_ error: JanuaryError) -> Bool {
        error.httpStatus == 404
            && error.message.contains("No v1.2 endpoint matches GET /v1.2/restaurants/")
            && error.message.contains("/menu-items")
    }

    private func normalizedRestaurantName(_ value: String) -> String {
        let baseName = value.split(separator: "(", maxSplits: 1).first.map(String.init) ?? value
        return baseName
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
