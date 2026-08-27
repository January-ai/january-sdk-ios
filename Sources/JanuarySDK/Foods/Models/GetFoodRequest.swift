/// Inputs for retrieving the complete record for a food.
public struct GetFoodRequest: Hashable, Sendable {
    public var foodID: FoodID
    public var endUserID: PartnerUserID?

    public init(foodID: FoodID, endUserID: PartnerUserID? = nil) {
        self.foodID = foodID
        self.endUserID = endUserID
    }
}
