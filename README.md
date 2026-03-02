# SwiftNetworkKit

A production-ready, async/await-based networking layer for iOS, macOS, tvOS, and watchOS. Built with protocol-oriented design, full interceptor support, and testability in mind.

---

## Features

- Async/Await native networking using `URLSession`
- Protocol-oriented and fully testable via `APIClientProtocol`
- Typed error handling with `NetworkError`
- Pluggable interceptor pipeline (Logging, Auth, Retry)
- Automatic snake_case → camelCase JSON decoding
- Key path decoding for nested JSON responses
- Automatic token refresh with concurrent refresh protection
- Exponential backoff retry with jitter
- Zero third-party dependencies

---

## Requirements

| Platform | Minimum Version |
|----------|----------------|
| iOS      | 15.0+          |
| macOS    | 12.0+          |
| tvOS     | 15.0+          |
| watchOS  | 8.0+           |
| Swift    | 5.9+           |

---

## Installation

### Swift Package Manager

In `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/JAZST2/SwiftNetworkKit.git", from: "1.0.0")
]
```

Or in Xcode: **File → Add Package Dependencies** and enter the repository URL.

---

## Project Structure

```
Sources/SwiftNetworkKit/
├── Core/
│   ├── APIClient.swift
│   ├── APIClientProtocol.swift
│   ├── Endpoint.swift
│   ├── HTTPMethod.swift
│   └── NetworkError.swift
├── RequestBuilder/
│   └── URLRequestBuilder.swift
├── Decoding/
│   └── ResponseDecoder.swift
└── Interceptors/
    ├── InterceptorProtocol.swift
    ├── LoggingInterceptor.swift
    ├── AuthInjectorInterceptor.swift
    └── RetryInterceptor.swift
```

---

## Quick Start

### 1. Define a Model

```swift
struct Post: Decodable, Identifiable {
    let id: Int
    let userId: Int
    let title: String
    let body: String
}
```

### 2. Define an Endpoint

```swift
struct GetPostsEndpoint: Endpoint {
    var baseURL = "https://jsonplaceholder.typicode.com"
    var path    = "/posts"
    var method  = HTTPMethod.GET
}
```

### 3. Create a Client

```swift
let client = APIClient()
```

### 4. Make a Request

```swift
let posts: [Post] = try await client.request(GetPostsEndpoint())
```

---

## Core Components

### HTTPMethod

Type-safe HTTP verb definitions backed by `String` raw values.

```swift
public enum HTTPMethod: String {
    case GET, POST, PUT, DELETE, PATCH, HEAD
}
```

**Usage:**

```swift
var method: HTTPMethod = .GET
// Internally: request.httpMethod = method.rawValue → "GET"
```

---

### NetworkError

Unified typed error system. Every error in the library maps to a `NetworkError` case. Conforms to `LocalizedError` for user-facing messages.

```swift
public enum NetworkError: Error {
    case invalidURL
    case invalidRequest
    case noInternetConnection
    case timeout
    case cancelled
    case unauthorized           // 401
    case forbidden              // 403
    case notFound               // 404
    case conflict               // 409
    case unprocessableEntity    // 422
    case tooManyRequests        // 429
    case serverError(statusCode: Int)
    case unexpectedStatusCode(Int)
    case noData
    case decodingFailed(Error)
    case encodingFailed(Error)
    case unknown(Error)
}
```

**Usage in ViewModel:**

```swift
do {
    posts = try await client.request(GetPostsEndpoint())
} catch let error as NetworkError {
    switch error {
    case .noInternetConnection:
        showBanner("Check your connection")
    case .unauthorized:
        navigateToLogin()
    case .serverError(let code):
        showBanner("Server error: \(code)")
    default:
        errorMessage = error.localizedDescription
    }
}
```

**HTTP Status Code Mapping:**

```swift
NetworkError.mapHTTPStatusCode(401) // → .unauthorized
NetworkError.mapHTTPStatusCode(503) // → .serverError(statusCode: 503)
NetworkError.mapHTTPStatusCode(200) // → nil (success)
```

---

### Endpoint

Protocol that describes everything needed to construct a `URLRequest`. Define one struct per API call.

