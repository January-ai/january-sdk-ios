import Foundation
import JanuaryPartnerTransport
import Testing
@_spi(JanuaryDevelopment) @testable import January
private struct MenuByIDTransport: ClientTransport {
    func send(_ request: HTTPRequest, body: HTTPBody?, baseURL: URL, operationID: String) async throws -> (HTTPResponse, HTTPBody?) {
        #expect(operationID == "getRestaurantMenuItems")
        #expect(request.path == "/v1.2/restaurants/cafe-123/menu-items?limit=2&offset=1")
        var response = HTTPResponse(status: .ok)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(#"{"total_count":3,"items":[{"type":"menu_item","id":"101","name":"Bowl","restaurant_name":"Cafe","nutrients":{"calories":{"value":220,"unit":"kcal"}},"image_url":"https://example.com/bowl.jpg","servings":[{"id":11,"quantity":1,"unit":"bowl","is_primary":true}]}]}"#))
    }
}
@Test func restaurantMenuLoadsByIDWithoutTextSearch() async throws {
    let client = try JanuaryClient(developmentAPIKey: "fixture-key", serverURL: URL(string: "https://example.invalid")!, transport: MenuByIDTransport())
    let result = try await client.restaurants.getMenuItems(.init(restaurantID: "cafe-123", limit: 2, offset: 1))
    #expect(result.totalCount == 3)
    #expect(result.items.first?.calories == 220)
    #expect(result.items.first?.servings.first?.scalingFactor == 1)
}
