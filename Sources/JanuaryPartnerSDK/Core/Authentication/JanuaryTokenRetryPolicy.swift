import Foundation

/// Controls bounded retries when the app's token provider fails to fetch a credential.
///
/// `maximumAttempts` includes the initial attempt. The default performs the initial
/// request plus up to three retries with exponential backoff and jitter. This policy
/// applies only to fetching a token from the app's backend; a January API operation
/// is still replayed at most once after `token_expired`.
public struct JanuaryTokenRetryPolicy: Hashable, Sendable {
    public static let `default` = JanuaryTokenRetryPolicy()
    public static let none = JanuaryTokenRetryPolicy(maximumAttempts: 1)

    public let maximumAttempts: Int
    public let initialDelay: TimeInterval
    public let multiplier: Double
    public let maximumDelay: TimeInterval
    public let jitterRatio: Double

    public init(
        maximumAttempts: Int = 4,
        initialDelay: TimeInterval = 0.25,
        multiplier: Double = 2,
        maximumDelay: TimeInterval = 2,
        jitterRatio: Double = 0.2
    ) {
        precondition(maximumAttempts >= 1, "maximumAttempts must be at least 1.")
        precondition(initialDelay.isFinite && initialDelay >= 0, "initialDelay must be finite and nonnegative.")
        precondition(multiplier.isFinite && multiplier >= 1, "multiplier must be finite and at least 1.")
        precondition(maximumDelay.isFinite && maximumDelay >= 0, "maximumDelay must be finite and nonnegative.")
        precondition(jitterRatio.isFinite && (0...1).contains(jitterRatio), "jitterRatio must be between 0 and 1.")

        self.maximumAttempts = maximumAttempts
        self.initialDelay = initialDelay
        self.multiplier = multiplier
        self.maximumDelay = maximumDelay
        self.jitterRatio = jitterRatio
    }

    package func delay(afterFailedAttempt failedAttempt: Int, unitRandom: Double) -> TimeInterval {
        let exponent = Double(max(0, failedAttempt - 1))
        let baseDelay = min(maximumDelay, initialDelay * pow(multiplier, exponent))
        let variation = baseDelay * jitterRatio
        let normalizedRandom = min(1, max(0, unitRandom))
        let jittered = baseDelay - variation + (2 * variation * normalizedRandom)
        return min(maximumDelay, max(0, jittered))
    }
}