```swift
public protocol Endpoint {
    var baseURL: String { get }
    var path: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }       // default: nil
    var queryItems: [URLQueryItem]? { get }       // default: nil
    var body: Data? { get }                       // default: nil
    var timeoutInterval: TimeInterval { get }     // default: 30.0
}
```

**Examples:**

```swift
// Simple GET
struct GetPostsEndpoint: Endpoint {
    var baseURL = "https://jsonplaceholder.typicode.com"
    var path    = "/posts"
    var method  = HTTPMethod.GET
}

// Dynamic path
struct GetPostEndpoint: Endpoint {
    let id: Int
    var baseURL     = "https://jsonplaceholder.typicode.com"
    var path: String { "/posts/\(id)" }
    var method      = HTTPMethod.GET
}

// With query parameters
struct GetPostsByUserEndpoint: Endpoint {
    let userId: Int
    var baseURL    = "https://jsonplaceholder.typicode.com"
    var path       = "/posts"
    var method     = HTTPMethod.GET
    var queryItems: [URLQueryItem]? {
        [URLQueryItem(name: "userId", value: "\(userId)")]
    }
}

// POST with body
struct CreatePostRequest: Encodable {
    let title: String
    let body: String
    let userId: Int
}

struct CreatePostEndpoint: Endpoint {
    let post: CreatePostRequest
    var baseURL = "https://jsonplaceholder.typicode.com"
    var path    = "/posts"
    var method  = HTTPMethod.POST
    var headers: [String: String]? {
        ["Content-Type": "application/json"]
    }
    var body: Data? { encode(post) }
}

// DELETE
struct DeletePostEndpoint: Endpoint {
    let id: Int
    var baseURL     = "https://jsonplaceholder.typicode.com"
    var path: String { "/posts/\(id)" }
    var method      = HTTPMethod.DELETE
}
```

**Organise by feature:**

```
App/Endpoints/
├── PostsEndpoints.swift    // GetPosts, GetPost, CreatePost, DeletePost
├── UserEndpoints.swift     // GetUser, UpdateUser
└── AuthEndpoints.swift     // Login, Logout, RefreshToken
```

---

### URLRequestBuilder

Converts an `Endpoint` into a fully configured `URLRequest`. Used internally by `APIClient` — you never call this directly.

**Build steps:**
1. Constructs URL using `URLComponents` (handles percent-encoding automatically)
2. Validates HTTP rules (GET/HEAD with body → throws `.invalidRequest`)
3. Assembles `URLRequest` with method, headers, body, and timeout
4. Merges default headers with endpoint-specific headers (endpoint wins on conflict)

**Header merge strategy:**

| Source | Header | Result |
|--------|--------|--------|
| Default | `Accept: application/json` | Included |
| Default | `Content-Type: application/json` | Overridden by endpoint |
| Endpoint | `Content-Type: multipart/form-data` | Wins ✅ |
| Endpoint | `Authorization: Bearer token` | Added ✅ |

**Usage:**

```swift
// Standard JSON builder (default)
let builder = URLRequestBuilder.jsonBuilder

// Custom default headers
let builder = URLRequestBuilder(defaultHeaders: [
    "Content-Type": "application/json",
    "Accept":       "application/json",
    "X-API-Key":    "your-key"
])
```

---

### ResponseDecoder

Wraps `JSONDecoder` with flexible decoding strategies, key path support, and readable error messages.

**Decoding strategies:**

```swift
// snake_case → camelCase (default, most REST APIs)
ResponseDecoder()
// "user_name" → "userName"

// Exact key matching
ResponseDecoder(strategy: .useDefaultKeys)

// Custom transformation
ResponseDecoder(strategy: .custom { keys in
    AnyKey(stringValue: keys.last?.stringValue
        .replacingOccurrences(of: "api_", with: "") ?? "")
})
```

**Key path decoding:**

```swift
// API returns: { "data": [{ "id": 1, "title": "Hello" }] }

// Without key path — wrapper struct needed
struct PostsResponse: Decodable { let data: [Post] }

// With key path — clean and direct
let posts = try decoder.decode([Post].self, from: data, keyPath: "data")
```

**ISO 8601 dates decoded automatically:**

```swift
struct Article: Decodable {
    let title: String
    let publishedAt: Date   // "2024-01-15T10:30:00Z" → Date ✅
}
```

---

### APIClientProtocol

