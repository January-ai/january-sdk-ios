import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// This file intentionally contains the small HTTP runtime the generated
// January transport needs. OpenAPI generation remains a maintainer tool; SDK
// consumers do not need to resolve Apple's OpenAPI packages.

public struct HTTPField: Sendable, Hashable {
    public struct Name: Sendable, Hashable, RawRepresentable {
        public let rawValue: String

        public init?(rawValue: String) {
            self.init(rawValue)
        }

        public init?(_ rawValue: String) {
            let normalized = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else { return nil }
            self.rawValue = normalized
        }

        public static let accept = Name("accept")!
        public static let authorization = Name("authorization")!
        public static let contentType = Name("content-type")!
        public static let retryAfter = Name("retry-after")!
        public static let userAgent = Name("user-agent")!
        public static let wwwAuthenticate = Name("www-authenticate")!
    }
}

public struct HTTPFields: Sendable, Hashable {
    private var storage: [HTTPField.Name: String] = [:]

    public init() {}

    public subscript(name: HTTPField.Name) -> String? {
        get { storage[name] }
        set { storage[name] = newValue }
    }

    package var values: [HTTPField.Name: String] { storage }
}

public struct _HTTPRequest: Sendable, Hashable {
    public struct Method: Sendable, Hashable, RawRepresentable {
        public let rawValue: String

        public init?(rawValue: String) {
            guard !rawValue.isEmpty else { return nil }
            self.rawValue = rawValue
        }

        private init(_ rawValue: String) { self.rawValue = rawValue }

        public static let delete = Method("DELETE")
        public static let get = Method("GET")
        public static let patch = Method("PATCH")
        public static let post = Method("POST")
    }

    public var method: Method
    public var path: String?
    public var headerFields: HTTPFields

    public init(soar_path path: String, method: Method, headerFields: HTTPFields = .init()) {
        self.method = method
        self.path = path
        self.headerFields = headerFields
    }
}

public typealias HTTPRequest = _HTTPRequest

package enum HTTPTypes {
    package typealias HTTPRequest = _HTTPRequest
}

public struct HTTPResponse: Sendable, Hashable {
    public struct Status: Sendable, Hashable, ExpressibleByIntegerLiteral {
        public let code: Int

        public init(code: Int) { self.code = code }
        public init(integerLiteral value: Int) { self.code = value }

        public static let ok = Status(code: 200)
        public static let unauthorized = Status(code: 401)
    }

    public var status: Status
    public var headerFields: HTTPFields

    public init(status: Status, headerFields: HTTPFields = .init()) {
        self.status = status
        self.headerFields = headerFields
    }
}

public struct _HTTPBody: Sendable, Hashable {
    public enum IterationBehavior: Sendable {
        case single
        case multiple
    }

    package let data: Data
    public let iterationBehavior: IterationBehavior

    public init(_ data: Data) {
        self.data = data
        self.iterationBehavior = .multiple
    }

    public init(_ bytes: [UInt8]) { self.init(Data(bytes)) }
    public init(_ string: String) { self.init(Data(string.utf8)) }
}

public typealias HTTPBody = _HTTPBody

public extension Data {
    init(collecting body: HTTPBody, upTo limit: Int) async throws {
        guard body.data.count <= limit else { throw TransportRuntimeError.bodyTooLarge }
        self = body.data
    }
}

public extension Array where Element == UInt8 {
    init(collecting body: HTTPBody, upTo limit: Int) async throws {
        self = Array(try await Data(collecting: body, upTo: limit))
    }
}

public protocol ClientTransport: Sendable {
    func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?)
}

public protocol ClientMiddleware: Sendable {
    func intercept(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String,
        next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?)
    ) async throws -> (HTTPResponse, HTTPBody?)
}

public struct ClientError: Error {
    public let underlyingError: any Error

    public init(underlyingError: any Error) {
        self.underlyingError = underlyingError
    }
}

