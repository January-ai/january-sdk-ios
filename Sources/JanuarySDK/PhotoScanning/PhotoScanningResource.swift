import JanuaryPartnerTransport

public struct PhotoScanningResource: Sendable {
    private let client: Client
    internal init(client: Client) { self.client = client }

    public func scan(_ request: ScanFoodPhotoRequest) async throws -> FoodScan {
        try await performTransportRequest {
            let body = Components.Schemas.ScanFoodPhotoBody(image: request.image)
            let output = try await client.scanFoodPhoto(
                .init(headers: .init(xEndUserId: request.endUserID?.rawValue), body: .json(body))
            )
            switch output {
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .contentTooLarge(let response): throw apiError(.validation, status: 413, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .gatewayTimeout(let response): throw apiError(.timeout, status: 504, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    /// Parses a natural-language meal description into detected foods and nutrition.
    public func searchByNaturalLanguage(
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
                    headers: .init(xEndUserId: request.endUserID?.rawValue),
                    body: .json(.init(text: request.query))
                )
            )
            switch output {
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    public func correct(_ request: CorrectPhotoScanRequest) async throws -> FoodScan {
        try await performTransportRequest {
            let body: Components.Schemas.CorrectPhotoScanBody = try ModelBridge.convert(
                CorrectBody(mealName: request.mealName, detections: request.detections, userInput: request.userInput)
            )
            let output = try await client.correctPhotoScan(
                .init(headers: .init(xEndUserId: request.endUserID?.rawValue), body: .json(body))
            )
            switch output {
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, response: try response.body.json)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, response: try response.body.json)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, response: try response.body.json)
            case .gatewayTimeout(let response): throw apiError(.timeout, status: 504, response: try response.body.json)
            case .default(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }
}

private struct CorrectBody: Codable {
    let mealName: String?; let detections: [FoodDetection]; let userInput: String
    enum CodingKeys: String, CodingKey { case detections; case mealName = "meal_name"; case userInput = "user_input" }
}
