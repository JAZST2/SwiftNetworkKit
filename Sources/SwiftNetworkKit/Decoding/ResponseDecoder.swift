//
//  ResponseDecoder.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Foundation

// MARK: - Decoding Strategy
public enum DecodingStrategy {
    
    case useDefaultKeys
    
    case convertFromSnakeCase

    case custom(([CodingKey]) -> CodingKey)
}

// MARK: - ResponseDecoder
public struct ResponseDecoder {

    // MARK: - Properties
    private let decoder: JSONDecoder

    // MARK: - Init
    public init(strategy: DecodingStrategy = .convertFromSnakeCase) {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = strategy.jsonDecoderStrategy
        decoder.dateDecodingStrategy = .iso8601   // handles ISO 8601 dates out of the box
        self.decoder = decoder
    }

    // MARK: - Decode
    public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        if T.self == EmptyResponse.self, let empty = EmptyResponse() as? T {
            return empty
        }

        guard !data.isEmpty else {
            throw NetworkError.noData
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch let decodingError as DecodingError {
            throw NetworkError.decodingFailed(decodingError.readable)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
    
    public func decode<T: Decodable>(_ type: T.Type, from data: Data, keyPath: String) throws -> T {
        guard !data.isEmpty else { throw NetworkError.noData }

        do {
            // First decode into a generic dictionary
            let json = try JSONSerialization.jsonObject(with: data)

            // Navigate to the nested key
            guard let nested = (json as? [String: Any])?[keyPath] else {
                throw NetworkError.decodingFailed(
                    DecodingStrategyError.keyPathNotFound(keyPath)
                )
            }

            // Re-encode the nested object and decode into T
            let nestedData = try JSONSerialization.data(withJSONObject: nested)
            return try decoder.decode(T.self, from: nestedData)

        } catch let error as NetworkError {
            throw error
        } catch let decodingError as DecodingError {
            throw NetworkError.decodingFailed(decodingError.readable)
        } catch {
            throw NetworkError.decodingFailed(error)
        }
    }
}

// MARK: - DecodingStrategy → JSONDecoder.KeyDecodingStrategy
private extension DecodingStrategy {

    var jsonDecoderStrategy: JSONDecoder.KeyDecodingStrategy {
        switch self {
        case .useDefaultKeys:
            return .useDefaultKeys
        case .convertFromSnakeCase:
            return .convertFromSnakeCase
        case .custom(let closure):
            return .custom(closure)
        }
    }
}

// MARK: - DecodingError Readable Message
/// Makes DecodingError messages human readable for easier debugging.
private extension DecodingError {

    var readable: Error {
        switch self {
        case .typeMismatch(let type, let ctx):
            return SimpleError("Type mismatch for \(type): \(ctx.debugDescription)")
        case .valueNotFound(let type, let ctx):
            return SimpleError("Value not found for \(type): \(ctx.debugDescription)")
        case .keyNotFound(let key, let ctx):
            return SimpleError("Key '\(key.stringValue)' not found: \(ctx.debugDescription)")
        case .dataCorrupted(let ctx):
            return SimpleError("Data corrupted: \(ctx.debugDescription)")
        @unknown default:
            return self
        }
    }
}

// MARK: - Supporting Types
private struct SimpleError: LocalizedError {
    let errorDescription: String?
    init(_ message: String) { self.errorDescription = message }
}

private enum DecodingStrategyError: LocalizedError {
    case keyPathNotFound(String)
    var errorDescription: String? {
        switch self {
        case .keyPathNotFound(let key):
            return "Key path '\(key)' was not found in the JSON response."
        }
    }
}
