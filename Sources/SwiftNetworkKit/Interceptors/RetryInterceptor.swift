//
//  RetryInterceptor.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Foundation

// MARK: - InterceptorProtocol
public protocol InterceptorProtocol {

    func intercept(_ request: URLRequest) async throws -> URLRequest

    func intercept(
        response: URLResponse,
        data: Data,
        for request: URLRequest
    ) async throws -> Data
}

// MARK: - Default Implementations
public extension InterceptorProtocol {

    func intercept(_ request: URLRequest) async throws -> URLRequest {
        return request
    }

    func intercept(
        response: URLResponse,
        data: Data,
        for request: URLRequest
    ) async throws -> Data {
        return data
    }
}

// MARK: - InterceptorChain
struct InterceptorChain {

    private let interceptors: [InterceptorProtocol]

    init(interceptors: [InterceptorProtocol]) {
        self.interceptors = interceptors
    }

    func apply(to request: URLRequest) async throws -> URLRequest {
        var current = request
        for interceptor in interceptors {
            current = try await interceptor.intercept(current)
        }
        return current
    }
    
    func apply(
        response: URLResponse,
        data: Data,
        for request: URLRequest
    ) async throws -> Data {
        var current = data
        for interceptor in interceptors.reversed() {
            current = try await interceptor.intercept(
                response: response,
                data: current,
                for: request
            )
        }
        return current
    }
}