The abstract contract your ViewModels and services depend on. Both the real `APIClient` and `MockAPIClient` conform to this.

```swift
public protocol APIClientProtocol {
    func request<T: Decodable>(_ endpoint: some Endpoint) async throws -> T
    func requestWithoutResponse(_ endpoint: some Endpoint) async throws
    func requestData(_ endpoint: some Endpoint) async throws -> Data
}
```

**Always inject the protocol, never the concrete type:**

```swift
// ✅ Correct — testable and swappable
class PostsViewModel: ObservableObject {
    private let client: APIClientProtocol

    init(client: APIClientProtocol) {
        self.client = client
    }
}

// Production
PostsViewModel(client: APIClient.production(tokenProvider: AuthManager.shared))

// Tests
PostsViewModel(client: MockAPIClient())

// ❌ Wrong — untestable
class PostsViewModel: ObservableObject {
    private let client = APIClient()
}
```

---

### APIClient

The real `URLSession`-backed implementation of `APIClientProtocol`.

**Request pipeline:**

```
requestData()
    ↓
1. URLRequestBuilder    → builds URLRequest from Endpoint
2. InterceptorChain     → applies request interceptors (auth, logging)
3. URLSession           → fires network call
4. validateResponse()   → maps status codes to NetworkError
5. InterceptorChain     → applies response interceptors (logging, retry)
    ↓
request()
    ↓
6. ResponseDecoder      → decodes Data into T
```

**Convenience factories:**

```swift
// No interceptors — good for public endpoints
let client = APIClient.default

// Development — verbose logging + auth + retry
let client = APIClient.development(tokenProvider: AuthManager.shared)

// Production — silent, auth + retry only
let client = APIClient.production(tokenProvider: AuthManager.shared)
```

**Custom configuration:**

```swift
// Custom timeout
let config = URLSessionConfiguration.default
config.timeoutIntervalForRequest = 60
let client = APIClient(
    session: URLSession(configuration: config),
    interceptors: [
        LoggingInterceptor(level: .minimal),
        AuthInjectorInterceptor(tokenProvider: AuthManager.shared),
        RetryInterceptor(maxRetries: 3)
    ]
)
```

---

## Interceptors

Interceptors plug into the `APIClient` pipeline and run on every request and response. They are composable, reusable, and toggled without touching `APIClient`.

**Pipeline order:**

```
Request  → Interceptor1 → Interceptor2 → Interceptor3 → URLSession
Response ← Interceptor1 ← Interceptor2 ← Interceptor3 ← URLSession
```

### InterceptorProtocol

The contract all interceptors conform to. Both methods have default pass-through implementations — only override what you need.

```swift
public protocol InterceptorProtocol {
    func intercept(_ request: URLRequest) async throws -> URLRequest
    func intercept(response: URLResponse, data: Data, for request: URLRequest) async throws -> Data
}
```

**Creating a custom interceptor:**

```swift
// Example: adds a custom app version header to every request
struct AppVersionInterceptor: InterceptorProtocol {
    func intercept(_ request: URLRequest) async throws -> URLRequest {
        var modified = request
        modified.setValue("2.1.0", forHTTPHeaderField: "X-App-Version")
        return modified
    }
    // response method not needed — uses default pass-through
}
```

---

### LoggingInterceptor

Logs outgoing requests and incoming responses. Uses Apple's `OSLog` for structured, filterable output.

**Log levels:**

```swift
LoggingInterceptor(level: .none)     // silent — use in production
LoggingInterceptor(level: .minimal)  // method, URL, status code only
LoggingInterceptor(level: .verbose)  // full headers, body, duration (default)
```

**Verbose output example:**

```
┌─────────────────────────────────────────
│ ➡️  REQUEST
│ GET https://jsonplaceholder.typicode.com/posts
│ Headers: ["Accept": "application/json"]
└─────────────────────────────────────────
┌─────────────────────────────────────────
│ ✅  RESPONSE
│ 200 OK — 143ms
│ Body: [{"userId":1,"id":1,"title":"Hello"}...]
└─────────────────────────────────────────
```

> Large response bodies are automatically truncated to 500 characters to keep the console readable.

---

### AuthInjectorInterceptor

Automatically injects auth tokens into every request. Handles silent token refresh on `401` responses with concurrent refresh protection.

