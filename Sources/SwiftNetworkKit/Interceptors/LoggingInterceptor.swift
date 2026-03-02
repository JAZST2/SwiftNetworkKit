//
//  LoggingInterceptor.swift
//  SwiftNetworkKit
//
//  Created by Mark Justine Evasco on 2/21/26.
//

import Foundation
import OSLog

// MARK: - Log Level
public enum LogLevel {
    case none
    case minimal
    case verbose
}

// MARK: - LoggingInterceptor
public final class LoggingInterceptor: InterceptorProtocol {

    // MARK: - Properties
    private let level: LogLevel
    private let logger = Logger(subsystem: "SwiftNetworkKit", category: "Network")

    private var startTimes: [String: Date] = [:]

    // MARK: - Init
    public init(level: LogLevel = .verbose) {
        self.level = level
    }

    // MARK: - InterceptorProtocol
    public func intercept(_ request: URLRequest) async throws -> URLRequest {
        guard level != .none else { return request }

        let key = request.url?.absoluteString ?? "unknown"
        startTimes[key] = Date()

        switch level {
        case .none:
            break

        case .minimal:
            let method = request.httpMethod ?? "UNKNOWN"
            let url = request.url?.absoluteString ?? "nil"
            logger.info("➡️  \(method) \(url)")

        case .verbose:
            logRequest(request)
        }

        return request
    }

    public func intercept(
        response: URLResponse,
        data: Data,
        for request: URLRequest
    ) async throws -> Data {
        guard level != .none else { return data }

        let key = request.url?.absoluteString ?? "unknown"
        let duration = startTimes[key].map { Date().timeIntervalSince($0) }
        startTimes.removeValue(forKey: key)

        let durationString = duration.map { String(format: "%.0fms", $0 * 1000) } ?? "?ms"

        switch level {
        case .none:
            break

        case .minimal:
            if let http = response as? HTTPURLResponse {
                let emoji = http.statusCode < 400 ? "✅" : "❌"
                logger.info("\(emoji)  \(http.statusCode) — \(durationString)")
            }

        case .verbose:
            logResponse(response, data: data, duration: durationString)
        }

        return data
    }
}

// MARK: - Private Logging Helpers
private extension LoggingInterceptor {

    func logRequest(_ request: URLRequest) {
        var lines: [String] = []
        lines.append("┌─────────────────────────────────────────")
        lines.append("│ ➡️  REQUEST")
        lines.append("│ \(request.httpMethod ?? "UNKNOWN") \(request.url?.absoluteString ?? "nil")")

        if let headers = request.allHTTPHeaderFields, !headers.isEmpty {
            lines.append("│ Headers: \(headers)")
        }

        if let body = request.httpBody,
           let bodyString = String(data: body, encoding: .utf8) {
            lines.append("│ Body: \(bodyString)")
        }

        lines.append("└─────────────────────────────────────────")
        logger.info("\(lines.joined(separator: "\n"))")
    }

    func logResponse(_ response: URLResponse, data: Data, duration: String) {
        var lines: [String] = []
        lines.append("┌─────────────────────────────────────────")

        if let http = response as? HTTPURLResponse {
            let emoji = http.statusCode < 400 ? "✅" : "❌"
            let status = HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            lines.append("│ \(emoji)  RESPONSE")
            lines.append("│ \(http.statusCode) \(status.capitalized) — \(duration)")

            if let headers = http.allHeaderFields as? [String: String], !headers.isEmpty {
                lines.append("│ Headers: \(headers)")
            }
        }

        if !data.isEmpty {
            if let bodyString = String(data: data, encoding: .utf8) {
                // Truncate large responses to avoid flooding the console
                let truncated = bodyString.count > 500
                    ? String(bodyString.prefix(500)) + "... (truncated)"
                    : bodyString
                lines.append("│ Body: \(truncated)")
            }
        } else {
            lines.append("│ Body: empty")
        }

        lines.append("└─────────────────────────────────────────")
        logger.info("\(lines.joined(separator: "\n"))")
    }
}
