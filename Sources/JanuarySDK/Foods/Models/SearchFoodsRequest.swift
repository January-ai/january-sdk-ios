/// Inputs for a food-name search.
public struct SearchFoodsRequest: Hashable, Sendable {
    public var query: String
    public var category: FoodCategory?
    public var limit: Int
    public var endUserID: PartnerUserID?

    public init(
        query: String,
        category: FoodCategory? = nil,
        limit: Int = 10,
        endUserID: PartnerUserID? = nil
    ) {
        self.query = query
        self.category = category
        self.limit = limit
        self.endUserID = endUserID
    }
}
