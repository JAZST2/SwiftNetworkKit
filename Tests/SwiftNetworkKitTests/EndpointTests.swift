//
//  EndpointTests.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Testing
import Foundation
@testable import SwiftNetworkKit

// MARK: - Test Endpoints
/// Local endpoint definitions used only for testing.
/// Keeps tests self-contained without depending on app-level endpoints.

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

private struct GetPostsByUserEndpoint: Endpoint {
    let userId: Int
    var baseURL    = "https://jsonplaceholder.typicode.com"
    var path       = "/posts"
    var method     = HTTPMethod.GET
    var queryItems: [URLQueryItem]? {
        [URLQueryItem(name: "userId", value: "\(userId)")]
    }
}

private struct CreatePostRequest: Codable {
    let title: String
    let body: String
    let userId: Int
}

private struct CreatePostEndpoint: Endpoint {
    let post: CreatePostRequest
    var baseURL = "https://jsonplaceholder.typicode.com"
    var path    = "/posts"
    var method  = HTTPMethod.POST
    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }
    var body: Data? { encode(post) }
}

private struct DeletePostEndpoint: Endpoint {
    let id: Int
    var baseURL     = "https://jsonplaceholder.typicode.com"
    var path: String { "/posts/\(id)" }
    var method      = HTTPMethod.DELETE
}

private struct SlowEndpoint: Endpoint {
    var baseURL          = "https://jsonplaceholder.typicode.com"
    var path             = "/posts"
    var method           = HTTPMethod.GET
    var timeoutInterval  = 60.0
}

private struct MultiQueryEndpoint: Endpoint {
    var baseURL    = "https://jsonplaceholder.typicode.com"
    var path       = "/posts"
    var method     = HTTPMethod.GET
    var queryItems: [URLQueryItem]? {[
        URLQueryItem(name: "userId", value: "1"),
        URLQueryItem(name: "_limit", value: "10"),
        URLQueryItem(name: "_page",  value: "2")
    ]}
}

// MARK: - EndpointTests
@Suite("Endpoint Tests")
struct EndpointTests {

    let builder = URLRequestBuilder.jsonBuilder

    // MARK: - Default Values
    @Suite("Default Values")
    struct DefaultValueTests {

        @Test("Default headers are nil")
        func defaultHeadersAreNil() {
            let endpoint = GetPostsEndpoint()
            #expect(endpoint.headers == nil)
        }

        @Test("Default query items are nil")
        func defaultQueryItemsAreNil() {
            let endpoint = GetPostsEndpoint()
            #expect(endpoint.queryItems == nil)
        }

        @Test("Default body is nil")
        func defaultBodyIsNil() {
            let endpoint = GetPostsEndpoint()
            #expect(endpoint.body == nil)
        }

        @Test("Default timeout is 30 seconds")
        func defaultTimeoutIs30Seconds() {
            let endpoint = GetPostsEndpoint()
            #expect(endpoint.timeoutInterval == 30.0)
        }

        @Test("Custom timeout is respected")
        func customTimeoutIsRespected() {
            let endpoint = SlowEndpoint()
            #expect(endpoint.timeoutInterval == 60.0)
        }
    }

    // MARK: - URL Construction
    @Suite("URL Construction")
    struct URLConstructionTests {

        let builder = URLRequestBuilder.jsonBuilder

        @Test("Simple GET builds correct URL")
        func simpleGETBuildsCorrectURL() throws {
            let request = try builder.build(from: GetPostsEndpoint())
            #expect(request.url?.absoluteString == "https://jsonplaceholder.typicode.com/posts")
        }

        @Test("Dynamic path builds correct URL")
        func dynamicPathBuildsCorrectURL() throws {
            let request = try builder.build(from: GetPostEndpoint(id: 5))
            #expect(request.url?.absoluteString == "https://jsonplaceholder.typicode.com/posts/5")
        }

        @Test("Query items are appended to URL")
        func queryItemsAreAppendedToURL() throws {
            let request = try builder.build(from: GetPostsByUserEndpoint(userId: 3))
            let url = request.url?.absoluteString ?? ""
            #expect(url.contains("userId=3"))
        }

        @Test("Multiple query items are all appended")
        func multipleQueryItemsAreAppended() throws {
            let request = try builder.build(from: MultiQueryEndpoint())
            let url = request.url?.absoluteString ?? ""
            #expect(url.contains("userId=1"))
            #expect(url.contains("_limit=10"))
            #expect(url.contains("_page=2"))
        }

        @Test("Invalid base URL throws invalidURL")
        func invalidBaseURLThrowsError() {
            struct BadEndpoint: Endpoint {
                var baseURL = "not a valid url @@##"
                var path    = "/posts"
                var method  = HTTPMethod.GET
            }
            #expect(throws: NetworkError.invalidURL) {
                try URLRequestBuilder.jsonBuilder.build(from: BadEndpoint())
            }
        }

