import Foundation

/// Backward-compatible name for the user context required by Food Logs.
public typealias FoodLogUserContext = PartnerUserContext

public struct CreateFoodLogRequest: Hashable, Sendable {
    public var foods: [FoodSelection]
    public var timestampUTC: String?
    public var name: String?
    public var user: FoodLogUserContext
    public init(foods: [FoodSelection], timestampUTC: String? = nil, name: String? = nil, user: FoodLogUserContext) {
        self.foods = foods; self.timestampUTC = timestampUTC; self.name = name; self.user = user
    }
}

public struct UpdateFoodLogRequest: Hashable, Sendable {
    public var id: String
    public var foods: [FoodSelection]?
    public var timestampUTC: String?
    public var name: String?
    public var user: FoodLogUserContext
    public init(id: String, foods: [FoodSelection]? = nil, timestampUTC: String? = nil, name: String? = nil, user: FoodLogUserContext) {
        self.id = id; self.foods = foods; self.timestampUTC = timestampUTC; self.name = name; self.user = user
    }
}

public struct ListFoodLogsRequest: Hashable, Sendable {
    public var start: String; public var end: String; public var user: FoodLogUserContext
    public init(start: String, end: String, user: FoodLogUserContext) { self.start = start; self.end = end; self.user = user }
}

public struct GetFoodLogRequest: Hashable, Sendable {
    public var id: String; public var user: FoodLogUserContext
    public init(id: String, user: FoodLogUserContext) { self.id = id; self.user = user }
}

/// Bucket size for a food-log summary.
public enum FoodLogSummaryGrouping: String, Codable, Hashable, Sendable, CaseIterable { case day, week }

/// Which weekday a week bucket begins on. Ignored when grouping by day.
public enum WeekStart: String, Codable, Hashable, Sendable, CaseIterable { case monday, sunday }

/// Summarizes the logs between `start` and `end` (inclusive calendar dates in the user's timezone,
/// at most 366 days) into day or week buckets with summed nutrients.
public struct GetFoodLogSummaryRequest: Hashable, Sendable {
    public var start: String
    public var end: String
    public var groupBy: FoodLogSummaryGrouping
    public var weekStart: WeekStart
    public var user: FoodLogUserContext
    public init(
        start: String,
        end: String,
        groupBy: FoodLogSummaryGrouping = .day,
        weekStart: WeekStart = .monday,
        user: FoodLogUserContext
    ) {
        self.start = start; self.end = end; self.groupBy = groupBy; self.weekStart = weekStart; self.user = user
    }
}

public struct DeleteFoodLogRequest: Hashable, Sendable {
    public var id: String; public var user: FoodLogUserContext
    public init(id: String, user: FoodLogUserContext) { self.id = id; self.user = user }
}

public struct ConsumedServing: Codable, Hashable, Sendable {
    public var id: ServingID?; public var quantity: Double?
    public init(id: ServingID?, quantity: Double?) { self.id = id; self.quantity = quantity }
}

public struct ServingDetails: Codable, Hashable, Sendable {
    public var id: ServingID?; public var quantity: Double?; public var unit: String?; public var weightGrams: Double?
    public init(id: ServingID?, quantity: Double?, unit: String?, weightGrams: Double? = nil) {
        self.id = id; self.quantity = quantity; self.unit = unit; self.weightGrams = weightGrams
    }
    enum CodingKeys: String, CodingKey { case id, quantity, unit; case weightGrams = "weight_grams" }
}

public struct LoggedFood: Codable, Hashable, Sendable {
    public var id: FoodID; public var name: String?; public var brandName: String?; public var imageURL: String?
    public var glycemicIndex: Double?; public var glycemicLoad: Double?; public var nutrients: NutritionFacts
    public var consumedServing: ConsumedServing; public var servingDetails: ServingDetails
    enum CodingKeys: String, CodingKey {
        case id, name, nutrients; case brandName = "brand_name"; case imageURL = "image_url"
        case glycemicIndex = "glycemic_index"; case glycemicLoad = "glycemic_load"
        case consumedServing = "consumed_serving"; case servingDetails = "serving_details"
    }
}

