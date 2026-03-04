//
//  MockAPIClientTests.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Testing
import Foundation
@testable import SwiftNetworkKit

// MARK: - Test Models
private struct Post: Decodable, Equatable {
    let id: Int
    let title: String
}

private struct Comment: Decodable, Equatable {
    let id: Int
    let body: String
}

// MARK: - Test Endpoints
private struct GetPostsEndpoint: Endpoint {
    var baseURL = "https://jsonplaceholder.typicode.com"
    var path    = "/posts"
    var method  = HTTPMethod.GET
}

private struct GetPostEndpoint: Endpoint {
    let id: Int
    var baseURL     = "https://jsonplaceholder.typicode.com"
    var path: String { "/posts/\(id)" }
    var method      = HTTPMethod.GET
}

private struct GetCommentsEndpoint: Endpoint {
    var baseURL = "https://jsonplaceholder.typicode.com"
    var path    = "/comments"
    var method  = HTTPMethod.GET
}

private struct DeletePostEndpoint: Endpoint {
    let id: Int
    var baseURL     = "https://jsonplaceholder.typicode.com"
    var path: String { "/posts/\(id)" }
    var method      = HTTPMethod.DELETE
}

// MARK: - MockAPIClientTests
@Suite("MockAPIClient Tests")
struct MockAPIClientTests {

    // MARK: - Response Registration
    @Suite("Response Registration")
    struct ResponseRegistrationTests {

        @Test("Registered success response is returned correctly")
        func registeredSuccessResponseIsReturned() async throws {
            let mock = MockAPIClient()
            let expected = [Post(id: 1, title: "Hello"), Post(id: 2, title: "World")]
            mock.registerResponse(expected, for: GetPostsEndpoint.self)

            let result: [Post] = try await mock.request(GetPostsEndpoint())
            #expect(result == expected)
        }

        @Test("Registered error is thrown correctly")
        func registeredErrorIsThrown() async throws {
            let mock = MockAPIClient()
            mock.registerError(.notFound, for: GetPostEndpoint.self)

            await #expect(throws: NetworkError.notFound) {
                let _: Post = try await mock.request(GetPostEndpoint(id: 99))
            }
        }

        @Test("Registered data is returned for requestData()")
        func registeredDataIsReturnedForRequestData() async throws {
            let mock = MockAPIClient()
            let json = #"[{"id":1,"title":"Hello"}]"#
            let data = json.data(using: .utf8)!
            mock.registerData(data, for: GetPostsEndpoint.self)

            let result = try await mock.requestData(GetPostsEndpoint())
            #expect(result == data)
        }

        @Test("Different endpoints return their own registered responses")
        func differentEndpointsReturnOwnResponses() async throws {
            let mock = MockAPIClient()
            let posts    = [Post(id: 1, title: "Post")]
            let comments = [Comment(id: 1, body: "Comment")]

            mock.registerResponse(posts,    for: GetPostsEndpoint.self)
            mock.registerResponse(comments, for: GetCommentsEndpoint.self)

            let returnedPosts:    [Post]    = try await mock.request(GetPostsEndpoint())
            let returnedComments: [Comment] = try await mock.request(GetCommentsEndpoint())

            #expect(returnedPosts    == posts)
            #expect(returnedComments == comments)
        }

        @Test("Re-registering an endpoint overwrites the previous response")
        func reRegisteringOverwritesPreviousResponse() async throws {
            let mock = MockAPIClient()
            let first  = [Post(id: 1, title: "First")]
            let second = [Post(id: 2, title: "Second")]

            mock.registerResponse(first,  for: GetPostsEndpoint.self)
            mock.registerResponse(second, for: GetPostsEndpoint.self) // overwrite

            let result: [Post] = try await mock.request(GetPostsEndpoint())
            #expect(result == second)
        }