        @Test("Empty base URL throws invalidURL")
        func emptyBaseURLThrowsError() {
            struct EmptyBaseEndpoint: Endpoint {
                var baseURL = ""
                var path    = "/posts"
                var method  = HTTPMethod.GET
            }
            #expect(throws: NetworkError.invalidURL) {
                try URLRequestBuilder.jsonBuilder.build(from: EmptyBaseEndpoint())
            }
        }
    }

    // MARK: - HTTP Method
    @Suite("HTTP Method")
    struct HTTPMethodTests {

        let builder = URLRequestBuilder.jsonBuilder

        @Test("GET method is set correctly")
        func getMethodIsSetCorrectly() throws {
            let request = try builder.build(from: GetPostsEndpoint())
            #expect(request.httpMethod == "GET")
        }

        @Test("POST method is set correctly")
        func postMethodIsSetCorrectly() throws {
            let post = CreatePostRequest(title: "Test", body: "Body", userId: 1)
            let request = try builder.build(from: CreatePostEndpoint(post: post))
            #expect(request.httpMethod == "POST")
        }

        @Test("DELETE method is set correctly")
        func deleteMethodIsSetCorrectly() throws {
            let request = try builder.build(from: DeletePostEndpoint(id: 1))
            #expect(request.httpMethod == "DELETE")
        }

        @Test("GET with body throws invalidRequest")
        func getWithBodyThrowsInvalidRequest() {
            struct InvalidGetEndpoint: Endpoint {
                var baseURL = "https://jsonplaceholder.typicode.com"
                var path    = "/posts"
                var method  = HTTPMethod.GET
                var body: Data? { "body".data(using: .utf8) }
            }
            #expect(throws: NetworkError.invalidRequest) {
                try URLRequestBuilder.jsonBuilder.build(from: InvalidGetEndpoint())
            }
        }

        @Test("HEAD with body throws invalidRequest")
        func headWithBodyThrowsInvalidRequest() {
            struct InvalidHeadEndpoint: Endpoint {
                var baseURL = "https://jsonplaceholder.typicode.com"
                var path    = "/posts"
                var method  = HTTPMethod.HEAD
                var body: Data? { "body".data(using: .utf8) }
            }
            #expect(throws: NetworkError.invalidRequest) {
                try URLRequestBuilder.jsonBuilder.build(from: InvalidHeadEndpoint())
            }
        }
    }

    // MARK: - Headers
    @Suite("Headers")
    struct HeaderTests {

        @Test("Default JSON headers are applied")
        func defaultJSONHeadersAreApplied() throws {
            let request = try URLRequestBuilder.jsonBuilder.build(from: GetPostsEndpoint())
            #expect(request.allHTTPHeaderFields?["Content-Type"] == "application/json")
            #expect(request.allHTTPHeaderFields?["Accept"] == "application/json")
        }

        @Test("Endpoint headers are merged with default headers")
        func endpointHeadersMergeWithDefaults() throws {
            let post = CreatePostRequest(title: "Test", body: "Body", userId: 1)
            let request = try URLRequestBuilder.jsonBuilder.build(from: CreatePostEndpoint(post: post))
            #expect(request.allHTTPHeaderFields?["Content-Type"] == "application/json")
            #expect(request.allHTTPHeaderFields?["Accept"] == "application/json")
        }

        @Test("Endpoint header overrides default header")
        func endpointHeaderOverridesDefault() throws {
            struct CustomContentTypeEndpoint: Endpoint {
                var baseURL = "https://jsonplaceholder.typicode.com"
                var path    = "/upload"
                var method  = HTTPMethod.POST
                var headers: [String: String]? {
                    ["Content-Type": "multipart/form-data"]
                }
                var body: Data? { Data() }
            }
            let request = try URLRequestBuilder.jsonBuilder.build(from: CustomContentTypeEndpoint())
            #expect(request.allHTTPHeaderFields?["Content-Type"] == "multipart/form-data")
        }
    }

    // MARK: - Request Body
    @Suite("Request Body")
    struct RequestBodyTests {

        @Test("POST body is encoded correctly")
        func postBodyIsEncodedCorrectly() throws {
            let post = CreatePostRequest(title: "Hello", body: "World", userId: 1)
            let endpoint = CreatePostEndpoint(post: post)
            let request = try URLRequestBuilder.jsonBuilder.build(from: endpoint)

            #expect(request.httpBody != nil)

            let decoded = try JSONDecoder().decode(CreatePostRequest.self, from: request.httpBody!)
            #expect(decoded.title == "Hello")
            #expect(decoded.body == "World")
            #expect(decoded.userId == 1)
        }

        @Test("GET request has no body")
        func getRequestHasNoBody() throws {
            let request = try URLRequestBuilder.jsonBuilder.build(from: GetPostsEndpoint())
            #expect(request.httpBody == nil)
        }

        @Test("encode() helper produces valid JSON data")
        func encodeHelperProducesValidJSON() {
            let endpoint = CreatePostEndpoint(
                post: CreatePostRequest(title: "Test", body: "Body", userId: 1)
            )
            #expect(endpoint.body != nil)
            #expect(endpoint.body?.isEmpty == false)
        }
    }

    // MARK: - Timeout
    @Suite("Timeout")
    struct TimeoutTests {

        @Test("Default timeout is set on request")
        func defaultTimeoutIsSet() throws {
            let request = try URLRequestBuilder.jsonBuilder.build(from: GetPostsEndpoint())
            #expect(request.timeoutInterval == 30.0)
        }

        @Test("Custom timeout is set on request")
        func customTimeoutIsSet() throws {
            let request = try URLRequestBuilder.jsonBuilder.build(from: SlowEndpoint())
            #expect(request.timeoutInterval == 60.0)
        }
    }
}