public struct FoodLog: Codable, Hashable, Sendable {
    public var id: String?; public var foods: [LoggedFood]; public var timestampUTC: String; public var name: String?
    public init(id: String?, foods: [LoggedFood], timestampUTC: String, name: String? = nil) {
        self.id = id; self.foods = foods; self.timestampUTC = timestampUTC; self.name = name
    }
    enum CodingKeys: String, CodingKey { case id, foods, name; case timestampUTC = "timestamp_utc" }
}

public struct ListFoodLogsResponse: Codable, Hashable, Sendable {
    public var totalCount: Int; public var items: [FoodLog]
    public init(totalCount: Int, items: [FoodLog]) { self.totalCount = totalCount; self.items = items }
    enum CodingKeys: String, CodingKey { case items; case totalCount = "total_count" }
}

public typealias DeleteFoodLogResponse = Void

/// One day or week of a food-log summary. Buckets tile the requested range, so an empty period is present with zero counts.
public struct FoodLogSummaryBucket: Codable, Hashable, Sendable {
    public var startDate: String
    public var endDate: String
    public var logsCount: Int
    public var daysWithLogs: Int
    /// Nutrients summed over the bucket. Sparse: a key is absent when nothing could be totalled.
    public var nutrients: NutritionFacts
    public init(startDate: String, endDate: String, logsCount: Int, daysWithLogs: Int, nutrients: NutritionFacts) {
        self.startDate = startDate; self.endDate = endDate; self.logsCount = logsCount
        self.daysWithLogs = daysWithLogs; self.nutrients = nutrients
    }
    enum CodingKeys: String, CodingKey {
        case nutrients; case startDate = "start_date"; case endDate = "end_date"
        case logsCount = "logs_count"; case daysWithLogs = "days_with_logs"
    }
}

public struct FoodLogSummaryTotals: Codable, Hashable, Sendable {
    public var logsCount: Int
    public var daysWithLogs: Int
    public var nutrients: NutritionFacts
    public init(logsCount: Int, daysWithLogs: Int, nutrients: NutritionFacts) {
        self.logsCount = logsCount; self.daysWithLogs = daysWithLogs; self.nutrients = nutrients
    }
    enum CodingKeys: String, CodingKey { case nutrients; case logsCount = "logs_count"; case daysWithLogs = "days_with_logs" }
}

/// Totals divided by the number of days that have at least one log.
public struct FoodLogSummaryAverage: Codable, Hashable, Sendable {
    public var nutrients: NutritionFacts
    public init(nutrients: NutritionFacts) { self.nutrients = nutrients }
}

public struct FoodLogSummary: Codable, Hashable, Sendable {
    public var groupBy: FoodLogSummaryGrouping
    /// `nil` when grouped by day.
    public var weekStart: WeekStart?
    public var timezone: String
    public var startDate: String
    public var endDate: String
    public var buckets: [FoodLogSummaryBucket]
    public var totals: FoodLogSummaryTotals
    public var averagePerLoggedDay: FoodLogSummaryAverage
    public init(
        groupBy: FoodLogSummaryGrouping,
        weekStart: WeekStart?,
        timezone: String,
        startDate: String,
        endDate: String,
        buckets: [FoodLogSummaryBucket],
        totals: FoodLogSummaryTotals,
        averagePerLoggedDay: FoodLogSummaryAverage
    ) {
        self.groupBy = groupBy; self.weekStart = weekStart; self.timezone = timezone
        self.startDate = startDate; self.endDate = endDate; self.buckets = buckets
        self.totals = totals; self.averagePerLoggedDay = averagePerLoggedDay
    }
    enum CodingKeys: String, CodingKey {
        case timezone, buckets, totals; case groupBy = "group_by"; case weekStart = "week_start"
        case startDate = "start_date"; case endDate = "end_date"; case averagePerLoggedDay = "average_per_logged_day"
    }
}
