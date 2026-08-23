import Foundation
import HTTPTypes
import OpenAPIRuntime

package struct DevelopmentAuthenticationMiddleware: ClientMiddleware {
    package let apiKey: String
    package let userAgent: String

    package init(apiKey: String, userAgent: String) {
        self.apiKey = apiKey
        self.userAgent = userAgent
    }

    package func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        var request = request
        request.headerFields[.authorization] = "Bearer \(apiKey)"
        request.headerFields[.userAgent] = userAgent

        for rawName in ["x-end-user-id", "x-end-user-timezone"] {
            if
                let name = HTTPField.Name(rawName),
                let encoded = request.headerFields[name],
                let decoded = encoded.removingPercentEncoding
            {
                request.headerFields[name] = decoded
            }
        }

        return try await next(request, body, baseURL)
    }
}
