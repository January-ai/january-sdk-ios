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

    private enum CodingKeys: String, CodingKey {
        case id
        case quantity
        case unit
        case scalingFactor = "scaling_factor"
        case weightGrams = "weight_grams"
        case isPrimary = "is_primary"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(ServingID.self, forKey: .id)
        quantity = try container.decode(Double.self, forKey: .quantity)
        unit = try container.decode(String.self, forKey: .unit)
        scalingFactor = try container.decodeIfPresent(Double.self, forKey: .scalingFactor) ?? 1.0
        weightGrams = try container.decodeIfPresent(Double.self, forKey: .weightGrams)
        isPrimary = try container.decode(Bool.self, forKey: .isPrimary)
    }
}
