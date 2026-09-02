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
            let body = Components.Schemas.ScanFoodPhotoBody(image: request.image)
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
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
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
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
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
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
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
                        id: detection.food.id.map { FoodID(rawValue: $0) },
                        name: detection.food.name,
                        brandName: detection.food.brandName,
                        nutrients: try ModelBridge.convert(detection.food.nutrients),
                        servings: detection.food.servings.map { serving in
                            DetectedServing(
                                id: serving.id.map { ServingID(rawValue: $0) },
                                quantity: serving.quantity,
                                unit: serving.unit,
                                selectedQuantity: serving.selectedQuantity
                            )
                        }
                    ),
                    confidenceScore: detection.confidence.flatMap(ConfidenceScore.init(rawValue:))
                )
            }
        )
    }

    private func transport(_ value: FoodScan) throws -> Components.Schemas.FoodScan {
        .init(
            mealName: value.mealName,
            totalNutrients: try ModelBridge.convert(value.totalNutrients),
            detections: try value.detections.map { detection in
                .init(
                    confidence: detection.confidenceScore?.rawValue,
                    food: .init(
                        id: detection.food.id?.rawValue,
                        name: detection.food.name,
                        brandName: detection.food.brandName,
                        nutrients: try ModelBridge.convert(detection.food.nutrients),
                        servings: detection.food.servings.orEmpty.map { serving in
                            .init(
                                id: serving.id?.rawValue,
                                quantity: serving.quantity,
                                unit: serving.unit,
                                selectedQuantity: serving.selectedQuantity
                            )
                        }
                    )
                )
            }
        )
    }
}

private extension Optional where Wrapped == [DetectedServing] {
    var orEmpty: [DetectedServing] { self ?? [] }
}
