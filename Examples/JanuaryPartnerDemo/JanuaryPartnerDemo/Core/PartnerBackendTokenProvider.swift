import Foundation
import JanuarySDK

/// Demo implementation of the provider a partner supplies to JanuarySDK.
///
/// The endpoint belongs to the partner, authenticates the signed-in app user,
/// exchanges the partner's server-side January credential, and returns
/// `{ "token": "ct-…", "expiresIn": 1800 }`.
struct PartnerBackendTokenProvider: JanuaryTokenProvider {
    let endpoint: URL
    let developmentEndUserID: String?
    let appSessionToken: String?
    var session: URLSession = .shared

    func fetchClientToken() async throws -> JanuaryClientToken {
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw PartnerBackendTokenError.invalidURL
        }
        if let developmentEndUserID {
            components.queryItems = (components.queryItems ?? []) + [
                URLQueryItem(name: "user", value: developmentEndUserID),
            ]
        }
        guard let requestURL = components.url else {
            throw PartnerBackendTokenError.invalidURL
        }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        if let appSessionToken, !appSessionToken.isEmpty {
            request.setValue("Bearer \(appSessionToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PartnerBackendTokenError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw PartnerBackendTokenError.rejected(status: http.statusCode)
        }
        return try JSONDecoder().decode(JanuaryClientToken.self, from: data)
    }
}

private enum PartnerBackendTokenError: LocalizedError {
    case invalidURL
    case invalidResponse
    case rejected(status: Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The partner token endpoint URL is invalid."
        case .invalidResponse:
            return "The partner token endpoint returned an invalid response."
        case .rejected(let status):
            return "The partner token endpoint returned HTTP \(status)."
        }
    }
}
