import Foundation
import JanuaryPartnerTransport

enum AuthenticationSource: Sendable {
    case developmentAPIKey(String, endUserID: PartnerUserID?)
    case fixedClientToken(String)
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
        case .developmentAPIKey(let apiKey, _):
            return try await next(
                authenticatedRequest(request, bearerToken: apiKey),
                body,
                baseURL
            )
        case .fixedClientToken(let token):
            return try await next(
                clientTokenRequest(request, bearerToken: token),
                body,
                baseURL
            )
        case .clientToken(let manager):
            let token = try await manager.token()
            let authenticated = clientTokenRequest(
                request,
                bearerToken: token.token
            )
            let firstResponse = try await next(authenticated, body, baseURL)

            guard
                firstResponse.0.status == .unauthorized,
                isReplayable(body),
                let responseBody = firstResponse.1
            else {
                return firstResponse
            }

            let responseBytes = try await [UInt8](collecting: responseBody, upTo: 64 * 1_024)
            let bufferedResponse = (firstResponse.0, HTTPBody(responseBytes))
            guard
                let error = try? JSONDecoder().decode(TokenErrorResponse.self, from: Data(responseBytes)),
                error.code == "token_expired"
            else {
                return bufferedResponse
            }

            await manager.invalidate(ifMatching: token.token)
            let refreshedToken = try await manager.token()
            return try await next(
                clientTokenRequest(
                    request,
                    bearerToken: refreshedToken.token
                ),
                body,
                baseURL
            )
        }
    }

    private func authenticatedRequest(
        _ original: HTTPRequest,
        bearerToken: String
    ) -> HTTPRequest {
        var request = original
        request.headerFields[.authorization] = "Bearer \(bearerToken)"
        request.headerFields[.userAgent] = userAgent

        if
            let name = HTTPField.Name("January-End-User-ID"),
            request.headerFields[name]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
        {
            request.headerFields[name] = nil
        }

        if let legacyName = HTTPField.Name("x-end-user-id") {
            request.headerFields[legacyName] = nil
        }

        for rawName in ["January-End-User-ID", "x-end-user-timezone"] {
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

    private func clientTokenRequest(
        _ original: HTTPRequest,
        bearerToken: String
    ) -> HTTPRequest {
        var request = authenticatedRequest(original, bearerToken: bearerToken)
        if let name = HTTPField.Name("January-End-User-ID") {
            request.headerFields[name] = nil
        }
        return request
    }

    private func isReplayable(_ body: HTTPBody?) -> Bool {
        guard let body else { return true }
        switch body.iterationBehavior {
        case .multiple: return true
        case .single: return false
        }
    }
}

private struct TokenErrorResponse: Decodable {
    let code: String
}
