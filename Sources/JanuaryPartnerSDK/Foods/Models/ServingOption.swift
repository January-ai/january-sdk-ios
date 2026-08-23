/// A serving option returned with a food.
public struct ServingOption: Codable, Hashable, Sendable {
    public var id: ServingID
    public var quantity: Double
    public var unit: String
    public var scalingFactor: Double
    public var weightGrams: Double?
    public var isPrimary: Bool

    public init(
        id: ServingID,
        quantity: Double,
        unit: String,
        scalingFactor: Double,
        weightGrams: Double? = nil,
        isPrimary: Bool
    ) {
        self.id = id
        self.quantity = quantity
        self.unit = unit
        self.scalingFactor = scalingFactor
        self.weightGrams = weightGrams
        self.isPrimary = isPrimary
    }
}
