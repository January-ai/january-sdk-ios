import Foundation

/// Unit of a logged or totalled volume of water.
public enum VolumeUnit: String, Codable, Hashable, Sendable, CaseIterable {
    case fluidOunces = "fl_oz"
    case milliliters = "ml"
}

/// An amount of water to log: 1–811.5 fluid ounces or 30–24,000 milliliters.
public struct WaterAmount: Codable, Hashable, Sendable {
    public var value: Double
    public var unit: VolumeUnit
    public init(value: Double, unit: VolumeUnit) { self.value = value; self.unit = unit }
}

/// A totalled volume of water, rounded to one decimal place.
public struct Volume: Codable, Hashable, Sendable {
    public var value: Double
    public var unit: VolumeUnit
    public init(value: Double, unit: VolumeUnit) { self.value = value; self.unit = unit }
}

/// One recorded water intake. Keep `id` to delete it later.
public struct WaterLog: Codable, Hashable, Sendable {
    public var id: String
    /// The amount as logged, in the unit it was sent in.
    public var amount: WaterAmount
    /// When the water was consumed, in UTC with milliseconds.
    public var consumedAtUTC: String
    public init(id: String, amount: WaterAmount, consumedAtUTC: String) {
        self.id = id; self.amount = amount; self.consumedAtUTC = consumedAtUTC
    }
    enum CodingKeys: String, CodingKey { case id, amount; case consumedAtUTC = "consumed_at" }
}

/// Everything logged on one local calendar day, in the unit the request asked for.
public struct DailyWaterTotal: Codable, Hashable, Sendable {
    /// Local calendar date (`yyyy-MM-dd`) in the request's timezone.
    public var date: String
    public var total: Volume
    public init(date: String, total: Volume) { self.date = date; self.total = total }
}

/// One entry per local day with water logged, oldest first. Days with nothing logged are absent.
public struct ListWaterLogsResponse: Codable, Hashable, Sendable {
    public var items: [DailyWaterTotal]
    public init(items: [DailyWaterTotal]) { self.items = items }
}

public struct CreateWaterLogRequest: Hashable, Sendable {
    public var amount: WaterAmount
    /// ISO-8601 date-time with any offset. Omitted means now.
    public var consumedAtUTC: String?
    public var user: PartnerUserContext
    public init(amount: WaterAmount, consumedAtUTC: String? = nil, user: PartnerUserContext) {
        self.amount = amount; self.consumedAtUTC = consumedAtUTC; self.user = user
    }
}

/// Daily totals between `start` and `end` (inclusive `yyyy-MM-dd` dates in the user's timezone,
/// at most 5 years back), in `unit`. When more than 100 days have water logged, the most recent 100 are returned.
public struct ListWaterLogsRequest: Hashable, Sendable {
    public var start: String
    public var end: String
    public var unit: VolumeUnit
    public var user: PartnerUserContext
    public init(start: String, end: String, unit: VolumeUnit = .fluidOunces, user: PartnerUserContext) {
        self.start = start; self.end = end; self.unit = unit; self.user = user
    }
}

public struct DeleteWaterLogRequest: Hashable, Sendable {
    public var id: String; public var user: PartnerUserContext
    public init(id: String, user: PartnerUserContext) { self.id = id; self.user = user }
}

public typealias DeleteWaterLogResponse = Void
