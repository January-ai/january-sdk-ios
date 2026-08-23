import JanuaryPartnerTransport

public struct PhotoScanningResource: Sendable {
    private let client: Client
    internal init(client: Client) { self.client = client }

    public func scan(_ request: ScanFoodPhotoRequest) async throws -> PhotoScan {
        try await performTransportRequest {
            let body = Components.Schemas.ScanFoodPhotoBody(image: request.image)
            let output = try await client.scanFoodPhoto(
                .init(headers: .init(xEndUserId: request.endUserID?.rawValue), body: .json(body))
            )
            switch output {
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, message: try response.body.json.message)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, message: try response.body.json.message)
            case .contentTooLarge(let response): throw apiError(.validation, status: 413, message: try response.body.json.message)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, message: try response.body.json.message)
            case .gatewayTimeout(let response): throw apiError(.timeout, status: 504, message: try response.body.json.message)
            case .undocumented(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }

    public func correct(_ request: CorrectPhotoScanRequest) async throws -> PhotoScan {
        try await performTransportRequest {
            let body: Components.Schemas.CorrectPhotoScanBody = try ModelBridge.convert(
                CorrectBody(mealName: request.mealName, detections: request.detections, userInput: request.userInput)
            )
            let output = try await client.correctPhotoScan(
                .init(headers: .init(xEndUserId: request.endUserID?.rawValue), body: .json(body))
            )
            switch output {
            case .ok(let response): return try ModelBridge.convert(try response.body.json)
            case .badRequest(let response): throw apiError(.validation, status: 400, message: try response.body.json.message)
            case .unauthorized(let response): throw apiError(.authentication, status: 401, message: try response.body.json.message)
            case .tooManyRequests(let response): throw apiError(.rateLimited, status: 429, message: try response.body.json.message)
            case .gatewayTimeout(let response): throw apiError(.timeout, status: 504, message: try response.body.json.message)
            case .undocumented(let status, _): throw apiError(errorCategory(for: status), status: status)
            }
        }
    }
}

private struct CorrectBody: Codable {
    let mealName: String; let detections: [FoodDetection]; let userInput: String
    enum CodingKeys: String, CodingKey { case detections; case mealName = "meal_name"; case userInput = "user_input" }
}

