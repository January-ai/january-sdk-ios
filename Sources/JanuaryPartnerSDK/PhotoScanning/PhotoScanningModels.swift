import Foundation

public struct ScanFoodPhotoRequest: Hashable, Sendable {
    public var image: String
    public var endUserID: PartnerUserID?
    public init(image: String, endUserID: PartnerUserID? = nil) { self.image = image; self.endUserID = endUserID }
}

public struct FoodDetection: Codable, Hashable, Sendable {
    public var food: DetectedFood
    public var confidenceScore: String?
    public init(food: DetectedFood, confidenceScore: String? = nil) { self.food = food; self.confidenceScore = confidenceScore }
    enum CodingKeys: String, CodingKey { case food; case confidenceScore = "confidence_score" }
}

public struct GlucosePredictionPoint: Codable, Hashable, Sendable {
    public var minutes: Double
    public var value: Double
    public init(minutes: Double, value: Double) { self.minutes = minutes; self.value = value }
}

public struct PhotoScanGlucoseImpact: Codable, Hashable, Sendable {
    public var impactScore: String
    public var prediction: [GlucosePredictionPoint]
    public init(impactScore: String, prediction: [GlucosePredictionPoint]) { self.impactScore = impactScore; self.prediction = prediction }
    enum CodingKeys: String, CodingKey { case prediction; case impactScore = "impact_score" }
}

public struct PhotoScan: Codable, Hashable, Sendable {
    public var mealName: String?
    public var totalNutrients: CompleteScanNutritionFacts?
    public var detections: [FoodDetection]?
    public var glucoseImpact: PhotoScanGlucoseImpact?
    public init(mealName: String? = nil, totalNutrients: CompleteScanNutritionFacts? = nil, detections: [FoodDetection]? = nil, glucoseImpact: PhotoScanGlucoseImpact? = nil) {
        self.mealName = mealName; self.totalNutrients = totalNutrients; self.detections = detections; self.glucoseImpact = glucoseImpact
    }
    enum CodingKeys: String, CodingKey { case detections; case mealName = "meal_name"; case totalNutrients = "total_nutrients"; case glucoseImpact = "glucose_impact" }
}

public struct CorrectPhotoScanRequest: Hashable, Sendable {
    public var mealName: String
    public var detections: [FoodDetection]
    public var userInput: String
    public var endUserID: PartnerUserID?
    public init(mealName: String, detections: [FoodDetection], userInput: String, endUserID: PartnerUserID? = nil) {
        self.mealName = mealName; self.detections = detections; self.userInput = userInput; self.endUserID = endUserID
    }
}

