import Foundation
import January

/// Demo implementation of the provider a partner supplies to January.
///
/// The endpoint is either the partner's authenticated backend or its
/// self-hosted testing relay. It exchanges the server-side January credential
/// and returns `{ "token": "ct-…", "expiresIn": 1800 }`.
struct PartnerBackendTokenProvider: JanuaryTokenProvider {
    let endpoint: URL
    let appSessionToken: String
    var session: URLSession = .shared

    func fetchClientToken(for _: String) async throws -> JanuaryClientToken {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer " + appSessionToken, forHTTPHeaderField: "Authorization")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw JanuaryTokenProviderError(
                "The partner token endpoint is unavailable.",
                retryable: true
            )
        }
        guard let http = response as? HTTPURLResponse else {
            throw PartnerBackendTokenError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw JanuaryTokenProviderError(
                "The partner token endpoint rejected the request.",
                retryable: http.statusCode == 408 ||
                    http.statusCode == 429 ||
                    http.statusCode >= 500
            )
        }
        return try JSONDecoder().decode(JanuaryClientToken.self, from: data)
    }
}

private enum PartnerBackendTokenError: LocalizedError {
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The partner token endpoint returned an invalid response."
        }
    }
}
