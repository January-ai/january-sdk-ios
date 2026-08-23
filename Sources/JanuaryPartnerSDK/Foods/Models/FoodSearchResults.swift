/// Results from a food-name search.
public struct FoodSearchResults: Codable, Hashable, Sendable {
    public var totalCount: Double
    public var items: [FoodSearchItem]

    public init(totalCount: Double, items: [FoodSearchItem]) {
        self.totalCount = totalCount
        self.items = items
    }
}