        @Test("Unregistered endpoint throws an error")
        func unregisteredEndpointThrowsError() async throws {
            let mock = MockAPIClient()
            // Nothing registered

            await #expect(throws: (any Error).self) {
                let _: [Post] = try await mock.request(GetPostsEndpoint())
            }
        }

        @Test("requestWithoutResponse() succeeds with no registration")
        func requestWithoutResponseSucceedsWithNoRegistration() async throws {
            let mock = MockAPIClient()

            await #expect(throws: Never.self) {
                try await mock.requestWithoutResponse(DeletePostEndpoint(id: 1))
            }
        }

        @Test("requestWithoutResponse() throws registered error")
        func requestWithoutResponseThrowsRegisteredError() async throws {
            let mock = MockAPIClient()
            mock.registerError(.forbidden, for: DeletePostEndpoint.self)

            await #expect(throws: NetworkError.forbidden) {
                try await mock.requestWithoutResponse(DeletePostEndpoint(id: 1))
            }
        }
    }

    // MARK: - Forced Error
    @Suite("Forced Error")
    struct ForcedErrorTests {

        @Test("forcedError overrides registered success response")
        func forcedErrorOverridesSuccess() async throws {
            let mock = MockAPIClient()
            mock.registerResponse([Post(id: 1, title: "Hello")], for: GetPostsEndpoint.self)
            mock.forcedError = .noInternetConnection

            await #expect(throws: NetworkError.noInternetConnection) {
                let _: [Post] = try await mock.request(GetPostsEndpoint())
            }
        }

        @Test("forcedError overrides registered error response")
        func forcedErrorOverridesRegisteredError() async throws {
            let mock = MockAPIClient()
            mock.registerError(.notFound, for: GetPostsEndpoint.self)
            mock.forcedError = .timeout  // timeout wins over notFound

            await #expect(throws: NetworkError.timeout) {
                let _: [Post] = try await mock.request(GetPostsEndpoint())
            }
        }

        @Test("forcedError applies to all endpoint types")
        func forcedErrorAppliesToAllEndpoints() async throws {
            let mock = MockAPIClient()
            mock.registerResponse([Post(id: 1, title: "Hello")],    for: GetPostsEndpoint.self)
            mock.registerResponse([Comment(id: 1, body: "Comment")], for: GetCommentsEndpoint.self)
            mock.forcedError = .serverError(statusCode: 503)

            await #expect(throws: NetworkError.serverError(statusCode: 503)) {
                let _: [Post] = try await mock.request(GetPostsEndpoint())
            }

            await #expect(throws: NetworkError.serverError(statusCode: 503)) {
                let _: [Comment] = try await mock.request(GetCommentsEndpoint())
            }
        }

        @Test("forcedError applies to requestData()")
        func forcedErrorAppliesToRequestData() async throws {
            let mock = MockAPIClient()
            let data = "{}".data(using: .utf8)!
            mock.registerData(data, for: GetPostsEndpoint.self)
            mock.forcedError = .cancelled

            await #expect(throws: NetworkError.cancelled) {
                _ = try await mock.requestData(GetPostsEndpoint())
            }
        }

        @Test("forcedError applies to requestWithoutResponse()")
        func forcedErrorAppliesToRequestWithoutResponse() async throws {
            let mock = MockAPIClient()
            mock.forcedError = .unauthorized

            await #expect(throws: NetworkError.unauthorized) {
                try await mock.requestWithoutResponse(DeletePostEndpoint(id: 1))
            }
        }
    }

    // MARK: - Call Tracking
    @Suite("Call Tracking")
    struct CallTrackingTests {

        @Test("Initial state has zero calls")
        func initialStateHasZeroCalls() {
            let mock = MockAPIClient()
            #expect(mock.callCount == 0)
            #expect(mock.wasCalled == false)
        }

        @Test("callCount increments after each request")
        func callCountIncrementsAfterEachRequest() async throws {
            let mock = MockAPIClient()
            mock.forcedError = .timeout

            _ = try? await mock.requestData(GetPostsEndpoint())
            _ = try? await mock.requestData(GetPostsEndpoint())

            #expect(mock.callCount == 2)
        }

        @Test("callCount tracks failed requests too")
        func callCountTracksFailedRequests() async throws {
            let mock = MockAPIClient()
            mock.forcedError = .unauthorized

            try? await mock.requestWithoutResponse(DeletePostEndpoint(id: 1))
            try? await mock.requestWithoutResponse(DeletePostEndpoint(id: 2))
            try? await mock.requestWithoutResponse(DeletePostEndpoint(id: 3))

            #expect(mock.callCount == 3)
        }

        @Test("wasCalled(with:) returns false for uncalled endpoint")
        func wasCalledReturnsFalseForUncalledEndpoint() {
            let mock = MockAPIClient()
            #expect(mock.wasCalled(with: GetPostsEndpoint.self) == false)
        }

        @Test("wasCalled(with:) returns true after calling that endpoint")
        func wasCalledReturnsTrueAfterCalling() async throws {
            let mock = MockAPIClient()
            mock.forcedError = .timeout

            _ = try? await mock.requestData(GetPostsEndpoint())

            #expect(mock.wasCalled(with: GetPostsEndpoint.self) == true)
            #expect(mock.wasCalled(with: GetCommentsEndpoint.self) == false)
        }

        @Test("callCount(for:) counts each endpoint type independently")
        func callCountPerEndpointIsIndependent() async throws {
            let mock = MockAPIClient()
            mock.forcedError = .timeout

            _ = try? await mock.requestData(GetPostsEndpoint())
            _ = try? await mock.requestData(GetPostsEndpoint())
            _ = try? await mock.requestData(GetPostsEndpoint())
            _ = try? await mock.requestData(GetCommentsEndpoint())

            #expect(mock.callCount(for: GetPostsEndpoint.self)    == 3)
            #expect(mock.callCount(for: GetCommentsEndpoint.self) == 1)
        }

        @Test("lastRequest(of:) returns nil when endpoint was never called")
        func lastRequestReturnsNilForUncalledEndpoint() {
            let mock = MockAPIClient()
            let last = mock.lastRequest(of: GetPostEndpoint.self)
            #expect(last == nil)
        }

        @Test("lastRequest(of:) returns the most recent endpoint value")
        func lastRequestReturnsMostRecentEndpoint() async throws {
            let mock = MockAPIClient()
            let post = Post(id: 1, title: "Hello")
            mock.registerResponse(post, for: GetPostEndpoint.self)

            let _: Post = try await mock.request(GetPostEndpoint(id: 1))
            let _: Post = try await mock.request(GetPostEndpoint(id: 3))
            let _: Post = try await mock.request(GetPostEndpoint(id: 7))

            let last = mock.lastRequest(of: GetPostEndpoint.self)
            #expect(last?.id == 7)
        }
    }

    // MARK: - Reset
    @Suite("Reset")
    struct ResetTests {

        @Test("reset() clears call count to zero")
        func resetClearsCallCount() async throws {
            let mock = MockAPIClient()
            mock.forcedError = .timeout

            _ = try? await mock.requestData(GetPostsEndpoint())
            _ = try? await mock.requestData(GetPostsEndpoint())

            mock.reset()
            #expect(mock.callCount == 0)
        }

        @Test("reset() clears wasCalled to false")
        func resetClearsWasCalled() async throws {
            let mock = MockAPIClient()
            mock.forcedError = .timeout

            _ = try? await mock.requestData(GetPostsEndpoint())
            mock.reset()

            #expect(mock.wasCalled == false)
        }

        @Test("reset() clears forced error")
        func resetClearsForcedError() {
            let mock = MockAPIClient()
            mock.forcedError = .unauthorized
            mock.reset()
            #expect(mock.forcedError == nil)
        }

        @Test("reset() clears registered responses")
        func resetClearsRegisteredResponses() async throws {
            let mock = MockAPIClient()
            mock.registerResponse([Post(id: 1, title: "Hello")], for: GetPostsEndpoint.self)
            mock.reset()

            await #expect(throws: (any Error).self) {
                let _: [Post] = try await mock.request(GetPostsEndpoint())
            }
        }

        @Test("reset() clears simulated delay")
        func resetClearsSimulatedDelay() {
            let mock = MockAPIClient()
            mock.simulatedDelay = 3.0
            mock.reset()
            #expect(mock.simulatedDelay == 0)
        }

        @Test("mock is fully reusable after reset()")
        func mockIsReusableAfterReset() async throws {
            let mock = MockAPIClient()

            // First use
            mock.registerResponse([Post(id: 1, title: "First")], for: GetPostsEndpoint.self)
            let first: [Post] = try await mock.request(GetPostsEndpoint())
            #expect(first.first?.title == "First")

            // Reset and reuse
            mock.reset()
            mock.registerResponse([Post(id: 2, title: "Second")], for: GetPostsEndpoint.self)
            let second: [Post] = try await mock.request(GetPostsEndpoint())
            #expect(second.first?.title == "Second")
            #expect(mock.callCount == 1)  // reset to 0 then incremented once
        }
    }

    // MARK: - Simulated Delay
    @Suite("Simulated Delay")
    struct SimulatedDelayTests {

        @Test("Zero delay completes immediately")
        func zeroDelayCompletesImmediately() async throws {
            let mock = MockAPIClient()
            mock.registerResponse([Post(id: 1, title: "Hello")], for: GetPostsEndpoint.self)
            mock.simulatedDelay = 0

            let start = Date()
            let _: [Post] = try await mock.request(GetPostsEndpoint())
            let elapsed = Date().timeIntervalSince(start)

            #expect(elapsed < 0.5)
        }

        @Test("Simulated delay causes measurable latency")
        func simulatedDelayIsMeasurable() async throws {
            let mock = MockAPIClient()
            mock.registerResponse([Post(id: 1, title: "Hello")], for: GetPostsEndpoint.self)
            mock.simulatedDelay = 0.3

            let start = Date()
            let _: [Post] = try await mock.request(GetPostsEndpoint())
            let elapsed = Date().timeIntervalSince(start)

            #expect(elapsed >= 0.3)
        }
    }
}
