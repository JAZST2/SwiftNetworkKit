//
//  URLRequestBuilder.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Foundation

public struct URLRequestBuilder {

    // MARK: - Default Headers
    private let defaultHeaders: [String: String]

    public init(defaultHeaders: [String: String] = [:]) {
        self.defaultHeaders = defaultHeaders
    }

    public func build(from endpoint: some Endpoint) throws -> URLRequest {

        let url = try buildURL(from: endpoint)

        try validate(endpoint: endpoint)

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeoutInterval
        request.httpBody = endpoint.body

        var mergedHeaders = defaultHeaders
        endpoint.headers?.forEach { mergedHeaders[$0.key] = $0.value }
        request.allHTTPHeaderFields = mergedHeaders

        return request
    }
}

// MARK: - Private Helpers
private extension URLRequestBuilder {

    func buildURL(from endpoint: some Endpoint) throws -> URL {
        let rawURL = endpoint.baseURL + endpoint.path

        guard var components = URLComponents(string: rawURL) else {
            throw NetworkError.invalidURL
        }

        if let queryItems = endpoint.queryItems, !queryItems.isEmpty {
            var existing = components.queryItems ?? []
            existing.append(contentsOf: queryItems)
            components.queryItems = existing
        }

        guard let url = components.url else {
            throw NetworkError.invalidURL
        }

        return url
    }

    func validate(endpoint: some Endpoint) throws {
        if (endpoint.method == .GET || endpoint.method == .HEAD),
           endpoint.body != nil {
            throw NetworkError.invalidRequest
        }
    }
}

// MARK: - Convenience
public extension URLRequestBuilder {

    static var jsonBuilder: URLRequestBuilder {
        URLRequestBuilder(defaultHeaders: [
            "Content-Type": "application/json",
            "Accept":       "application/json"
        ])
    }
}
