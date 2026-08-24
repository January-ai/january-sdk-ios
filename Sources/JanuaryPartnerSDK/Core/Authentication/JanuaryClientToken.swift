import Foundation

/// A short-lived credential returned by a partner-controlled backend.
public struct JanuaryClientToken: Hashable, Sendable {
    /// The opaque bearer-token value. Never log or persist this value.
    public let value: String
    /// The instant after which January will no longer accept the token.
    public let expiresAt: Date

    public init(value: String, expiresAt: Date) {
        self.value = value
        self.expiresAt = expiresAt
    }
}

/// Fetches a fresh short-lived credential from the integrating app's backend.
///
/// The provider should use the app's existing authenticated session. It must
/// never contain or return a January partner API key.
public typealias JanuaryClientTokenProvider = @Sendable () async throws -> JanuaryClientToken

package actor ClientTokenManager {
    private let provider: JanuaryClientTokenProvider
    private let refreshLeeway: TimeInterval
    private let now: @Sendable () -> Date
    private var cachedToken: JanuaryClientToken?
    private var refreshTask: Task<JanuaryClientToken, any Error>?

    init(
        provider: @escaping JanuaryClientTokenProvider,
        refreshLeeway: TimeInterval = 60,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.provider = provider
        self.refreshLeeway = refreshLeeway
        self.now = now
    }

    func token() async throws -> JanuaryClientToken {
        try Task.checkCancellation()
        if let cachedToken, cachedToken.expiresAt.timeIntervalSince(now()) > refreshLeeway {
            return cachedToken
        }
        if let refreshTask {
            let token = try await refreshTask.value
            try Task.checkCancellation()
            return token
        }

        let provider = self.provider
        let refreshLeeway = self.refreshLeeway
        let now = self.now
        let task = Task<JanuaryClientToken, any Error> {
            do {
                try Task.checkCancellation()
                let token = try await provider()
                let normalizedValue = token.value.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !normalizedValue.isEmpty else {
                    throw JanuaryError(
                        category: .authentication,
                        code: "invalid_client_token",
                        message: "The client token provider returned an empty token."
                    )
                }
                guard token.expiresAt.timeIntervalSince(now()) > refreshLeeway else {
                    throw JanuaryError(
                        category: .authentication,
                        code: "invalid_client_token_expiration",
                        message: "The client token provider returned an expired or nearly expired token."
                    )
                }
                return JanuaryClientToken(value: normalizedValue, expiresAt: token.expiresAt)
            } catch let error as CancellationError {
                throw error
            } catch let error as JanuaryError {
                throw error
            } catch {
                throw JanuaryError(
                    category: .authentication,
                    code: "client_token_provider_failed",
                    message: "The app could not obtain a January client token."
                )
            }
        }
        refreshTask = task

        do {
            let token = try await task.value
            cachedToken = token
            refreshTask = nil
            try Task.checkCancellation()
            return token
        } catch {
            refreshTask = nil
            throw error
        }
    }

    func invalidate(ifMatching value: String) {
        guard cachedToken?.value == value else { return }
        cachedToken = nil
    }
}
