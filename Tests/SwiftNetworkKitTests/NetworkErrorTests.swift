//
//  NetworkErrorTests.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Testing
import Foundation
@testable import SwiftNetworkKit

// MARK: - NetworkErrorTests
@Suite("NetworkError Tests")
struct NetworkErrorTests {

    // MARK: - HTTP Status Code Mapping
    @Suite("HTTP Status Code Mapping")
    struct HTTPStatusCodeMappingTests {

        @Test("200 range returns nil — no error on success")
        func successStatusCodesReturnNil() {
            let successCodes = [200, 201, 204, 299]
            for code in successCodes {
                #expect(NetworkError.mapHTTPStatusCode(code) == nil,
                    "Expected nil for status code \(code)")
            }
        }

        @Test("401 maps to unauthorized")
        func unauthorizedStatusCode() {
            let error = NetworkError.mapHTTPStatusCode(401)
            #expect(error == .unauthorized)
        }

        @Test("403 maps to forbidden")
        func forbiddenStatusCode() {
            let error = NetworkError.mapHTTPStatusCode(403)
            #expect(error == .forbidden)
        }

        @Test("404 maps to notFound")
        func notFoundStatusCode() {
            let error = NetworkError.mapHTTPStatusCode(404)
            #expect(error == .notFound)
        }

        @Test("409 maps to conflict")
        func conflictStatusCode() {
            let error = NetworkError.mapHTTPStatusCode(409)
            #expect(error == .conflict)
        }

        @Test("422 maps to unprocessableEntity")
        func unprocessableEntityStatusCode() {
            let error = NetworkError.mapHTTPStatusCode(422)
            #expect(error == .unprocessableEntity)
        }

        @Test("429 maps to tooManyRequests")
        func tooManyRequestsStatusCode() {
            let error = NetworkError.mapHTTPStatusCode(429)
            #expect(error == .tooManyRequests)
        }

        @Test("500 range maps to serverError with correct code",
              arguments: [500, 502, 503, 504, 599])
        func serverErrorStatusCodes(code: Int) {
            let error = NetworkError.mapHTTPStatusCode(code)
            if case .serverError(let statusCode) = error {
                #expect(statusCode == code)
            } else {
                Issue.record("Expected .serverError for status code \(code)")
            }
        }

        @Test("Unexpected status code maps to unexpectedStatusCode")
        func unexpectedStatusCode() {
            let error = NetworkError.mapHTTPStatusCode(418)  // I'm a teapot 🫖
            if case .unexpectedStatusCode(let code) = error {
                #expect(code == 418)
            } else {
                Issue.record("Expected .unexpectedStatusCode for 418")
            }
        }
    }

    // MARK: - URL Error Mapping
    @Suite("URL Error Mapping")
    struct URLErrorMappingTests {

        @Test("notConnectedToInternet maps to noInternetConnection")
        func notConnectedMapsToNoInternet() {
            let urlError = URLError(.notConnectedToInternet)
            let error = NetworkError.mapURLError(urlError)
            #expect(error == .noInternetConnection)
        }

        @Test("networkConnectionLost maps to noInternetConnection")
        func connectionLostMapsToNoInternet() {
            let urlError = URLError(.networkConnectionLost)
            let error = NetworkError.mapURLError(urlError)
            #expect(error == .noInternetConnection)
        }

        @Test("timedOut maps to timeout")
        func timedOutMapsToTimeout() {
            let urlError = URLError(.timedOut)
            let error = NetworkError.mapURLError(urlError)
            #expect(error == .timeout)
        }

        @Test("cancelled maps to cancelled")
        func cancelledMapsToCancelled() {
            let urlError = URLError(.cancelled)
            let error = NetworkError.mapURLError(urlError)
            #expect(error == .cancelled)
        }

        @Test("unknown URLError maps to unknown NetworkError")
        func unknownURLErrorMapsToUnknown() {
            let urlError = URLError(.badURL)
            let error = NetworkError.mapURLError(urlError)
            if case .unknown = error {
                // pass
            } else {
                Issue.record("Expected .unknown for unhandled URLError")
            }
        }
    }

    // MARK: - Localized Error Descriptions
    @Suite("Localized Error Descriptions")
    struct LocalizedDescriptionTests {

        @Test("invalidURL has non-empty description")
        func invalidURLDescription() {
            let error = NetworkError.invalidURL
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.isEmpty == false)
        }

        @Test("unauthorized has non-empty description")
        func unauthorizedDescription() {
            let error = NetworkError.unauthorized
            #expect(error.errorDescription != nil)
            #expect(error.errorDescription?.isEmpty == false)
        }

        @Test("serverError includes status code in description")
        func serverErrorDescriptionIncludesCode() {
            let error = NetworkError.serverError(statusCode: 503)
            #expect(error.errorDescription?.contains("503") == true)
        }

        @Test("decodingFailed includes underlying error in description")
        func decodingFailedDescription() {
            let underlying = NSError(domain: "test", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "missing key"])
            let error = NetworkError.decodingFailed(underlying)
            #expect(error.errorDescription?.contains("missing key") == true)
        }

        @Test("All error cases have non-empty descriptions")
        func allCasesHaveDescriptions() {
            let errors: [NetworkError] = [
                .invalidURL,
                .invalidRequest,
                .noInternetConnection,
                .timeout,
                .cancelled,
                .unauthorized,
                .forbidden,
                .notFound,
                .conflict,
                .unprocessableEntity,
                .tooManyRequests,
                .serverError(statusCode: 500),
                .noData,
                .decodingFailed(NSError(domain: "test", code: 0)),
                .encodingFailed(NSError(domain: "test", code: 0)),
                .unknown(NSError(domain: "test", code: 0))
            ]

            for error in errors {
                #expect(
                    error.errorDescription?.isEmpty == false,
                    "Expected non-empty description for \(error)"
                )
            }
        }
    }

    // MARK: - Equatability
    @Suite("Error Equatability")
    struct EquatabilityTests {

        @Test("Same simple cases are equal")
        func simpleCasesAreEqual() {
            #expect(NetworkError.unauthorized == NetworkError.unauthorized)
            #expect(NetworkError.notFound == NetworkError.notFound)
            #expect(NetworkError.timeout == NetworkError.timeout)
        }

        @Test("Different cases are not equal")
        func differentCasesAreNotEqual() {
            #expect(NetworkError.unauthorized != NetworkError.forbidden)
            #expect(NetworkError.timeout != NetworkError.cancelled)
        }

        @Test("serverError with same code are equal")
        func serverErrorSameCodeEqual() {
            #expect(NetworkError.serverError(statusCode: 500) ==
                    NetworkError.serverError(statusCode: 500))
        }

        @Test("serverError with different codes are not equal")
        func serverErrorDifferentCodesNotEqual() {
            #expect(NetworkError.serverError(statusCode: 500) !=
                    NetworkError.serverError(statusCode: 503))
        }
    }
}
