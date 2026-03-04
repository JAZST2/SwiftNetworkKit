//
//  APIClientTests.swift
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
    let userId: Int
    let title: String
    let body: String
}

private struct CreatePostRequest: Encodable {
    let title: String
    let body: String
    let userId: Int
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

private struct CreatePostEndpoint: Endpoint {
    let post: CreatePostRequest
    var baseURL = "https://jsonplaceholder.typicode.com"
    var path    = "/posts"
    var method  = HTTPMethod.POST
    var headers: [String: String]? { ["Content-Type": "application/json"] }
    var body: Data? { encode(post) }
}

private struct DeletePostEndpoint: Endpoint {
    let id: Int
    var baseURL     = "https://jsonplaceholder.typicode.com"
    var path: String { "/posts/\(id)" }
    var method      = HTTPMethod.DELETE
}

// MARK: - APIClientTests
@Suite("APIClient Tests")
struct APIClientTests {

    // MARK: - Helpers
    /// Builds a mock client with a pre-registered success response.
    private func makeMock() -> MockAPIClient {
        MockAPIClient()
    }

    private var samplePosts: [Post] {[
        Post(id: 1, userId: 1, title: "First Post",  body: "First body"),
        Post(id: 2, userId: 1, title: "Second Post", body: "Second body"),
        Post(id: 3, userId: 2, title: "Third Post",  body: "Third body")
    ]}

    private var samplePost: Post {
        Post(id: 1, userId: 1, title: "Hello", body: "World")
    }

    // MARK: - Successful Requests
    @Suite("Successful Requests")
    struct SuccessfulRequestTests {

        private var samplePosts: [Post] {[
            Post(id: 1, userId: 1, title: "First Post",  body: "First body"),
            Post(id: 2, userId: 1, title: "Second Post", body: "Second body")
        ]}

        @Test("request() returns decoded array on success")
        func requestReturnsDecodedArray() async throws {
            let mock = MockAPIClient()
            mock.registerResponse(samplePosts, for: GetPostsEndpoint.self)

            let posts: [Post] = try await mock.request(GetPostsEndpoint())

            #expect(posts.count == 2)
            #expect(posts[0].title == "First Post")
            #expect(posts[1].title == "Second Post")
        }

        @Test("request() returns single decoded object on success")
        func requestReturnsSingleObject() async throws {
            let mock = MockAPIClient()
            let expected = Post(id: 5, userId: 1, title: "Hello", body: "World")
            mock.registerResponse(expected, for: GetPostEndpoint.self)

            let post: Post = try await mock.request(GetPostEndpoint(id: 5))

            #expect(post.id == 5)
            #expect(post.title == "Hello")
        }

        @Test("requestWithoutResponse() succeeds for DELETE")
        func requestWithoutResponseSucceeds() async throws {
            let mock = MockAPIClient()
            // No response registered — requestWithoutResponse treats this as success

            await #expect(throws: Never.self) {
                try await mock.requestWithoutResponse(DeletePostEndpoint(id: 1))
            }
        }

        @Test("requestData() returns raw Data")
        func requestDataReturnsRawData() async throws {
            let mock = MockAPIClient()
            let json = #"[{"id":1,"userId":1,"title":"Hello","body":"World"}]"#
            let data = json.data(using: .utf8)!
            mock.registerData(data, for: GetPostsEndpoint.self)

            let result = try await mock.requestData(GetPostsEndpoint())

            #expect(result == data)
        }
    }

    // MARK: - Error Handling
    @Suite("Error Handling")
    struct ErrorHandlingTests {

        @Test("request() throws registered NetworkError")
        func requestThrowsRegisteredError() async throws {
            let mock = MockAPIClient()
            mock.registerError(.noInternetConnection, for: GetPostsEndpoint.self)

            await #expect(throws: NetworkError.noInternetConnection) {
                let _: [Post] = try await mock.request(GetPostsEndpoint())
            }
        }

