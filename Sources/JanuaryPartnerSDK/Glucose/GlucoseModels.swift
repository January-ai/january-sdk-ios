import Foundation

public enum Gender: String, Codable, Hashable, Sendable { case male, female }
public enum ActivityLevel: String, Codable, Hashable, Sendable {
    case sedentary; case lightlyActive = "lightly_active"; case moderatelyActive = "moderately_active"; case veryActive = "very_active"
}
public enum MedicalCondition: String, Codable, Hashable, Sendable {
    case type2Diabetes = "Type 2 diabetes"; case prediabetes = "Prediabetes"; case noneOfTheAbove = "None of the above"
}

public struct GlucosePredictionProfile: Codable, Hashable, Sendable {
    public var age: Double; public var gender: Gender; public var height: Double; public var weight: Double
    public var activityLevel: ActivityLevel?; public var healthConditions: [MedicalCondition]?
    public init(age: Double, gender: Gender, height: Double, weight: Double, activityLevel: ActivityLevel? = nil, healthConditions: [MedicalCondition]? = nil) {
        self.age = age; self.gender = gender; self.height = height; self.weight = weight
        self.activityLevel = activityLevel; self.healthConditions = healthConditions
    }
    enum CodingKeys: String, CodingKey { case age, gender, height, weight; case activityLevel = "activity_level"; case healthConditions = "health_conditions" }
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

public enum GlucoseImpact: String, Codable, Hashable, Sendable { case lowImpact = "low_impact"; case mediumImpact = "medium_impact"; case highImpact = "high_impact" }

public struct GlucosePrediction: Codable, Hashable, Sendable {
    public var curve: [[Double]]; public var scoring: GlucoseImpact; public var minimum: Double; public var maximum: Double
    public init(curve: [[Double]], scoring: GlucoseImpact, minimum: Double, maximum: Double) {
        self.curve = curve; self.scoring = scoring; self.minimum = minimum; self.maximum = maximum
    }
    enum CodingKeys: String, CodingKey { case scoring; case curve = "cgp"; case minimum = "cgp_min"; case maximum = "cgp_max" }
}

