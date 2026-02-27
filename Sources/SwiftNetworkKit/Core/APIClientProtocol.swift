//
//  APIClientProtocol.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Foundation

public protocol APIClientProtocol {

    func request<T: Decodable>(_ endpoint: some Endpoint) async throws -> T

    func requestWithoutResponse(_ endpoint: some Endpoint) async throws

    func requestData(_ endpoint: some Endpoint) async throws -> Data
}

// MARK: - Default Implementation
public extension APIClientProtocol {

    func requestWithoutResponse(_ endpoint: some Endpoint) async throws {
        let _: EmptyResponse = try await request(endpoint)
    }
}

// MARK: - EmptyResponse
public struct EmptyResponse: Decodable {}
