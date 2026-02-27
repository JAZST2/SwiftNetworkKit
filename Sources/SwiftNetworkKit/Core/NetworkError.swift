//
//  NetworkError.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Foundation

public enum NetworkError: Error {
    
    case invalidURL
    case invalidRequest
    
    case noInternetConnection
    case timeout
    case cancelled
    
    case unauthorized
    case forbidden
    case notFound
    case conflict
    case unprocessableEntity
    case tooManyRequests
    case serverError(statusCode: Int)
    case unexpectedStatusCode(statusCode: Int)
    
    case noData
    case decodingFailed(Error)
    case encodingFailed(Error)
    
    case unknown(Error)
}

extension NetworkError: LocalizedError {
    
    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "The URL is invalid. Please check the endpoint configuration."
        case .invalidRequest:
            return "The request is malformed or missing required fields."
        case .noInternetConnection:
            return "No internet connection. Please check your network settings."
        case .timeout:
            return "The request timed out. Please try again."
        case .cancelled:
            return "The request was cancelled."
        case .unauthorized:
            return "You are not authorized. Please log in and try again."
        case .forbidden:
            return "You don't have permission to access this resource."
        case .notFound:
            return "The requested resource could not be found."
        case .conflict:
            return "There was a conflict with the current state of the resource."
        case .unprocessableEntity:
            return "The server could not process the request."
        case .tooManyRequests:
            return "Too many requests. Please slow down and try again later."
        case .serverError(let code):
            return "A server error occurred (status code: \(code))."
        case .unexpectedStatusCode(let code):
            return "Unexpected response from server (status code: \(code))."
        case .noData:
            return "No data was returned from the server."
        case .decodingFailed(let error):
            return "Failed to decode the response: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode the request body: \(error.localizedDescription)"
        case .unknown(let error):
            return "An unknown error occurred: \(error.localizedDescription)"
        }
    }
}

extension NetworkError {

    static func mapHTTPStatusCode(_ statusCode: Int) -> NetworkError? {
        switch statusCode {
        case 200...299: return nil
        case 401:       return .unauthorized
        case 403:       return .forbidden
        case 404:       return .notFound
        case 409:       return .conflict
        case 422:       return .unprocessableEntity
        case 429:       return .tooManyRequests
        case 500...599: return .serverError(statusCode: statusCode)
        default:        return .unexpectedStatusCode(statusCode: statusCode)
        }
    }
    
    static func mapURLError(_ urlError: URLError) -> NetworkError {
        switch urlError.code {
        case .notConnectedToInternet,
             .networkConnectionLost:    return .noInternetConnection
        case .timedOut:                 return .timeout
        case .cancelled:                return .cancelled
        default:                        return .unknown(urlError)
        }
    }
}
