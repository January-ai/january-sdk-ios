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
    private let menuQuery: String
    private let endUserID: PartnerUserID?
    private var hasLoaded = false

    init(
        client: JanuaryClient,
        restaurant: Restaurant,
        latitude: Double,
        longitude: Double,
        radius: Double,
        resultLimit: Int,
        menuQuery: String,
        endUserID: PartnerUserID?
    ) {
        self.client = client
        self.restaurant = restaurant
        self.latitude = latitude
        self.longitude = longitude
        self.radius = radius
        self.resultLimit = resultLimit
        self.menuQuery = menuQuery
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
            let response = try await client.restaurants.searchMenuItems(.init(
                query: menuQuery,
                latitude: latitude,
                longitude: longitude,
                radius: radius,
                limit: resultLimit,
                endUserID: endUserID
            ))
            let selectedRestaurantName = normalizedRestaurantName(restaurant.name)
            menuItems = response.items.filter {
                let itemRestaurantName = normalizedRestaurantName($0.restaurantName)
                return itemRestaurantName.contains(selectedRestaurantName)
                    || selectedRestaurantName.contains(itemRestaurantName)
            }
        } catch {
            self.error = error
        }

        isLoading = false
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
