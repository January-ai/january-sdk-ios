import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
@testable import JanuaryPartnerSDK

private let burgerImageURL = "https://friendlysrestaurants.com/assets/live/img/production/detail/menu/lunch-dinner_999-combohs_all-american-burger-fries.jpg"

private actor PhotoFixtureTransport: ClientTransport {
    private var capturedImages: [String] = []

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        #expect(operationID == "scanFoodPhoto")
        #expect(request.path == "/v1.2/food-scans/photo")
        let requestBody = try #require(body)
        let data = try await Data(collecting: requestBody, upTo: 3_000_000)
        let payload = try JSONDecoder().decode(ScanPayload.self, from: data)
        capturedImages.append(payload.image)

        var response = HTTPResponse(status: .ok)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(#"{"meal_name":"Burger and fries","detections":[]}"#))
    }

    func images() -> [String] { capturedImages }
}

private struct ScanPayload: Decodable { let image: String }

@Test
func photoScanSendsPublicURLAndPNGDataURIThroughPublicClient() async throws {
    let fixtureURL = try #require(
        Bundle.module.url(
            forResource: "burger-and-fries",
            withExtension: "png",
            subdirectory: "Fixtures/PhotoScanning"
        )
    )
    let fixture = try Data(contentsOf: fixtureURL)
    let dataURI = "data:image/png;base64,\(fixture.base64EncodedString())"
    let transport = PhotoFixtureTransport()
    let client = try JanuaryPartnerClient(
        developmentAPIKey: "fixture-api-key",
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport
    )

    _ = try await client.photoScanning.scan(.init(image: burgerImageURL))
    _ = try await client.photoScanning.scan(.init(image: dataURI))

    let images = await transport.images()
    #expect(images.count == 2)
    #expect(images[0] == burgerImageURL)
    let encodedPNG = try #require(images[1].split(separator: ",", maxSplits: 1).last)
    #expect(images[1].hasPrefix("data:image/png;base64,"))
    #expect(Data(base64Encoded: String(encodedPNG)) == fixture)
}
