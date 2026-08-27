/// A stable identifier for a January food record.
public struct FoodID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: Int64

    public init(rawValue: Int64) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(Int64.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A stable identifier for a serving option.
public struct ServingID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: Int64

    public init(rawValue: Int64) {
        self.rawValue = rawValue
    }

    public init(from decoder: any Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(Int64.self)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

/// A partner-owned identifier for the end user a request acts on behalf of.
public struct PartnerUserID: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}
