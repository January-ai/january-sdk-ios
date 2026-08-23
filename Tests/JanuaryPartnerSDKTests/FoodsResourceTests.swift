import Foundation
import HTTPTypes
import OpenAPIRuntime
import Testing
@testable import JanuaryPartnerSDK

private struct CapturedRequest: Sendable {
    let operationID: String
    let path: String
    let authorization: String?
    let endUserID: String?
    let userAgent: String?
}

private actor FixtureTransport: ClientTransport {
    private let status: HTTPResponse.Status
    private let responseData: Data
    private var capturedRequests: [CapturedRequest] = []

    init(status: HTTPResponse.Status = .ok, responseData: Data) {
        self.status = status
        self.responseData = responseData
    }

    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        let endUserName = HTTPField.Name("x-end-user-id")!
        capturedRequests.append(
            CapturedRequest(
                operationID: operationID,
                path: request.path ?? "",
                authorization: request.headerFields[.authorization],
                endUserID: request.headerFields[endUserName],
                userAgent: request.headerFields[.userAgent]
            )
        )
        var response = HTTPResponse(status: status)
        response.headerFields[.contentType] = "application/json"
        return (response, HTTPBody(responseData))
    }

    func requests() -> [CapturedRequest] {
        capturedRequests
    }
}

private func fixture(_ relativePath: String) throws -> Data {
    let parts = relativePath.split(separator: "/", maxSplits: 1).map(String.init)
    let subdirectory = parts.count == 2 ? "Fixtures/\(parts[0])" : "Fixtures"
    let filename = parts.last ?? relativePath
    let name = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
    let fileExtension = URL(fileURLWithPath: filename).pathExtension
    let url = try #require(
        Bundle.module.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: subdirectory
        )
    )
    return try Data(contentsOf: url)
}

@Test
func foodSearchUsesAsyncTransportAndMapsPublicModels() async throws {
    let transport = FixtureTransport(
        responseData: try fixture("Foods/search-foods-response.json")
    )
    let client = try JanuaryPartnerClient(
        developmentAPIKey: "fixture-api-key",
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport
    )

    let result = try await client.foods.search(
        SearchFoodsRequest(
            query: "banana",
            category: .branded,
            limit: 10,
            endUserID: PartnerUserID(rawValue: "test-user-123")
        )
    )

    #expect(result.totalCount == 1)
    #expect(result.items.count == 1)
    #expect(result.items[0].id == FoodID(rawValue: 84_222_716))
    #expect(result.items[0].name == "Banana")
    #expect(result.items[0].calories == 160)
    #expect(result.items[0].carbohydrates == 15)
    #expect(result.items[0].servings[0].id == ServingID(rawValue: 67_943_292))

    let request = try #require(await transport.requests().first)
    #expect(request.operationID == "searchFoods")
    #expect(request.authorization == "Bearer fixture-api-key")
    #expect(request.endUserID == "test-user-123")
    #expect(request.userAgent?.hasPrefix("JanuaryPartnerSDK/0.1.0 ") == true)
    #expect(request.userAgent?.contains("Swift/6") == true)
    #expect(request.userAgent?.contains("Platform/") == true)
    #expect(request.userAgent?.contains("OS/") == true)
    #expect(request.userAgent?.contains("Device/") == true)
    let components = try #require(URLComponents(string: "https://example.invalid\(request.path)"))
    let query = Dictionary(
        uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value) }
    )
    #expect(components.path == "/v1.2/foods/search")
    #expect(query["query"] == "banana")
    #expect(query["category"] == "branded")
    #expect(query["limit"] == "10.0")
}

@Test
func foodSearchMapsAuthenticationErrors() async throws {
    let transport = FixtureTransport(
        status: .unauthorized,
        responseData: try fixture("Foods/missing-end-user.json")
    )
    let client = try JanuaryPartnerClient(
        developmentAPIKey: "fixture-api-key",
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport
    )

    do {
        _ = try await client.foods.search(SearchFoodsRequest(query: "banana"))
        Issue.record("Expected authentication error")
    } catch let error as JanuaryError {
        #expect(error.category == .authentication)
        #expect(error.code == "unauthorized")
        #expect(error.httpStatus == 401)
        #expect(!error.message.isEmpty)
    }
}

@Test
func foodSearchValidatesInputsBeforeTransport() async throws {
    let transport = FixtureTransport(responseData: Data())
    let client = try JanuaryPartnerClient(
        developmentAPIKey: "fixture-api-key",
        serverURL: URL(string: "https://example.invalid")!,
        transport: transport
    )

    do {
        _ = try await client.foods.search(SearchFoodsRequest(query: "", limit: 41))
        Issue.record("Expected validation error")
    } catch let error as JanuaryError {
        #expect(error.category == .validation)
        #expect(error.httpStatus == nil)
    }
    #expect(await transport.requests().isEmpty)
}

@Test
func publicConcurrencyTypesAreSendable() {
    func requireSendable<T: Sendable>(_: T.Type) {}
    requireSendable(JanuaryPartnerClient.self)
    requireSendable(FoodsResource.self)
    requireSendable(FoodSearchResults.self)
    requireSendable(JanuaryError.self)
}
