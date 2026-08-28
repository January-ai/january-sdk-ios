import Foundation
import OSLog

/// Exchanges a local development API key for short-lived client tokens.
///
/// Use this provider only to exercise the production authentication lifecycle
/// from a local debug build. A distributed app must implement
/// ``JanuaryTokenProvider`` against its own authenticated backend instead.
public struct JanuaryDevelopmentTokenProvider: JanuaryTokenProvider {
    internal typealias RequestPerformer = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private static let tokenEndpoint = URL(
        string: "https://partners.january.ai/v1.2/auth/client-tokens"
    )!
    private static let logger = Logger(
        subsystem: "ai.january.sdk",
        category: "authentication"
    )
    internal static let warning =
        "JanuaryDevelopmentTokenProvider is for local debug testing only. " +
        "Do not ship an app containing a January API key. Use your own backend-backed " +
        "JanuaryTokenProvider in production."

    private let apiKey: String
    private let endUserID: PartnerUserID
    private let ttlSeconds: Int
    private let endpoint: URL
    private let performRequest: RequestPerformer

    /// Creates a provider that exercises client-token minting from a local
    /// development build.
    ///
    /// - Warning: The API key is sent directly from the app process. Never use
    ///   this provider in a production or distributed application.
    @available(*, deprecated, message: "Local debug testing only. Do not ship an API key; implement JanuaryTokenProvider against your authenticated backend for production.")
    public init(
        apiKey: String,
        endUserID: PartnerUserID,
        ttlSeconds: Int = 300
    ) throws {
        try self.init(
            apiKey: apiKey,
            endUserID: endUserID,
            ttlSeconds: ttlSeconds,
            endpoint: Self.tokenEndpoint,
            warningHandler: { message in
                Self.logger.warning("\(message, privacy: .public)")
            },
            performRequest: { request in
                try await Self.performURLSessionRequest(request)
            }
        )
    }

    internal init(
        apiKey: String,
        endUserID: PartnerUserID,
        ttlSeconds: Int,
        endpoint: URL,
        warningHandler: (String) -> Void,
        performRequest: @escaping RequestPerformer
    ) throws {
        let normalizedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedAPIKey.isEmpty else {
            throw JanuaryError(
                category: .authentication,
                code: "invalid_development_api_key",
                message: "A development API key is required."
            )
        }

        let normalizedEndUserID = endUserID.rawValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !normalizedEndUserID.isEmpty, normalizedEndUserID.count <= 64 else {
            throw JanuaryError(
                category: .validation,
                code: "invalid_end_user_id",
                message: "The development end-user ID must contain between 1 and 64 characters."
            )
        }
        guard (300...7_200).contains(ttlSeconds) else {
            throw JanuaryError(
                category: .validation,
                code: "invalid_client_token_ttl",
                message: "The development client-token lifetime must be between 300 and 7200 seconds."
            )
        }

        warningHandler(Self.warning)
        self.apiKey = normalizedAPIKey
        self.endUserID = PartnerUserID(rawValue: normalizedEndUserID)
        self.ttlSeconds = ttlSeconds
        self.endpoint = endpoint
        self.performRequest = performRequest
    }

    public func fetchClientToken() async throws -> JanuaryClientToken {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(MintRequest(
            endUserID: endUserID.rawValue,
            ttlSeconds: ttlSeconds
        ))

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await performRequest(request)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw JanuaryTokenProviderError(
                "January's development token endpoint is unavailable.",
                retryable: true
            )
        }
        guard let response = response as? HTTPURLResponse else {
            throw JanuaryError(
                category: .transport,
                code: "invalid_client_token_response",
                message: "January returned an invalid client-token response."
            )
        }
        guard (200..<300).contains(response.statusCode) else {
            if response.statusCode == 408 || response.statusCode == 429 || response.statusCode >= 500 {
                throw JanuaryTokenProviderError(
                    "January could not mint a development client token.",
                    retryable: true
                )
            }
            throw JanuaryError(
                category: Self.errorCategory(for: response.statusCode),
                code: "development_client_token_mint_failed",
                message: "January could not mint a development client token.",
                httpStatus: response.statusCode
            )
        }

        do {
            return try JSONDecoder().decode(JanuaryClientToken.self, from: data)
        } catch {
            throw JanuaryError(
                category: .decoding,
                code: "invalid_client_token_response",
                message: "January returned an unreadable client-token response."
            )
        }
    }

    private static func errorCategory(for status: Int) -> ErrorCategory {
        switch status {
        case 401: return .authentication
        case 403: return .authorization
        case 429: return .rateLimited
        case 500...599: return .server
        default: return .transport
        }
    }

    private static func performURLSessionRequest(
        _ request: URLRequest
    ) async throws -> (Data, URLResponse) {
        return try await URLSession.shared.data(for: request)
    }
}

private struct MintRequest: Encodable {
    let endUserID: String
    let ttlSeconds: Int

    private enum CodingKeys: String, CodingKey {
        case endUserID = "end_user_id"
        case ttlSeconds = "ttl_seconds"
    }
}
