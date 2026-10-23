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
    private var query = ""
    private var activeLoad = UUID()

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

    func search(_ query: String) async {
        self.query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        await load()
    }

    private func load() async {
        let loadID = UUID()
        activeLoad = loadID
        let menuQuery = query
        hasLoaded = true
        isLoading = true
        menuItems = []
        error = nil
        do {
            var items: [RestaurantMenuItem] = []
            var offset = 0
            while true {
                let page = try await client.restaurants.getMenuItems(.init(
                    restaurantID: restaurant.id, offset: offset, endUserID: endUserID, query: menuQuery
                ))
                guard activeLoad == loadID, !Task.isCancelled else { return }
                items.append(contentsOf: page.items.enumerated().map { index, entry in
                    RestaurantMenuItem(
                        id: entry.id ?? "menu-\(offset + index)",
                        name: entry.name, restaurantName: restaurant.name,
                        calories: entry.calories, protein: entry.protein,
                        carbohydrates: entry.carbohydrates, netCarbohydrates: entry.netCarbohydrates,
                        totalFat: entry.totalFat, fiber: entry.fiber,
                        totalSugars: entry.totalSugars, addedSugars: entry.addedSugars,
                        glycemicIndex: entry.glycemicIndex, glycemicLoad: entry.glycemicLoad,
                        servings: entry.servings
                    )
                })
                offset += page.items.count
                if page.items.count < 100 { break }
            }
            menuItems = items
        } catch {
            guard activeLoad == loadID, !Task.isCancelled else { return }
            self.error = error
        }
        if activeLoad == loadID { isLoading = false }
    }

}
