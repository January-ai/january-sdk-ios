import JanuaryPartnerTransport

/// Operations that analyze food from photos or natural-language descriptions.
public struct FoodAnalysisResource: Sendable {
    private let client: Client
    private let userContext: PartnerUserContext?
    internal init(client: Client, userContext: PartnerUserContext? = nil) {
        self.client = client
        self.userContext = userContext
    }

    public func analyzePhoto(_ request: ScanFoodPhotoRequest) async throws -> FoodScan {
        try await performTransportRequest {
            let body = Components.Schemas.ScanFoodPhotoBody(
                image: request.image,
                reasoning: request.reasoningEffort.map { effort in
                    .init(effort: effort == .xhigh ? .xhigh : .none)
                }
            )
            let output = try await client.scanFoodPhoto(
                .init(body: .json(body))
            )
            switch output {
            case .ok(let response): return try map(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .contentTooLarge(let response): throw apiError(.validation, status: 413, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .gatewayTimeout(let response): throw apiError(.timeout, status: 504, response: try response.body.json)
            case .default(let status, let response): throw apiError(errorCategory(for: status), status: status, response: try? response.body.json)
            }
        }
    }

    /// Parses a natural-language meal description into detected foods and nutrition.
    public func analyzeDescription(
        _ request: SearchFoodsByNaturalLanguageRequest
    ) async throws -> FoodScan {
        guard !request.query.isEmpty, request.query.count <= 512 else {
            throw JanuaryError(
                category: .validation,
                message: "Meal description must contain between 1 and 512 characters."
            )
        }

        return try await performTransportRequest {
            let output = try await client.searchFoodsByNaturalLanguage(
                .init(
                    body: .json(.init(text: request.query))
                )
            )
            switch output {
            case .ok(let response): return try map(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, let response): throw apiError(errorCategory(for: status), status: status, response: try? response.body.json)
            }
        }
    }

    public func correct(_ request: CorrectPhotoScanRequest) async throws -> FoodScan {
        try await performTransportRequest {
            let body = Components.Schemas.CorrectPhotoScanBody(
                analysis: try transport(request.analysis),
                instruction: request.instruction
            )
            let output = try await client.correctPhotoScan(
                .init(body: .json(body))
            )
            switch output {
            case .ok(let response): return try map(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .forbidden(let response): throw apiError(.authorization, status: 403, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .gatewayTimeout(let response): throw apiError(.timeout, status: 504, response: try response.body.json)
            case .default(let status, let response): throw apiError(errorCategory(for: status), status: status, response: try? response.body.json)
            }
        }
    }

    private func map(_ value: Components.Schemas.FoodScan) throws -> FoodScan {
        FoodScan(
            mealName: value.mealName,
            totalNutrients: try ModelBridge.convert(value.totalNutrients),
            detections: try value.detections.map { detection in
                FoodDetection(
                    food: DetectedFood(
                        id: FoodID(rawValue: detection.food.id),
                        name: detection.food.name,
                        brandName: detection.food.brandName,
                        nutrients: try ModelBridge.convert(detection.food.nutrients),
                        serving: ServingSummary(
                            id: ServingID(rawValue: detection.food.serving.id),
                            quantity: detection.food.serving.quantity,
                            unit: detection.food.serving.unit,
                            weightGrams: detection.food.serving.weightGrams
                        ),
                        quantity: detection.food.quantity
                    ),
                    confidenceScore: detection.confidence.flatMap(ConfidenceScore.init(rawValue:))
                )
            }
        )
    }

    /// A correction sends the prior scan back field for field. The API requires
    /// every detection's food id, serving id, and quantity; a scan returned by
    /// the API always has them, so a missing value is a caller-built detection.
    private func transport(_ value: FoodScan) throws -> Components.Schemas.CorrectionAnalysis {
        .init(
            mealName: value.mealName,
            totalNutrients: try ModelBridge.convert(value.totalNutrients),
            detections: try value.detections.map { detection in
                guard let foodID = detection.food.id else {
                    throw correctionValidationError("food.id")
                }
                guard let servingID = detection.food.serving.id else {
                    throw correctionValidationError("food.serving.id")
                }
                guard let servingQuantity = detection.food.serving.quantity else {
                    throw correctionValidationError("food.serving.quantity")
                }
                guard let quantity = detection.food.quantity else {
                    throw correctionValidationError("food.quantity")
                }
                return .init(
                    confidence: detection.confidenceScore?.rawValue,
                    food: .init(
                        name: detection.food.name,
                        brandName: detection.food.brandName,
                        id: foodID.rawValue,
                        quantity: quantity,
                        nutrients: try ModelBridge.convert(detection.food.nutrients),
                        serving: .init(
                            id: servingID.rawValue,
                            quantity: servingQuantity,
                            unit: detection.food.serving.unit,
                            weightGrams: detection.food.serving.weightGrams
                        )
                    )
                )
            }
        )
    }

    private func correctionValidationError(_ field: String) -> JanuaryError {
        JanuaryError(
            category: .validation,
            message: "Every detection sent for correction needs \(field); pass the analysis exactly as the API returned it."
        )
    }
}
