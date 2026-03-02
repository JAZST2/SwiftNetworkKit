//
//  APIClient.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Foundation

// MARK: - APIClient
/// The real, production implementation of APIClientProtocol.
/// Uses URLSession with async/await to execute network requests.
/// Supports a fully pluggable interceptor pipeline.
public final class APIClient: APIClientProtocol {

    // MARK: - Dependencies
    private let session: URLSession
    private let builder: URLRequestBuilder
    private let decoder: ResponseDecoder
    private let chain: InterceptorChain

    // MARK: - Init
    /// - Parameters:
    ///   - session: URLSession to use. Defaults to shared.
    ///   - builder: URLRequestBuilder to use. Defaults to .jsonBuilder.
    ///   - decoder: ResponseDecoder to use. Defaults to snakeCase strategy.
    ///   - interceptors: Ordered list of interceptors. Defaults to empty.
    public init(
        session: URLSession = .shared,
        builder: URLRequestBuilder = .jsonBuilder,
        decoder: ResponseDecoder = ResponseDecoder(),
        interceptors: [InterceptorProtocol] = []
    ) {
        self.session = session
        self.builder = builder
        self.decoder = decoder
        self.chain = InterceptorChain(interceptors: interceptors)
    }

    // MARK: - APIClientProtocol

    /// Executes a request and decodes the response into the given Decodable type.
    public func request<T: Decodable>(_ endpoint: some Endpoint) async throws -> T {
        let data = try await requestData(endpoint)
        return try decoder.decode(T.self, from: data)
    }

    /// Executes a request and returns raw Data.
    /// Runs the full interceptor pipeline and handles retry signals.
    public func requestData(_ endpoint: some Endpoint) async throws -> Data {
        // Step 1 – Build the base URLRequest from the endpoint
        let baseRequest = try builder.build(from: endpoint)

        // Step 2 – Execute with retry loop
        // The loop allows RetryInterceptor to signal re-execution
        return try await executeWithRetry(request: baseRequest)
    }
}

// MARK: - Private Execution
private extension APIClient {

    /// Executes the request through the full interceptor pipeline.
    /// Loops on retry signals from RetryInterceptor.
    func executeWithRetry(request: URLRequest) async throws -> Data {
        var currentRequest = request

        while true {
            do {
                // Step 1 – Run request through interceptor chain
                // e.g. AuthInjector adds token, Logger prints the request
                let interceptedRequest = try await chain.apply(to: currentRequest)

                // Step 2 – Fire the actual network call
                let (data, response) = try await performRequest(interceptedRequest)

                // Step 3 – Validate HTTP status code
                try validateResponse(response, data: data)

                // Step 4 – Run response through interceptor chain
                // e.g. Logger prints the response, AuthInjector watches for 401
                let processedData = try await chain.apply(
                    response: response,
                    data: data,
                    for: interceptedRequest
                )

                return processedData

            } catch let error as NetworkError {
                // Check if this is a retry signal from RetryInterceptor
                if case .unknown(let inner) = error, inner is RetrySignal {
                    // Re-apply request interceptors with fresh token before retrying
                    currentRequest = try await chain.apply(to: request)
                    continue  // loop again with updated request
                }

                // Any other NetworkError — propagate to the caller
                throw error
            }
        }
    }

    /// Fires the actual URLSession data task and maps URLErrors to NetworkError.
    func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError {
            throw NetworkError.mapURLError(urlError)
        } catch {
            throw NetworkError.unknown(error)
        }
    }

    /// Validates the HTTPURLResponse status code.
    /// Throws a typed NetworkError if the status code indicates failure.
    func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(
                NSError(
                    domain: "SwiftNetworkKit",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Response was not an HTTP response."]
                )
            )
        }

        if let error = NetworkError.mapHTTPStatusCode(httpResponse.statusCode) {
            throw error
        }
    }
}

// MARK: - Convenience Factories
public extension APIClient {

    /// A default client with no interceptors.
    /// Good for public endpoints that need no auth or logging.
    static var `default`: APIClient {
        APIClient()
    }

    /// A client pre-configured for development.
    /// Includes verbose logging. Pass your TokenProvider for auth.
    static func development(tokenProvider: TokenProvider? = nil) -> APIClient {
        var interceptors: [InterceptorProtocol] = [
            LoggingInterceptor(level: .verbose)
        ]
        if let provider = tokenProvider {
            interceptors.append(AuthInjectorInterceptor(tokenProvider: provider))
            interceptors.append(RetryInterceptor(maxRetries: 3))
        }
        return APIClient(interceptors: interceptors)
    }

    /// A client pre-configured for production.
    /// No logging. Includes auth and retry.
    static func production(tokenProvider: TokenProvider) -> APIClient {
        APIClient(interceptors: [
            AuthInjectorInterceptor(tokenProvider: tokenProvider),
            RetryInterceptor(maxRetries: 3)
        ])
    }
}
