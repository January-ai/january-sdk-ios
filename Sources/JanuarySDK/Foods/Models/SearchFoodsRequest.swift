/// Inputs for a food-name search.
public struct SearchFoodsRequest: Hashable, Sendable {
    public var query: String
    public var category: FoodCategory?
    /// Results per call, 1 through 50.
    public var limit: Int
    /// Results to skip for paging; a page shorter than `limit` is the last one.
    public var offset: Int
    public var endUserID: PartnerUserID?

    public init(
        query: String,
        category: FoodCategory? = nil,
        limit: Int = 10,
        endUserID: PartnerUserID? = nil,
        offset: Int = 0
    ) {
        self.query = query
        self.category = category
        self.limit = limit
        self.offset = offset
        self.endUserID = endUserID
    }
}
