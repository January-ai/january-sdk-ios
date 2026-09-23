import Foundation

/// One recorded weight measurement, as stored.
public struct WeightLog: Codable, Hashable, Sendable {
    /// The weight as logged, in the unit it was sent in.
    public var weight: Weight
    /// When the weight was measured, in UTC with milliseconds.
    public var measuredAtUTC: String
    public init(weight: Weight, measuredAtUTC: String) { self.weight = weight; self.measuredAtUTC = measuredAtUTC }
    enum CodingKeys: String, CodingKey { case weight; case measuredAtUTC = "created_at" }
}

/// The latest weight measured on one local calendar day.
public struct DailyWeight: Codable, Hashable, Sendable {
    /// Local calendar date (`yyyy-MM-dd`) in the request's timezone.
    public var date: String
    public var weight: Weight
    public init(date: String, weight: Weight) { self.date = date; self.weight = weight }
}

/// One entry per day that has a weight, oldest first. Days without a weight are absent.
public struct ListWeightLogsResponse: Codable, Hashable, Sendable {
    public var items: [DailyWeight]
    public init(items: [DailyWeight]) { self.items = items }
}

/// Logs a weight of 10–1,000 pounds or 4.5–453.6 kilograms. Every measurement is kept; a day
/// shows the one with the latest `measuredAtUTC`.
public struct CreateWeightLogRequest: Hashable, Sendable {
    public var weight: Weight
    /// ISO-8601 date-time with any offset. Omitted means now.
    public var measuredAtUTC: String?
    public var user: PartnerUserContext
    public init(weight: Weight, measuredAtUTC: String? = nil, user: PartnerUserContext) {
        self.weight = weight; self.measuredAtUTC = measuredAtUTC; self.user = user
    }
}

/// Daily weights between `start` and `end` (inclusive `yyyy-MM-dd` dates in the user's timezone,
/// at most 5 years back). When more than 100 days have a weight, the most recent 100 are returned.
public struct ListWeightLogsRequest: Hashable, Sendable {
    public var start: String
    public var end: String
    public var user: PartnerUserContext
    public init(start: String, end: String, user: PartnerUserContext) { self.start = start; self.end = end; self.user = user }
}
