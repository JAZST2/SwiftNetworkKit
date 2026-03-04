//
//  RetryInterceptorTests.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Testing
import Foundation
@testable import SwiftNetworkKit

// MARK: - Helpers
/// Builds a mock HTTPURLResponse with a given status code.
private func makeResponse(statusCode: Int) -> HTTPURLResponse {
    HTTPURLResponse(
        url: URL(string: "https://jsonplaceholder.typicode.com/posts")!,
        statusCode: statusCode,
        httpVersion: nil,
        headerFields: nil
    )!
}

/// Builds a mock URLRequest.
private func makeRequest() -> URLRequest {
    URLRequest(url: URL(string: "https://jsonplaceholder.typicode.com/posts")!)
}

// MARK: - RetryInterceptorTests
@Suite("RetryInterceptor Tests")
struct RetryInterceptorTests {

    // MARK: - Request Pass Through
    @Suite("Request Pass Through")
    struct RequestPassThroughTests {

        @Test("intercept(request) passes request through unchanged")
        func requestPassesThroughUnchanged() async throws {
            let interceptor = RetryInterceptor()
            let request = makeRequest()

            let result = try await interceptor.intercept(request)

            #expect(result.url == request.url)
            #expect(result.httpMethod == request.httpMethod)
        }

        @Test("intercept(request) does not modify headers")
        func requestDoesNotModifyHeaders() async throws {
            let interceptor = RetryInterceptor()
            var request = makeRequest()
            request.setValue("application/json", forHTTPHeaderField: "Accept")

            let result = try await interceptor.intercept(request)

            #expect(result.allHTTPHeaderFields?["Accept"] == "application/json")
        }
    }

    // MARK: - Retryable Status Codes
    @Suite("Retryable Status Codes")
    struct RetryableStatusCodeTests {

        @Test("408 triggers retry signal",
              arguments: [408, 429, 500, 502, 503, 504])
        func retryableStatusCodeThrowsShouldRetry(code: Int) async throws {
            let interceptor = RetryInterceptor(maxRetries: 3)
            let response = makeResponse(statusCode: code)
            let request  = makeRequest()

            await #expect(throws: (any Error).self) {
                _ = try await interceptor.intercept(
                    response: response,
                    data: Data(),
                    for: request
                )
            }
        }

