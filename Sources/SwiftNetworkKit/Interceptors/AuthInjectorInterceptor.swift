//
//  AuthInjectorInterceptor.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/26/26.
//

import Foundation

// MARK: - TokenProvider
public protocol TokenProvider: AnyObject, Sendable {

    var accessToken: String? { get }

    var refreshToken: String? { get }

    func refreshAccessToken() async throws -> String
}

// MARK: - AuthScheme
public enum AuthScheme: String {
    case bearer = "Bearer"
    case basic  = "Basic"
    case apiKey = "ApiKey"
}

// MARK: - AuthInjectorInterceptor
public actor AuthInjectorInterceptor: InterceptorProtocol {

    // MARK: - Properties
    private let tokenProvider: TokenProvider
    private let scheme: AuthScheme
    private let headerKey: String

    private var refreshTask: Task<String, Error>?

    // MARK: - Init
    public init(
        tokenProvider: TokenProvider,
        scheme: AuthScheme = .bearer,
        headerKey: String = "Authorization"
    ) {
        self.tokenProvider = tokenProvider
        self.scheme = scheme
        self.headerKey = headerKey
    }

    // MARK: - InterceptorProtocol

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        guard let token = tokenProvider.accessToken else {
            return request
        }

        var modified = request
        modified.setValue("\(scheme.rawValue) \(token)", forHTTPHeaderField: headerKey)
        return modified
    }

    public func intercept(
        response: URLResponse,
        data: Data,
        for request: URLRequest
    ) async throws -> Data {
        guard let http = response as? HTTPURLResponse,
              http.statusCode == 401 else {
            return data
        }

        do {
            let newToken = try await refreshTokenIfNeeded()
            throw NetworkError.tokenRefreshed(newToken: newToken)
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.unauthorized
        }
    }
}

// MARK: - Token Refresh
private extension AuthInjectorInterceptor {

    func refreshTokenIfNeeded() async throws -> String {
        // If a refresh is already in flight, wait for it
        if let existing = refreshTask {
            return try await existing.value
        }

        let provider = tokenProvider

        let task = Task<String, Error> {
            return try await provider.refreshAccessToken()
        }

        refreshTask = task

        do {
            let token = try await task.value
            refreshTask = nil
            return token
        } catch {
            refreshTask = nil
            throw error
        }
    }
}

// MARK: - NetworkError Extension
extension NetworkError {

    static func tokenRefreshed(newToken: String) -> NetworkError {
        return .unknown(TokenRefreshSuccessSignal(newToken: newToken))
    }
}

// MARK: - TokenRefreshSuccessSignal
struct TokenRefreshSuccessSignal: Error {
    let newToken: String
}
