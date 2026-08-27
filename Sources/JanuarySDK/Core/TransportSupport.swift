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

internal func errorCategory(for status: Int) -> ErrorCategory {
    switch status {
    case 400, 422: .validation
    case 401: .authentication
    case 403: .authorization
    case 404: .notFound
    case 429: .rateLimited
    case 504: .timeout
    case 500...599: .server
    default: .transport
    }
}