**Setup:**

```swift
// Conform your AuthManager to TokenProvider
actor AuthManager: TokenProvider {
    var accessToken: String? {
        KeychainHelper.read(key: "access_token")
    }
    var refreshToken: String? {
        KeychainHelper.read(key: "refresh_token")
    }
    func refreshAccessToken() async throws -> String {
        // call your refresh endpoint
    }
}
```

**Auth schemes:**

```swift
// Bearer (default — most REST APIs)
AuthInjectorInterceptor(tokenProvider: AuthManager.shared)
// → "Authorization: Bearer eyJhbGci..."

// API Key
AuthInjectorInterceptor(tokenProvider: AuthManager.shared, scheme: .apiKey)
// → "Authorization: ApiKey abc123"

// Basic
AuthInjectorInterceptor(tokenProvider: AuthManager.shared, scheme: .basic)
// → "Authorization: Basic dXNlcjpwYXNz"
```

**Silent token refresh flow:**

```
Request → 401 received
              ↓
   AuthInjector catches it
              ↓
   Refreshes token silently
              ↓
   RetryInterceptor re-fires request
              ↓
   ViewModel never knew ✅
```

> Concurrent refresh protection ensures only one refresh call fires even if multiple requests fail with 401 simultaneously.

---

### RetryInterceptor

Automatically retries failed requests on transient errors with configurable backoff strategies.

**Retry policies:**

```swift
// Fixed delay — same wait every time
RetryInterceptor(policy: .constant(delay: 2.0))
// fail → wait 2s → retry → wait 2s → retry

// Exponential backoff
RetryInterceptor(policy: .exponential(base: 1.0))
// fail → wait 1s → retry → wait 2s → retry → wait 4s → retry

// Exponential with jitter (default — best for production)
RetryInterceptor(policy: .exponentialWithJitter(base: 1.0))
// fail → wait ~1.3s → retry → wait ~2.7s → retry → wait ~4.1s → retry
```

> Jitter prevents the "thundering herd" problem — without it, many clients failing simultaneously all retry at the same time, overwhelming the server.

**Retryable status codes:**

| Code | Reason | Retried? |
|------|--------|----------|
| 408 | Request Timeout | ✅ Yes |
| 429 | Too Many Requests | ✅ Yes |
| 500 | Internal Server Error | ✅ Yes |
| 502 | Bad Gateway | ✅ Yes |
| 503 | Service Unavailable | ✅ Yes |
| 504 | Gateway Timeout | ✅ Yes |
| 401 | Unauthorized | ❌ No (AuthInjector handles) |
| 404 | Not Found | ❌ No (won't change on retry) |

**Custom retry count:**

```swift
RetryInterceptor(maxRetries: 5, policy: .exponentialWithJitter(base: 1.0))
```

---

## End-to-End Example

```swift
// 1. Model
struct Post: Decodable, Identifiable {
    let id: Int
    let title: String
    let body: String
}

// 2. Endpoint
struct GetPostsEndpoint: Endpoint {
    var baseURL = "https://jsonplaceholder.typicode.com"
    var path    = "/posts"
    var method  = HTTPMethod.GET
}

// 3. ViewModel
@MainActor
class PostsViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let client: APIClientProtocol

    init(client: APIClientProtocol = APIClient.default) {
        self.client = client
    }

    func fetchPosts() async {
        isLoading = true
        errorMessage = nil
        do {
            posts = try await client.request(GetPostsEndpoint())
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// 4. SwiftUI View
struct PostsView: View {
    @StateObject private var vm = PostsViewModel()

    var body: some View {
        Group {
            if vm.isLoading {
                ProgressView()
            } else if let error = vm.errorMessage {
                Text(error).foregroundStyle(.red)
            } else {
                List(vm.posts) { post in
                    Text(post.title)
                }
            }
        }
        .task { await vm.fetchPosts() }
    }
}
```

---

## Environment Configuration

```swift
// Development — full logging
let client = APIClient.development(tokenProvider: AuthManager.shared)

// Production — silent, optimised
let client = APIClient.production(tokenProvider: AuthManager.shared)

// Public API — no auth needed
let client = APIClient.default
```

---

## License

SwiftNetworkKit is available under the MIT license.
