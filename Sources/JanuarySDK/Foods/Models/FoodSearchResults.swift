/// Results from a food-name search.
public struct FoodSearchResults: Codable, Hashable, Sendable {
    public var totalCount: Int
    public var items: [FoodSearchItem]

    public init(totalCount: Int, items: [FoodSearchItem]) {
        self.totalCount = totalCount
        self.items = items
    }
}
