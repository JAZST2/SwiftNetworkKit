//
//  APIClient.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Foundation

// MARK: - APIClient
public final class APIClient: APIClientProtocol {

    private let session: URLSession
    private let builder: URLRequestBuilder
    private let decoder: ResponseDecoder

    public init(
        session: URLSession = .shared,
        builder: URLRequestBuilder = .jsonBuilder,
        decoder: ResponseDecoder = ResponseDecoder()
    ) {
        self.session = session
        self.builder = builder
        self.decoder = decoder
    }

    // MARK: - APIClientProtocol
    public func request<T: Decodable>(_ endpoint: some Endpoint) async throws -> T {
        let data = try await requestData(endpoint)
        return try decode(data)
    }

    public func requestData(_ endpoint: some Endpoint) async throws -> Data {

        let urlRequest = try builder.build(from: endpoint)

        let (data, response) = try await performRequest(urlRequest)

        try validateResponse(response, data: data)

        return data
    }
}

// MARK: - Private Execution
private extension APIClient {

    func performRequest(_ request: URLRequest) async throws -> (Data, URLResponse) {
        do {
            return try await session.data(for: request)
        } catch let urlError as URLError {
            throw NetworkError.mapURLError(urlError)
        } catch {
            throw NetworkError.unknown(error)
        }
    }

    func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown(
                NSError(domain: "SwiftNetworkKit", code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Response was not an HTTP response."])
            )
        }

        if let error = NetworkError.mapHTTPStatusCode(httpResponse.statusCode) {
            throw error
        }
    }

    func decode<T: Decodable>(_ data: Data) throws -> T {
        try decoder.decode(T.self, from: data)
    }
}