        @Test("request() throws unauthorized when registered")
        func requestThrowsUnauthorized() async throws {
            let mock = MockAPIClient()
            mock.registerError(.unauthorized, for: GetPostsEndpoint.self)

            await #expect(throws: NetworkError.unauthorized) {
                let _: [Post] = try await mock.request(GetPostsEndpoint())
            }
        }

        @Test("request() throws notFound when registered")
        func requestThrowsNotFound() async throws {
            let mock = MockAPIClient()
            mock.registerError(.notFound, for: GetPostEndpoint.self)

            await #expect(throws: NetworkError.notFound) {
                let _: Post = try await mock.request(GetPostEndpoint(id: 999))
            }
        }

        @Test("forcedError overrides all registered responses")
        func forcedErrorOverridesRegisteredResponse() async throws {
            let mock = MockAPIClient()
            let posts = [Post(id: 1, userId: 1, title: "Hello", body: "World")]
            mock.registerResponse(posts, for: GetPostsEndpoint.self)
            mock.forcedError = .timeout  // overrides the registered success

            await #expect(throws: NetworkError.timeout) {
                let _: [Post] = try await mock.request(GetPostsEndpoint())
            }
        }

        @Test("request() throws when no response is registered")
        func requestThrowsWhenNoResponseRegistered() async throws {
            let mock = MockAPIClient()
            // Nothing registered for this endpoint

            await #expect(throws: (any Error).self) {
                let _: [Post] = try await mock.request(GetPostsEndpoint())
            }
        }

        @Test("requestWithoutResponse() throws registered error")
        func requestWithoutResponseThrowsRegisteredError() async throws {
            let mock = MockAPIClient()
            mock.registerError(.serverError(statusCode: 500), for: DeletePostEndpoint.self)

            await #expect(throws: NetworkError.serverError(statusCode: 500)) {
                try await mock.requestWithoutResponse(DeletePostEndpoint(id: 1))
            }
        }
    }

    // MARK: - Call Tracking
    @Suite("Call Tracking")
    struct CallTrackingTests {

        @Test("callCount increments on each request")
        func callCountIncrementsOnEachRequest() async throws {
            let mock = MockAPIClient()
            let posts = [Post(id: 1, userId: 1, title: "Hello", body: "World")]
            mock.registerResponse(posts, for: GetPostsEndpoint.self)

            let _: [Post] = try await mock.request(GetPostsEndpoint())
            let _: [Post] = try await mock.request(GetPostsEndpoint())
            let _: [Post] = try await mock.request(GetPostsEndpoint())

            #expect(mock.callCount == 3)
        }

        @Test("wasCalled is true after request")
        func wasCalledIsTrueAfterRequest() async throws {
            let mock = MockAPIClient()
            let posts = [Post(id: 1, userId: 1, title: "Hello", body: "World")]
            mock.registerResponse(posts, for: GetPostsEndpoint.self)

            #expect(mock.wasCalled == false)
            let _: [Post] = try await mock.request(GetPostsEndpoint())
            #expect(mock.wasCalled == true)
        }

        @Test("wasCalled(with:) tracks correct endpoint type")
        func wasCalledWithTracksCorrectEndpoint() async throws {
            let mock = MockAPIClient()
            let posts = [Post(id: 1, userId: 1, title: "Hello", body: "World")]
            mock.registerResponse(posts, for: GetPostsEndpoint.self)

            let _: [Post] = try await mock.request(GetPostsEndpoint())

            #expect(mock.wasCalled(with: GetPostsEndpoint.self) == true)
            #expect(mock.wasCalled(with: GetPostEndpoint.self) == false)
        }

        @Test("callCount(for:) counts per endpoint type independently")
        func callCountPerEndpointTypeIsIndependent() async throws {
            let mock = MockAPIClient()
            let posts = [Post(id: 1, userId: 1, title: "Hello", body: "World")]
            let post = Post(id: 1, userId: 1, title: "Hello", body: "World")

            mock.registerResponse(posts, for: GetPostsEndpoint.self)
            mock.registerResponse(post,  for: GetPostEndpoint.self)

            let _: [Post] = try await mock.request(GetPostsEndpoint())
            let _: [Post] = try await mock.request(GetPostsEndpoint())
            let _: Post   = try await mock.request(GetPostEndpoint(id: 1))

            #expect(mock.callCount(for: GetPostsEndpoint.self) == 2)
            #expect(mock.callCount(for: GetPostEndpoint.self)  == 1)
        }

        @Test("lastRequest(of:) returns most recent endpoint")
        func lastRequestReturnsCorrectEndpoint() async throws {
            let mock = MockAPIClient()
            let post = Post(id: 1, userId: 1, title: "Hello", body: "World")
            mock.registerResponse(post, for: GetPostEndpoint.self)

            let _: Post = try await mock.request(GetPostEndpoint(id: 1))
            let _: Post = try await mock.request(GetPostEndpoint(id: 7))

            let last = mock.lastRequest(of: GetPostEndpoint.self)
            #expect(last?.id == 7)
        }
    }

    // MARK: - Reset
    @Suite("Reset")
    struct ResetTests {

        @Test("reset() clears call history")
        func resetClearsCallHistory() async throws {
            let mock = MockAPIClient()
            let posts = [Post(id: 1, userId: 1, title: "Hello", body: "World")]
            mock.registerResponse(posts, for: GetPostsEndpoint.self)

            let _: [Post] = try await mock.request(GetPostsEndpoint())
            #expect(mock.callCount == 1)

            mock.reset()
            #expect(mock.callCount == 0)
            #expect(mock.wasCalled == false)
        }

        @Test("reset() clears registered responses")
        func resetClearsRegisteredResponses() async throws {
            let mock = MockAPIClient()
            let posts = [Post(id: 1, userId: 1, title: "Hello", body: "World")]
            mock.registerResponse(posts, for: GetPostsEndpoint.self)
            mock.reset()

            await #expect(throws: (any Error).self) {
                let _: [Post] = try await mock.request(GetPostsEndpoint())
            }
        }

        @Test("reset() clears forced error")
        func resetClearsForcedError() {
            let mock = MockAPIClient()
            mock.forcedError = .timeout
            mock.reset()
            #expect(mock.forcedError == nil)
        }
    }

    // MARK: - Simulated Delay
    @Suite("Simulated Delay")
    struct SimulatedDelayTests {

        @Test("simulatedDelay causes measurable delay")
        func simulatedDelayIsMeasurable() async throws {
            let mock = MockAPIClient()
            let posts = [Post(id: 1, userId: 1, title: "Hello", body: "World")]
            mock.registerResponse(posts, for: GetPostsEndpoint.self)
            mock.simulatedDelay = 0.2

            let start = Date()
            let _: [Post] = try await mock.request(GetPostsEndpoint())
            let elapsed = Date().timeIntervalSince(start)

            #expect(elapsed >= 0.2)
        }
    }
}
