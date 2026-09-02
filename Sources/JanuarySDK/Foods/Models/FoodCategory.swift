/// A category used to narrow a food search.
public enum FoodCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case generic
    case branded
    case recipe
}

public extension FoodCategory {
    @available(*, deprecated, renamed: "generic")
    static var general: Self { .generic }
}