        @Test("200 does not trigger retry")
        func successStatusCodeDoesNotRetry() async throws {
            let interceptor = RetryInterceptor()
            let response = makeResponse(statusCode: 200)
            let request  = makeRequest()

            await #expect(throws: Never.self) {
                _ = try await interceptor.intercept(
                    response: response,
                    data: Data(),
                    for: request
                )
            }
        }

        @Test("201 does not trigger retry")
        func createdStatusCodeDoesNotRetry() async throws {
            let interceptor = RetryInterceptor()
            let response = makeResponse(statusCode: 201)
            let request  = makeRequest()

            await #expect(throws: Never.self) {
                _ = try await interceptor.intercept(
                    response: response,
                    data: Data(),
                    for: request
                )
            }
        }

        @Test("401 does not trigger retry — AuthInjector handles this")
        func unauthorizedDoesNotTriggerRetry() async throws {
            let interceptor = RetryInterceptor()
            let response = makeResponse(statusCode: 401)
            let request  = makeRequest()

            await #expect(throws: Never.self) {
                _ = try await interceptor.intercept(
                    response: response,
                    data: Data(),
                    for: request
                )
            }
        }

        @Test("404 does not trigger retry — resource simply missing")
        func notFoundDoesNotTriggerRetry() async throws {
            let interceptor = RetryInterceptor()
            let response = makeResponse(statusCode: 404)
            let request  = makeRequest()

            await #expect(throws: Never.self) {
                _ = try await interceptor.intercept(
                    response: response,
                    data: Data(),
                    for: request
                )
            }
        }

        @Test("403 does not trigger retry — permission issue")
        func forbiddenDoesNotTriggerRetry() async throws {
            let interceptor = RetryInterceptor()
            let response = makeResponse(statusCode: 403)
            let request  = makeRequest()

            await #expect(throws: Never.self) {
                _ = try await interceptor.intercept(
                    response: response,
                    data: Data(),
                    for: request
                )
            }
        }
    }

    // MARK: - Max Retries
    @Suite("Max Retries")
    struct MaxRetriesTests {

        @Test("Throws retryFailed after exhausting maxRetries")
        func throwsRetryFailedAfterExhaustingRetries() async throws {
            let maxRetries  = 3
            let interceptor = RetryInterceptor(
                maxRetries: maxRetries,
                policy: .constant(delay: 0)
            )
            let response = makeResponse(statusCode: 503)
            let request  = makeRequest()

            // Exhaust all retries
            for _ in 0..<maxRetries {
                _ = try? await interceptor.intercept(
                    response: response,
                    data: Data(),
                    for: request
                )
            }

            // Next call should throw retryFailed
            var caughtRetryFailed = false
            do {
                _ = try await interceptor.intercept(
                    response: response,
                    data: Data(),
                    for: request
                )
            } catch let error as NetworkError {
                if case .unknown(let inner) = error,
                   inner.localizedDescription.contains("3") {
                    caughtRetryFailed = true
                }
            }

            #expect(caughtRetryFailed)
        }

        @Test("Different URLs have independent retry budgets")
        func differentURLsHaveIndependentRetryBudgets() async throws {
            let interceptor = RetryInterceptor(
                maxRetries: 2,
                policy: .constant(delay: 0)
            )

            let request1 = URLRequest(url: URL(string: "https://example.com/posts")!)
            let request2 = URLRequest(url: URL(string: "https://example.com/comments")!)
            let response = makeResponse(statusCode: 503)

            // Exhaust retries for request1
            _ = try? await interceptor.intercept(response: response, data: Data(), for: request1)
            _ = try? await interceptor.intercept(response: response, data: Data(), for: request1)

            // request2 should still have its full retry budget
            await #expect(throws: (any Error).self) {
                _ = try await interceptor.intercept(
                    response: response,
                    data: Data(),
                    for: request2
                )
            }
        }

        @Test("maxRetries of 1 allows exactly one retry attempt")
        func maxRetriesOfOneAllowsOneAttempt() async throws {
            let interceptor = RetryInterceptor(
                maxRetries: 1,
                policy: .constant(delay: 0)
            )
            let response = makeResponse(statusCode: 503)
            let request  = makeRequest()

            // First call — should retry (throw shouldRetry signal)
            var firstThrew = false
            do {
                _ = try await interceptor.intercept(
                    response: response,
                    data: Data(),
                    for: request
                )
            } catch { firstThrew = true }

            #expect(firstThrew)

            // Second call — should throw retryFailed
            var secondThrew = false
            do {
                _ = try await interceptor.intercept(
                    response: response,
                    data: Data(),
                    for: request
                )
            } catch { secondThrew = true }

            #expect(secondThrew)
        }
    }

    // MARK: - Retry Policy
    @Suite("Retry Policy")
    struct RetryPolicyTests {

        @Test("Constant policy returns same delay for all attempts",
              arguments: [0, 1, 2, 3, 4])
        func constantPolicyReturnsSameDelay(attempt: Int) {
            let policy = RetryPolicy.constant(delay: 2.0)
            #expect(policy.delay(for: attempt) == 2.0)
        }

        @Test("Exponential policy doubles delay each attempt")
        func exponentialPolicyDoublesDelay() {
            let policy = RetryPolicy.exponential(base: 1.0)
            #expect(policy.delay(for: 0) == 1.0)   // 1.0 * 2^0
            #expect(policy.delay(for: 1) == 2.0)   // 1.0 * 2^1
            #expect(policy.delay(for: 2) == 4.0)   // 1.0 * 2^2
            #expect(policy.delay(for: 3) == 8.0)   // 1.0 * 2^3
        }

        @Test("Exponential policy with custom base scales correctly")
        func exponentialPolicyWithCustomBase() {
            let policy = RetryPolicy.exponential(base: 0.5)
            #expect(policy.delay(for: 0) == 0.5)   // 0.5 * 2^0
            #expect(policy.delay(for: 1) == 1.0)   // 0.5 * 2^1
            #expect(policy.delay(for: 2) == 2.0)   // 0.5 * 2^2
        }

        @Test("ExponentialWithJitter delay is greater than base exponential")
        func jitterDelayIsGreaterThanBaseExponential() {
            let policy = RetryPolicy.exponentialWithJitter(base: 1.0)
            // Jitter adds 0.0...1.0 so result must be >= base exponential
            for attempt in 0...4 {
                let base  = RetryPolicy.exponential(base: 1.0).delay(for: attempt)
                let jittered = policy.delay(for: attempt)
                #expect(jittered >= base)
            }
        }

        @Test("ExponentialWithJitter delay is within expected range")
        func jitterDelayIsWithinExpectedRange() {
            let policy = RetryPolicy.exponentialWithJitter(base: 1.0)
            for attempt in 0...3 {
                let base  = RetryPolicy.exponential(base: 1.0).delay(for: attempt)
                let delay = policy.delay(for: attempt)
                // jitter adds at most 1.0
                #expect(delay < base + 1.0 + 0.001)
            }
        }

        @Test("Constant delay with 0 seconds completes instantly")
        func constantZeroDelayCompletesInstantly() async throws {
            let interceptor = RetryInterceptor(
                maxRetries: 3,
                policy: .constant(delay: 0)
            )
            let response = makeResponse(statusCode: 503)
            let request  = makeRequest()

            let start = Date()
            _ = try? await interceptor.intercept(
                response: response,
                data: Data(),
                for: request
            )
            let elapsed = Date().timeIntervalSince(start)

            #expect(elapsed < 0.5)
        }
    }

    // MARK: - Data Pass Through
    @Suite("Data Pass Through")
    struct DataPassThroughTests {

        @Test("Successful response returns data unchanged")
        func successfulResponseReturnsDataUnchanged() async throws {
            let interceptor = RetryInterceptor()
            let response    = makeResponse(statusCode: 200)
            let request     = makeRequest()
            let expected    = #"[{"id":1,"title":"Hello"}]"#.data(using: .utf8)!

            let result = try await interceptor.intercept(
                response: response,
                data: expected,
                for: request
            )

            #expect(result == expected)
        }

        @Test("Successful response with empty data returns empty data")
        func successfulResponseWithEmptyDataReturnsEmpty() async throws {
            let interceptor = RetryInterceptor()
            let response    = makeResponse(statusCode: 204)
            let request     = makeRequest()

            let result = try await interceptor.intercept(
                response: response,
                data: Data(),
                for: request
            )

            #expect(result.isEmpty)
        }
    }
}
