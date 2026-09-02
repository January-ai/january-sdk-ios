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
                authenticatedRequest(
                    request,
                    bearerToken: apiKey,
                    omitEndUserID: true
                ),
                body,
                baseURL
            )
        case .fixedClientToken(let token):
            return try await next(
                authenticatedRequest(request, bearerToken: token, omitEndUserID: true),
                body,
                baseURL
            )
        case .clientToken(let manager):
            let token = try await manager.token()
            let authenticated = authenticatedRequest(
                request,
                bearerToken: token.token,
                omitEndUserID: true
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
                authenticatedRequest(
                    request,
                    bearerToken: refreshedToken.token,
                    omitEndUserID: true
                ),
                body,
                baseURL
            )
        }
    }

    private func authenticatedRequest(
        _ original: HTTPRequest,
        bearerToken: String,
        forcedEndUserID: PartnerUserID? = nil,
        omitEndUserID: Bool = false
    ) -> HTTPRequest {
        var request = original
        request.headerFields[.authorization] = "Bearer \(bearerToken)"
        request.headerFields[.userAgent] = userAgent

        if let forcedEndUserID, let name = HTTPField.Name("x-end-user-id") {
            request.headerFields[name] = forcedEndUserID.rawValue
        }

        if
            let name = HTTPField.Name("x-end-user-id"),
            request.headerFields[name]?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true
        {
            request.headerFields[name] = nil
        }

        if omitEndUserID, let name = HTTPField.Name("x-end-user-id") {
            request.headerFields[name] = nil
        }

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
