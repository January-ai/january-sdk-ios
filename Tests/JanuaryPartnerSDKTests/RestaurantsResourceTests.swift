import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
@testable import JanuaryPartnerSDK

private struct RestaurantFixtureTransport: ClientTransport {
    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        #expect(operationID == "searchRestaurantMenuItems")
        var response = HTTPResponse(status: .ok)
        response.headerFields[.contentType] = "application/json"
        return (
            response,
            HTTPBody(
                #"{"total_count":1,"items":[{"type":"menu_item","id":"228990954","name":"burger","restaurant_name":"morning due cafe","servings":[{"id":189343592,"quantity":1,"unit":"serving","weight_grams":null,"is_primary":true}]}]}"#
            )
        )
    }
}

@Test
func menuServingDefaultsMissingScalingFactorToOne() async throws {
    let client = try JanuaryPartnerClient(
        developmentAPIKey: "fixture-api-key",
        serverURL: URL(string: "https://example.invalid")!,
        transport: RestaurantFixtureTransport()
    )

    let result = try await client.restaurants.searchMenuItems(
        .init(query: "burger", latitude: 37.7749, longitude: -122.4194)
    )

    #expect(result.items.first?.servings.first?.scalingFactor == 1.0)
}