public struct URLSessionTransport: ClientTransport {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(
        _ request: HTTPRequest,
        body: HTTPBody?,
        baseURL: URL,
        operationID: String
    ) async throws -> (HTTPResponse, HTTPBody?) {
        guard let path = request.path, let url = URL(string: path, relativeTo: baseURL)?.absoluteURL else {
            throw ClientError(underlyingError: TransportRuntimeError.invalidURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = body?.data
        for (name, value) in request.headerFields.values {
            urlRequest.setValue(value, forHTTPHeaderField: name.rawValue)
        }

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let response = response as? HTTPURLResponse else {
                throw TransportRuntimeError.invalidResponse
            }
            var fields = HTTPFields()
            for (rawName, rawValue) in response.allHeaderFields {
                guard
                    let name = rawName as? String,
                    let fieldName = HTTPField.Name(name)
                else { continue }
                fields[fieldName] = String(describing: rawValue)
            }
            let responseBody = data.isEmpty ? nil : HTTPBody(data)
            return (HTTPResponse(status: .init(code: response.statusCode), headerFields: fields), responseBody)
        } catch let error as ClientError {
            throw error
        } catch {
            throw ClientError(underlyingError: error)
        }
    }
}

package protocol AcceptableProtocol: RawRepresentable, Sendable, Hashable, CaseIterable where RawValue == String {}

package enum OpenAPIRuntime {
    package typealias HTTPBody = _HTTPBody

    package struct AcceptHeaderContentType<ContentType: AcceptableProtocol>: Sendable, Hashable {
        package let contentType: ContentType
        package init(contentType: ContentType) { self.contentType = contentType }
    }
}

package extension Array {
    static func defaultValues<T: AcceptableProtocol>() -> [OpenAPIRuntime.AcceptHeaderContentType<T>]
    where Element == OpenAPIRuntime.AcceptHeaderContentType<T> {
        T.allCases.map { .init(contentType: $0) }
    }
}

package struct Configuration: Sendable {
    package init() {}
}

package enum ParameterStyle: Sendable {
    case form
}

package enum TransportRuntimeError: Error {
    case bodyTooLarge
    case invalidContentType
    case invalidResponse
    case invalidURL
    case missingResponseBody
    case unsupportedValue
    case unexpectedResponseStatus(String)
}

package struct ServerVariable: Sendable, Hashable {
    package let name: String
    package let value: String
    package let allowedValues: [String]?

    package init(name: String, value: String, allowedValues: [String]? = nil) {
        self.name = name
        self.value = value
        self.allowedValues = allowedValues
    }
}

package extension URL {
    init(validatingOpenAPIServerURL source: String, variables: [ServerVariable]) throws {
        var rendered = source
        for variable in variables {
            if let allowedValues = variable.allowedValues, !allowedValues.contains(variable.value) {
                throw TransportRuntimeError.invalidURL
            }
            rendered = rendered.replacingOccurrences(of: "{\(variable.name)}", with: variable.value)
        }
        guard let url = URL(string: rendered) else { throw TransportRuntimeError.invalidURL }
        self = url
    }
}

package func throwUnexpectedResponseStatus(
    expectedStatus: String,
    response: any Sendable
) throws -> Never {
    throw TransportRuntimeError.unexpectedResponseStatus(expectedStatus)
}

package struct Converter: Sendable {
    package init(configuration: Configuration) {}

    package func renderedPath(template: String, parameters: [any Encodable]) throws -> String {
        var path = template
        for parameter in parameters {
            guard let range = path.range(of: "{}") else { break }
            let value = try stringValue(parameter)
                .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? ""
            path.replaceSubrange(range, with: value)
        }
        return path
    }

    package func setHeaderFieldAsURI<T: Encodable>(
        in headerFields: inout HTTPFields,
        name: String,
        value: T?
    ) throws {
        guard let value, let fieldName = HTTPField.Name(name) else { return }
        headerFields[fieldName] = try stringValue(value)
    }

    package func setQueryItemAsURI<T: Encodable>(
        in request: inout HTTPRequest,
        style: ParameterStyle?,
        explode: Bool?,
        name: String,
        value: T?
    ) throws {
        guard let value, let path = request.path else { return }
        let components = URLComponents(string: path)
        guard var components else { throw TransportRuntimeError.invalidURL }
        var items = components.queryItems ?? []
        items.append(URLQueryItem(name: name, value: try stringValue(value)))
        components.queryItems = items
        request.path = components.string
    }

    package func setAcceptHeader<T: AcceptableProtocol>(
        in headerFields: inout HTTPFields,
        contentTypes: [OpenAPIRuntime.AcceptHeaderContentType<T>]
    ) {
        headerFields[.accept] = contentTypes.map { $0.contentType.rawValue }.joined(separator: ", ")
    }

    package func setRequiredRequestBodyAsJSON<T: Encodable>(
        _ value: T,
        headerFields: inout HTTPFields,
        contentType: String
    ) throws -> HTTPBody {
        headerFields[.contentType] = contentType
        return HTTPBody(try jsonEncoder().encode(value))
    }

    package func extractContentTypeIfPresent(in headerFields: HTTPFields) -> String? {
        headerFields[.contentType]
    }

    package func bestContentType(received: String?, options: [String]) throws -> String {
        guard let first = options.first else { throw TransportRuntimeError.invalidContentType }
        guard let received else { return first }
        let normalized = received.split(separator: ";", maxSplits: 1).first?.lowercased()
        guard options.contains(where: { $0.lowercased() == normalized }) else {
            throw TransportRuntimeError.invalidContentType
        }
        return options.first { $0.lowercased() == normalized } ?? first
    }

    package func getResponseBodyAsJSON<T: Decodable, C>(
        _ type: T.Type,
        from body: HTTPBody?,
        transforming transform: (T) -> C
    ) async throws -> C {
        guard let body else { throw TransportRuntimeError.missingResponseBody }
        return transform(try jsonDecoder().decode(type, from: body.data))
    }

    package func getOptionalHeaderFieldAsURI<T: Decodable>(
        in headerFields: HTTPFields,
        name: String,
        as type: T.Type
    ) throws -> T? {
        guard let fieldName = HTTPField.Name(name), let value = headerFields[fieldName] else { return nil }
        if type == String.self { return value as? T }
        return try JSONDecoder().decode(type, from: Data(value.utf8))
    }

    private func stringValue<T: Encodable>(_ value: T) throws -> String {
        if let value = value as? Double { return String(value) }
        if let value = value as? Float { return String(value) }
        return try stringValue(value as any Encodable)
    }

    private func stringValue(_ value: any Encodable) throws -> String {
        if let value = value as? Double { return String(value) }
        if let value = value as? Float { return String(value) }
        let mirror = Mirror(reflecting: value)
        if mirror.displayStyle == .optional,
           let unwrapped = mirror.children.first?.value as? any Encodable {
            return try stringValue(unwrapped)
        }
        let data = try JSONEncoder().encode(AnyEncodable(value))
        let object = try JSONSerialization.jsonObject(with: data, options: .fragmentsAllowed)
        switch object {
        case let string as String: return string
        case let number as NSNumber: return number.stringValue
        case let array as [Any]: return array.map { String(describing: $0) }.joined(separator: ",")
        default: throw TransportRuntimeError.unsupportedValue
        }
    }

    private func jsonEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.dateFormatter.string(from: date))
        }
        return encoder
    }

    private func jsonDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = Self.dateFormatter.date(from: value) ?? Self.fallbackDateFormatter.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO-8601 date")
        }
        return decoder
    }

    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let fallbackDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

