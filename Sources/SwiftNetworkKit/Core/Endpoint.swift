//
//  Endpoint.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Foundation

public protocol Endpoint {

    var baseURL: String { get }

    var path: String { get }

    var method: HTTPMethod { get }

    var headers: [String: String]? { get }

    var queryItems: [URLQueryItem]? { get }

    var body: Data? { get }

    var timeoutInterval: TimeInterval { get }
}

public extension Endpoint {

    var headers: [String: String]? { nil }
    var queryItems: [URLQueryItem]? { nil }
    var body: Data? { nil }
    var timeoutInterval: TimeInterval { 30.0 }
}

public extension Endpoint {
    
    func encode<T: Encodable>(_ value: T) -> Data? {
        try? JSONEncoder().encode(value)
    }
}
