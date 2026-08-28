import Foundation

/// A short-lived credential returned by a partner-controlled backend.
///
/// Its shape intentionally matches the response returned by a partner backend,
/// so an app can decode that response directly as `JanuaryClientToken`.
public struct JanuaryClientToken: Codable, Hashable, Sendable {
    /// The opaque bearer-token value. Never log or persist this value.
    public let token: String
    /// Lifetime in seconds, measured from when the provider receives the token.
    public let expiresIn: TimeInterval

    public init(token: String, expiresIn: TimeInterval) {
        self.token = token
        self.expiresIn = expiresIn
    }

    private enum CodingKeys: String, CodingKey {
        case token
        case expiresIn
        case expiresInSnakeCase = "expires_in"
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        token = try values.decode(String.self, forKey: .token)
        if let camelCase = try values.decodeIfPresent(TimeInterval.self, forKey: .expiresIn) {
            expiresIn = camelCase
        } else {
            expiresIn = try values.decode(TimeInterval.self, forKey: .expiresInSnakeCase)
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(token, forKey: .token)
        try values.encode(expiresIn, forKey: .expiresIn)
    }

}

/// Fetches a fresh short-lived credential from the integrating app's backend.
///
/// The provider should use the app's existing authenticated session. It must
/// never contain or return a January partner API key.
public typealias JanuaryClientTokenProvider = @Sendable (_ endUserID: String) async throws -> JanuaryClientToken

/// The integration seam between the SDK and the app's authenticated backend.
/// The provider owns its URL, authentication, and networking implementation.
public protocol JanuaryTokenProvider: Sendable {
    func fetchClientToken(for endUserID: String) async throws -> JanuaryClientToken
}

package typealias CachedClientTokenProvider = @Sendable () async throws -> JanuaryClientToken

/// A token-provider failure with an explicit retry decision.
///
/// Mark only transient partner-backend failures—such as timeouts, rate limits,
/// and server errors—as retryable. Ordinary errors stop immediately.
public struct JanuaryTokenProviderError: Error, LocalizedError, Sendable {
    public let message: String
    public let retryable: Bool

    public init(_ message: String, retryable: Bool = false) {
        self.message = message
        self.retryable = retryable
    }

    public var errorDescription: String? { message }
}

package actor ClientTokenManager {
    private let provider: CachedClientTokenProvider
    private let refreshLeeway: TimeInterval
    private let retryPolicy: JanuaryTokenRetryPolicy
    private let now: @Sendable () -> Date
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private let unitRandom: @Sendable () -> Double
    private var cachedToken: JanuaryClientToken?
    private var cachedExpiresAt: Date?
    private var refreshTask: Task<JanuaryClientToken, any Error>?

    init(
        provider: @escaping CachedClientTokenProvider,
        refreshLeeway: TimeInterval = 60,
        retryPolicy: JanuaryTokenRetryPolicy = .default,
        now: @escaping @Sendable () -> Date = { Date() },
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { seconds in
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        },
        unitRandom: @escaping @Sendable () -> Double = { Double.random(in: 0...1) }
    ) {
        self.provider = provider
        self.refreshLeeway = refreshLeeway
        self.retryPolicy = retryPolicy
        self.now = now
        self.sleep = sleep
        self.unitRandom = unitRandom
    }

    func token() async throws -> JanuaryClientToken {
        try Task.checkCancellation()
        if let cachedToken, let cachedExpiresAt, cachedExpiresAt.timeIntervalSince(now()) > refreshLeeway {
            return cachedToken
        }
        if let refreshTask {
            let token = try await refreshTask.value
            try Task.checkCancellation()
            return token
        }

        let provider = self.provider
        let refreshLeeway = self.refreshLeeway
        let retryPolicy = self.retryPolicy
        let now = self.now
        let sleep = self.sleep
        let unitRandom = self.unitRandom
        let task = Task<JanuaryClientToken, any Error> {
            var attempt = 1
            while true {
                try Task.checkCancellation()
                let token: JanuaryClientToken
                do {
                    token = try await provider()
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    guard let providerError = error as? JanuaryTokenProviderError,
                          providerError.retryable else {
                        throw error
                    }
                    guard attempt < retryPolicy.maximumAttempts else {
                        throw JanuaryError(
                            category: .authentication,
                            code: "client_token_provider_failed",
                            message: "The app could not obtain a January client token after \(attempt) attempts."
                        )
                    }
                    let delay = retryPolicy.delay(
                        afterFailedAttempt: attempt,
                        unitRandom: unitRandom()
                    )
                    attempt += 1
                    if delay > 0 {
                        try await sleep(delay)
                    }
                    continue
                }

                let normalizedValue = token.token.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedValue.isEmpty else {
                    throw JanuaryError(
                        category: .authentication,
                        code: "invalid_client_token",
                        message: "The client token provider returned an empty token."
                    )
                }
                guard token.expiresIn.isFinite, token.expiresIn > refreshLeeway else {
                    throw JanuaryError(
                        category: .authentication,
                        code: "invalid_client_token_expiration",
                        message: "The client token provider returned an expired or nearly expired token."
                    )
                }
                return JanuaryClientToken(token: normalizedValue, expiresIn: token.expiresIn)
            }
        }
        refreshTask = task

        do {
            let token = try await task.value
            cachedToken = token
            cachedExpiresAt = now().addingTimeInterval(token.expiresIn)
            refreshTask = nil
            try Task.checkCancellation()
            return token
        } catch {
            refreshTask = nil
            throw error
        }
    }

    func invalidate(ifMatching value: String) {
        guard cachedToken?.token == value else { return }
        cachedToken = nil
        cachedExpiresAt = nil
    }
}
