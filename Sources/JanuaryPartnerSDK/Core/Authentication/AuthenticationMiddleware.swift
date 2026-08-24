import Foundation
import HTTPTypes
import OpenAPIRuntime

enum AuthenticationSource: Sendable {
    case developmentAPIKey(String)
    case clientToken(ClientTokenManager)
}

struct AuthenticationMiddleware: ClientMiddleware {
    let source: AuthenticationSource
    let userAgent: String

    init(source: AuthenticationSource, userAgent: String) {
        self.source = source
        self.userAgent = userAgent
    }

    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?) {
        switch source {
        case .developmentAPIKey(let apiKey):
            return try await next(
                authenticatedRequest(request, bearerToken: apiKey),
                body,
                baseURL
            )
        case .clientToken(let manager):
            let token = try await manager.token()
            let authenticated = authenticatedRequest(request, bearerToken: token.value)
            let firstResponse = try await next(authenticated, body, baseURL)

            guard
                firstResponse.0.status == .unauthorized,
                isInvalidTokenChallenge(firstResponse.0),
                isReplayable(body)
            else {
                return firstResponse
            }

            await manager.invalidate(ifMatching: token.value)
            let refreshedToken = try await manager.token()
            return try await next(
                authenticatedRequest(request, bearerToken: refreshedToken.value),
                body,
                baseURL
            )
        }
    }

    private func authenticatedRequest(_ original: HTTPRequest, bearerToken: String) -> HTTPRequest {
        var request = original
        request.headerFields[.authorization] = "Bearer \(bearerToken)"
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
        return request
    }

    private func isInvalidTokenChallenge(_ response: HTTPResponse) -> Bool {
        guard let challenge = response.headerFields[.wwwAuthenticate]?.lowercased() else {
            return false
        }
        return challenge.contains("error=\"invalid_token\"") || challenge.contains("error=invalid_token")
    }

    private func isReplayable(_ body: HTTPBody?) -> Bool {
        guard let body else { return true }
        switch body.iterationBehavior {
        case .multiple: return true
        case .single: return false
        }
    }
}
