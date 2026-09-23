import Foundation
import JanuaryPartnerTransport

internal enum ModelBridge {
    static func convert<Source: Encodable, Target: Decodable>(
        _ source: Source,
        to: Target.Type = Target.self
    ) throws -> Target {
        let data = try JSONEncoder().encode(source)
        return try JSONDecoder().decode(Target.self, from: data)
    }
}

internal func performTransportRequest<Value: Sendable>(
    _ operation: () async throws -> Value
) async throws -> Value {
    do {
        return try await operation()
    } catch let error as CancellationError {
        throw error
    } catch let error as JanuaryError {
        throw error
    } catch is DecodingError {
        throw JanuaryError(category: .decoding, message: "The January API returned an unreadable response.")
    } catch let error as URLError where error.code == .timedOut {
        throw JanuaryError(category: .timeout, message: "The request to the January API timed out.")
    } catch {
        throw mapTransportError(error)
    }
}

internal func mapTransportError(_ error: any Error) -> any Error {
    let underlying = (error as? ClientError)?.underlyingError ?? error
    if underlying is CancellationError {
        return CancellationError()
    }
    if let januaryError = underlying as? JanuaryError {
        return januaryError
    }
    // The app's token provider refused with an explicit, non-retryable failure (for example
    // its token endpoint rejected the user). No January API request was made, so this is an
    // authentication failure, not a networking one; the message is the one the provider wrote.
    if let providerError = underlying as? JanuaryTokenProviderError {
        return JanuaryError(
            category: .authentication,
            code: "client_token_provider_failed",
            message: providerError.message
        )
    }
    if underlying is DecodingError {
        return JanuaryError(category: .decoding, message: "The January API returned an unreadable response.")
    }
    if let urlError = underlying as? URLError, urlError.code == .timedOut {
        return JanuaryError(category: .timeout, message: "The request to the January API timed out.")
    }
    return JanuaryError(category: .transport, message: "The request to the January API failed.")
}

internal func apiError(_ category: ErrorCategory, status: Int, message: String? = nil) -> JanuaryError {
    JanuaryError(
        category: category,
        message: message ?? "The January API returned HTTP \(status).",
        httpStatus: status
    )
}

internal func apiError(
    _ category: ErrorCategory,
    status: Int,
    response: Components.Schemas.ErrorResponse
) -> JanuaryError {
    JanuaryError(
        category: category,
        code: response.code,
        message: response.message,
        httpStatus: status
    )
}

/// A status the operation does not list, with the API's error body when it sent one: the
/// error keeps the API's `code` and message (for example `conflict` with a 409).
internal func apiError(
    _ category: ErrorCategory,
    status: Int,
    response: Components.Schemas.ErrorResponse?
) -> JanuaryError {
    guard let response else { return apiError(category, status: status) }
    return apiError(category, status: status, response: response)
}

internal func errorCategory(for status: Int) -> ErrorCategory {
    switch status {
    // 409 is `conflict`: the request conflicts with an existing resource, and sending it
    // again unchanged fails the same way.
    case 400, 409, 422: .validation
    case 401: .authentication
    case 403: .authorization
    case 404: .notFound
    case 429: .rateLimited
    case 504: .timeout
    case 500...599: .server
    default: .transport
    }
}
