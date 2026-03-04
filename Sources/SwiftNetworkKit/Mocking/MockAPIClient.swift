//
//  MockAPIClient.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Foundation

// MARK: - MockAPIClient
/// A test double for APIClientProtocol.
/// Use this in unit tests and SwiftUI Previews instead of the real APIClient.
/// Supports configurable success responses, errors, delays, and call tracking.
///
/// Example:
/// ```swift
/// let mock = MockAPIClient()
/// mock.registerResponse([Post(id: 1, title: "Test")], for: GetPostsEndpoint.self)
/// let vm = PostsViewModel(client: mock)
/// ```
public final class MockAPIClient: APIClientProtocol {

    // MARK: - Response Registry
    /// Stores mock responses keyed by endpoint type name.
    /// Value is either a Decodable result or a NetworkError.
    private var responseRegistry: [String: Result<Any, NetworkError>] = [:]

    /// Stores raw Data responses keyed by endpoint type name.
    private var dataRegistry: [String: Data] = [:]

    // MARK: - Call Tracking
    /// Records every endpoint that was requested — useful for assertions in tests.
    public private(set) var requestedEndpoints: [any Endpoint] = []

    /// Total number of requests made to this mock.
    public var callCount: Int { requestedEndpoints.count }

    /// Returns true if at least one request has been made.
    public var wasCalled: Bool { !requestedEndpoints.isEmpty }

    // MARK: - Configuration
    /// Optional delay to simulate network latency (in seconds).
    public var simulatedDelay: TimeInterval = 0

    /// If true, every request throws this error regardless of registered responses.
    public var forcedError: NetworkError?

    // MARK: - Init
    public init() {}

    // MARK: - APIClientProtocol

    public func request<T: Decodable>(_ endpoint: some Endpoint) async throws -> T {
        try await recordAndDelay(endpoint)

        // Forced error overrides everything
        if let error = forcedError { throw error }

        let key = endpointKey(endpoint)

        // Check registry for a registered response
        guard let result = responseRegistry[key] else {
            throw NetworkError.unknown(
                MockError.noResponseRegistered(endpointType: key)
            )
        }

        switch result {
        case .success(let value):
            guard let typed = value as? T else {
                throw NetworkError.decodingFailed(
                    MockError.typeMismatch(
                        expected: String(describing: T.self),
                        received: String(describing: type(of: value))
                    )
                )
            }
            return typed

        case .failure(let error):
            throw error
        }
    }

    public func requestWithoutResponse(_ endpoint: some Endpoint) async throws {
        try await recordAndDelay(endpoint)
        if let error = forcedError { throw error }

        let key = endpointKey(endpoint)
        if let result = responseRegistry[key], case .failure(let error) = result {
            throw error
        }
        // No error registered — treat as success
    }

    public func requestData(_ endpoint: some Endpoint) async throws -> Data {
        try await recordAndDelay(endpoint)
        if let error = forcedError { throw error }

        let key = endpointKey(endpoint)

        if let data = dataRegistry[key] { return data }

        throw NetworkError.unknown(
            MockError.noResponseRegistered(endpointType: key)
        )
    }
}

// MARK: - Response Registration
public extension MockAPIClient {

    /// Registers a success response for a specific endpoint type.
    /// - Parameters:
    ///   - response: The value to return when this endpoint is requested.
    ///   - endpointType: The Endpoint type to match against.
    func registerResponse<T, E: Endpoint>(_ response: T, for endpointType: E.Type) {
        let key = String(describing: endpointType)
        responseRegistry[key] = .success(response)
    }

    /// Registers an error response for a specific endpoint type.
    /// - Parameters:
    ///   - error: The NetworkError to throw when this endpoint is requested.
    ///   - endpointType: The Endpoint type to match against.
    func registerError<E: Endpoint>(_ error: NetworkError, for endpointType: E.Type) {
        let key = String(describing: endpointType)
        responseRegistry[key] = .failure(error)
    }

    /// Registers raw Data for a specific endpoint type.
    /// Used with requestData().
    func registerData<E: Endpoint>(_ data: Data, for endpointType: E.Type) {
        let key = String(describing: endpointType)
        dataRegistry[key] = data
    }

    /// Removes all registered responses, data, and tracked calls.
    /// Call this in setUp() between tests.
    func reset() {
        responseRegistry.removeAll()
        dataRegistry.removeAll()
        requestedEndpoints.removeAll()
        forcedError = nil
        simulatedDelay = 0
    }
}

// MARK: - Call Verification
public extension MockAPIClient {

    /// Returns true if the given endpoint type was ever requested.
    func wasCalled<E: Endpoint>(with endpointType: E.Type) -> Bool {
        requestedEndpoints.contains { type(of: $0) == endpointType }
    }

    /// Returns the number of times a specific endpoint type was requested.
    func callCount<E: Endpoint>(for endpointType: E.Type) -> Int {
        requestedEndpoints.filter { type(of: $0) == endpointType }.count
    }

    /// Returns the last endpoint of a specific type that was requested.
    func lastRequest<E: Endpoint>(of type: E.Type) -> E? {
        requestedEndpoints.last { $0 is E } as? E
    }
}

// MARK: - Private Helpers
private extension MockAPIClient {

    /// Records the endpoint call and applies simulated delay.
    func recordAndDelay(_ endpoint: some Endpoint) async throws {
        requestedEndpoints.append(endpoint)

        if simulatedDelay > 0 {
            let nanoseconds = UInt64(simulatedDelay * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)
        }
    }

    /// Generates a stable key from the endpoint type name.
    func endpointKey(_ endpoint: some Endpoint) -> String {
        String(describing: type(of: endpoint))
    }
}

// MARK: - MockError
/// Internal errors specific to mock misconfiguration.
/// Surfaces as NetworkError.unknown in tests to help debug setup issues.
public enum MockError: LocalizedError {

    case noResponseRegistered(endpointType: String)
    case typeMismatch(expected: String, received: String)

    public var errorDescription: String? {
        switch self {
        case .noResponseRegistered(let type):
            return "MockAPIClient: No response registered for '\(type)'. Call registerResponse(_:for:) in your test setUp."
        case .typeMismatch(let expected, let received):
            return "MockAPIClient: Type mismatch — expected '\(expected)' but received '\(received)'."
        }
    }
}
