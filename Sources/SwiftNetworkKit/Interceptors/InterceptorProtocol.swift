//
//  InterceptorProtocol.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Foundation

// MARK: - RetryPolicy
public enum RetryPolicy {

    case constant(delay: TimeInterval)

    case exponential(base: TimeInterval)

    case exponentialWithJitter(base: TimeInterval)

    func delay(for attempt: Int) -> TimeInterval {
        switch self {
        case .constant(let delay):
            return delay

        case .exponential(let base):
            return base * pow(2.0, Double(attempt))

        case .exponentialWithJitter(let base):
            let exponential = base * pow(2.0, Double(attempt))
            let jitter = Double.random(in: 0.0...1.0)
            return exponential + jitter
        }
    }
}

// MARK: - RetryInterceptor
public final class RetryInterceptor: InterceptorProtocol {

    // MARK: - Properties
    private let maxRetries: Int
    private let policy: RetryPolicy

    private var retryCounts: [String: Int] = [:]

    private let retryableStatusCodes: Set<Int> = [
        408,  // Request Timeout
        429,  // Too Many Requests
        500,  // Internal Server Error
        502,  // Bad Gateway
        503,  // Service Unavailable
        504   // Gateway Timeout
    ]

    // MARK: - Init
    public init(
        maxRetries: Int = 3,
        policy: RetryPolicy = .exponentialWithJitter(base: 1.0)
    ) {
        self.maxRetries = maxRetries
        self.policy = policy
    }

    // MARK: - InterceptorProtocol

    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        return request
    }

    public func intercept(
        response: URLResponse,
        data: Data,
        for request: URLRequest
    ) async throws -> Data {
        let key = request.url?.absoluteString ?? "unknown"
        let currentAttempt = retryCounts[key, default: 0]

        guard shouldRetry(response: response) else {
            retryCounts.removeValue(forKey: key)
            return data
        }

        guard currentAttempt < maxRetries else {
            retryCounts.removeValue(forKey: key)
            throw NetworkError.retryFailed(attempts: maxRetries)
        }

        retryCounts[key] = currentAttempt + 1

        let delay = policy.delay(for: currentAttempt)
        let nanoseconds = UInt64(delay * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
        
        throw NetworkError.shouldRetry
    }
}

// MARK: - Private Helpers
private extension RetryInterceptor {

    func shouldRetry(response: URLResponse) -> Bool {
        if response is TokenRefreshResponse {
            return true
        }

        guard let http = response as? HTTPURLResponse else {
            return false
        }

        return retryableStatusCodes.contains(http.statusCode)
    }
}

// MARK: - NetworkError Retry Cases
public extension NetworkError {

    static var shouldRetry: NetworkError {
        .unknown(RetrySignal())
    }

    static func retryFailed(attempts: Int) -> NetworkError {
        .unknown(RetryFailedError(attempts: attempts))
    }
}

// MARK: - Internal Signal Types
struct RetrySignal: LocalizedError {
    var errorDescription: String? { "Retry signal — internal use only." }
}

/// Thrown when retries are exhausted. Maps to a user-facing error.
private struct RetryFailedError: LocalizedError {
    let attempts: Int
    var errorDescription: String? {
        "Request failed after \(attempts) retry attempts."
    }
}

private class TokenRefreshResponse: URLResponse {}
