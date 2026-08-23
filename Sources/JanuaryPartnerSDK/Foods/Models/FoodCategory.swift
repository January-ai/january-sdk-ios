/// A category used to narrow a food search.
public enum FoodCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case general
    case branded
    case recipe
}
