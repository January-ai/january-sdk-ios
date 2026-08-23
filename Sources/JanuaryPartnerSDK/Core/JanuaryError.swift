import Foundation

/// The stable categories used by ``JanuaryError``.
public enum ErrorCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case authentication
    case authorization
    case validation
    case notFound
    case rateLimited
    case server
    case transport
    case timeout
    case decoding
}

/// An error returned by the January Partner SDK.
public struct JanuaryError: Error, LocalizedError, Sendable {
    public let category: ErrorCategory
    public let message: String
    public let httpStatus: Int?
    public let requestID: String?
    public let retryAfterSeconds: Double?

    public var errorDescription: String? { message }

    internal init(
        category: ErrorCategory,
        message: String,
        httpStatus: Int? = nil,
        requestID: String? = nil,
        retryAfterSeconds: Double? = nil
    ) {
        self.category = category
        self.message = message
        self.httpStatus = httpStatus
        self.requestID = requestID
        self.retryAfterSeconds = retryAfterSeconds
    }
}