private struct AnyEncodable: Encodable {
    let value: any Encodable
    init(_ value: any Encodable) { self.value = value }
    func encode(to encoder: Encoder) throws { try value.encode(to: encoder) }
}

package struct UniversalClient: Sendable {
    package let converter: Converter
    private let serverURL: URL
    private let transport: any ClientTransport
    private let middlewares: [any ClientMiddleware]

    package init(
        serverURL: URL,
        configuration: Configuration,
        transport: any ClientTransport,
        middlewares: [any ClientMiddleware]
    ) {
        self.serverURL = serverURL
        self.converter = Converter(configuration: configuration)
        self.transport = transport
        self.middlewares = middlewares
    }

    package func send<Input: Sendable, Output: Sendable>(
        input: Input,
        forOperation operationID: String,
        serializer: @Sendable (Input) throws -> (HTTPRequest, HTTPBody?),
        deserializer: @Sendable (HTTPResponse, HTTPBody?) async throws -> Output
    ) async throws -> Output {
        do {
            let (request, body) = try serializer(input)
            var next: @Sendable (HTTPRequest, HTTPBody?, URL) async throws -> (HTTPResponse, HTTPBody?) = {
                request, body, baseURL in
                try await transport.send(request, body: body, baseURL: baseURL, operationID: operationID)
            }
            for middleware in middlewares.reversed() {
                let following = next
                next = { request, body, baseURL in
                    try await middleware.intercept(
                        request,
                        body: body,
                        baseURL: baseURL,
                        operationID: operationID,
                        next: following
                    )
                }
            }
            let (response, responseBody) = try await next(request, body, serverURL)
            return try await deserializer(response, responseBody)
        } catch let error as ClientError {
            throw error
        } catch {
            throw ClientError(underlyingError: error)
        }
    }
}

@inline(__always)
package func suppressMutabilityWarning<T>(_ value: inout T) {}
