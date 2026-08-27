import Foundation

public enum Sex: String, Codable, Hashable, Sendable, CaseIterable { case male, female }
@available(*, deprecated, renamed: "Sex")
public typealias Gender = Sex

public enum HeightUnit: String, Codable, Hashable, Sendable, CaseIterable {
    case inches = "in"
    case centimeters = "cm"
}

public struct Height: Codable, Hashable, Sendable {
    public var value: Double
    public var unit: HeightUnit
    public init(value: Double, unit: HeightUnit) { self.value = value; self.unit = unit }
}

public enum WeightUnit: String, Codable, Hashable, Sendable, CaseIterable {
    case pounds = "lb"
    case kilograms = "kg"
}

public struct Weight: Codable, Hashable, Sendable {
    public var value: Double
    public var unit: WeightUnit
    public init(value: Double, unit: WeightUnit) { self.value = value; self.unit = unit }
}
public enum ActivityLevel: String, Codable, Hashable, Sendable {
    case sedentary; case lightlyActive = "lightly_active"; case moderatelyActive = "moderately_active"; case veryActive = "very_active"
}
public enum MedicalCondition: String, Codable, Hashable, Sendable {
    case type2Diabetes = "type_2_diabetes"; case prediabetes
    @available(*, deprecated, message: "Omit healthConditions or pass an empty array when none apply.")
    case noneOfTheAbove = "none_of_the_above"
}

public struct GlucosePredictionProfile: Codable, Hashable, Sendable {
    public var age: Double; public var sex: Sex; public var height: Height; public var weight: Weight
    public var activityLevel: ActivityLevel?; public var healthConditions: [MedicalCondition]?
    public init(age: Double, sex: Sex, height: Height, weight: Weight, activityLevel: ActivityLevel? = nil, healthConditions: [MedicalCondition]? = nil) {
        self.age = age; self.sex = sex; self.height = height; self.weight = weight
        self.activityLevel = activityLevel; self.healthConditions = healthConditions
    }
    public init(age: Double, gender: Sex, height: Double, weight: Double, activityLevel: ActivityLevel? = nil, healthConditions: [MedicalCondition]? = nil) {
        self.init(
            age: age,
            sex: gender,
            height: Height(value: height, unit: .inches),
            weight: Weight(value: weight, unit: .pounds),
            activityLevel: activityLevel,
            healthConditions: healthConditions?.filter { $0 != .noneOfTheAbove }
        )
    }
    public var gender: Sex { sex }
    enum CodingKeys: String, CodingKey { case age, sex, height, weight; case activityLevel = "activity_level"; case healthConditions = "health_conditions" }
}

public struct CgmReading: Codable, Hashable, Sendable {
    public var timestamp: String; public var value: Double
    public init(timestamp: String, value: Double) { self.timestamp = timestamp; self.value = value }
}

public struct ConsumedHistoricalServing: Codable, Hashable, Sendable {
    public var id: ServingID; public var quantity: Double
    public init(id: ServingID, quantity: Double) { self.id = id; self.quantity = quantity }
}

public struct ConsumedHistoricalFood: Codable, Hashable, Sendable {
    public var timestamp: String; public var id: FoodID; public var serving: ConsumedHistoricalServing
    public init(timestamp: String, id: FoodID, serving: ConsumedHistoricalServing) { self.timestamp = timestamp; self.id = id; self.serving = serving }
}

public struct PredictGlucoseRequest: Hashable, Sendable {
    public var userProfile: GlucosePredictionProfile; public var foods: [FoodSelection]; public var startTime: Date
    public var cgmData: [CgmReading]?; public var consumedFoods: [ConsumedHistoricalFood]?
    public var endUserID: PartnerUserID?; public var timezone: String?
    public init(userProfile: GlucosePredictionProfile, foods: [FoodSelection], startTime: Date, cgmData: [CgmReading]? = nil, consumedFoods: [ConsumedHistoricalFood]? = nil, endUserID: PartnerUserID? = nil, timezone: String? = nil) {
        self.userProfile = userProfile; self.foods = foods; self.startTime = startTime; self.cgmData = cgmData
        self.consumedFoods = consumedFoods; self.endUserID = endUserID; self.timezone = timezone
    }
}

public struct GlucoseImpact: RawRepresentable, Codable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let lowImpact = Self(rawValue: "low")
    public static let mediumImpact = Self(rawValue: "medium")
    public static let highImpact = Self(rawValue: "high")
    public init(from decoder: Decoder) throws {
        self.init(rawValue: try decoder.singleValueContainer().decode(String.self))
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct GlucoseChart: Codable, Hashable, Sendable {
    public var min: Double
    public var max: Double
    public init(min: Double, max: Double) { self.min = min; self.max = max }
}

public struct GlucosePrediction: Codable, Hashable, Sendable {
    public var prediction: [GlucosePredictionPoint]
    public var impact: GlucoseImpact
    public var chart: GlucoseChart
    public init(prediction: [GlucosePredictionPoint], impact: GlucoseImpact, chart: GlucoseChart) {
        self.prediction = prediction; self.impact = impact; self.chart = chart
    }
    public init(curve: [[Double]], scoring: GlucoseImpact, minimum: Double, maximum: Double) {
        self.prediction = curve.compactMap { point in
            guard point.count == 2 else { return nil }
            return GlucosePredictionPoint(minutes: point[0], value: point[1])
        }
        self.impact = scoring
        self.chart = GlucoseChart(min: minimum, max: maximum)
    }
    public var curve: [[Double]] { prediction.map { [$0.minutes, $0.value] } }
    public var scoring: GlucoseImpact { impact }
    public var minimum: Double { chart.min }
    public var maximum: Double { chart.max }
    enum CodingKeys: String, CodingKey { case prediction, chart; case impact = "impact_score" }
}
