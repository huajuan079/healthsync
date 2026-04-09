import Foundation

// MARK: - Auth Token Provider Protocol

protocol AuthTokenProvider {
    func getAccessToken() -> String?
    func getRefreshToken() -> String?
    func setAccessToken(_ token: String) throws
    func setRefreshToken(_ token: String) throws
    func clearTokens() throws
}

// MARK: - API Service Protocol

protocol APIServiceProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func setAuthToken(_ token: String?)
}

// MARK: - Endpoint

enum Endpoint: Equatable {
    case login(username: String, password: String)
    case refreshToken(token: String)
    case healthUpload(data: HealthDataBatch)
    case healthStatus
    case healthFetch(username: String, startDate: String?, endDate: String?)
    case appleLogin(identityToken: String, userIdentifier: String, email: String?, fullName: String?)

    static func == (lhs: Endpoint, rhs: Endpoint) -> Bool {
        switch (lhs, rhs) {
        case (.login, .login),
             (.refreshToken, .refreshToken),
             (.healthUpload, .healthUpload),
             (.healthStatus, .healthStatus),
             (.healthFetch, .healthFetch),
             (.appleLogin, .appleLogin):
            return true
        default:
            return false
        }
    }

    var path: String {
        switch self {
        case .login:
            return "/api/auth/login"
        case .refreshToken:
            return "/api/auth/refresh"
        case .healthUpload:
            return "/api/health/upload"
        case .healthStatus:
            return "/api/health/status"
        case .healthFetch:
            return "/api/health/fetch"
        case .appleLogin:
            return "/api/auth/apple"
        }
    }

    var method: String {
        switch self {
        case .login, .refreshToken, .healthUpload, .appleLogin:
            return "POST"
        case .healthStatus, .healthFetch:
            return "GET"
        }
    }
}

// MARK: - API Service

final class APIService: APIServiceProtocol {
    private let baseURL: String
    private let session: URLSession
    private let tokenProvider: AuthTokenProvider
    private var authToken: String?

    init(baseURL: String, authTokenProvider: AuthTokenProvider) {
        self.baseURL = baseURL
        self.tokenProvider = authTokenProvider

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)

        // Load initial token
        self.authToken = tokenProvider.getAccessToken()
    }

    func setAuthToken(_ token: String?) {
        self.authToken = token
    }

    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        print("[APIService] request started: \(endpoint.path)")
        let request = try buildRequest(for: endpoint)

        print("[APIService] Sending request to: \(request.url?.absoluteString ?? "unknown")")
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
            print("[APIService] Received response, data size: \(data.count) bytes")
        } catch {
            print("[APIService] Network error: \(error)")
            throw APIError.networkError(error)
        }

        // Handle 401 Unauthorized - try refresh token before throwing
        if let httpResponse = response as? HTTPURLResponse,
           httpResponse.statusCode == 401,
           endpoint != .login(username: "", password: ""),
           endpoint != .refreshToken(token: ""),
           endpoint != .appleLogin(identityToken: "", userIdentifier: "", email: nil, fullName: nil) {
            print("[APIService] 401 received, attempting token refresh")
            try await refreshAndRetry()
            return try await self.request(endpoint)
        }

        try handleResponse(response)

        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            print("[APIService] Response decoded successfully")
            return decoded
        } catch {
            print("[APIService] Decoding error: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("[APIService] Response data: \(jsonString.prefix(200))...")
            }
            throw APIError.decodingFailed(error)
        }
    }

    private func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        guard let url = URL(string: baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add auth token
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        // Add body for POST requests
        switch endpoint {
        case .login(let username, let password):
            let body = LoginRequest(username: username, password: password)
            request.httpBody = try JSONEncoder().encode(body)

        case .refreshToken(let token):
            let body = RefreshTokenRequest(refreshToken: token)
            request.httpBody = try JSONEncoder().encode(body)

        case .healthUpload(let data):
            request.httpBody = try JSONEncoder().encode(data)

        case .healthFetch(let username, let startDate, let endDate):
            var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
            var queryItems: [URLQueryItem] = [
                URLQueryItem(name: "username", value: username)
            ]
            if let startDate = startDate {
                queryItems.append(URLQueryItem(name: "startDate", value: startDate))
            }
            if let endDate = endDate {
                queryItems.append(URLQueryItem(name: "endDate", value: endDate))
            }
            components.queryItems = queryItems
            request.url = components.url
            request.httpBody = nil

        case .appleLogin(let identityToken, let userIdentifier, let email, let fullName):
            let body = AppleLoginRequest(
                identityToken: identityToken,
                userIdentifier: userIdentifier,
                email: email,
                fullName: fullName
            )
            request.httpBody = try JSONEncoder().encode(body)

        default:
            break
        }

        return request
    }

    private func handleResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw APIError.unauthorized
        case 404:
            throw APIError.notFound
        case 500...599:
            throw APIError.serverError(statusCode: httpResponse.statusCode)
        default:
            throw APIError.httpError(statusCode: httpResponse.statusCode)
        }
    }

    private func refreshAndRetry() async throws {
        guard let refreshToken = tokenProvider.getRefreshToken() else {
            throw APIError.unauthorized
        }

        let response: RefreshTokenResponse = try await request(.refreshToken(token: refreshToken))

        try tokenProvider.setAccessToken(response.accessToken)
        authToken = response.accessToken
    }
}

// MARK: - API Errors

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case serverError(statusCode: Int)
    case httpError(statusCode: Int)
    case decodingFailed(Error)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid server URL"
        case .invalidResponse:
            return "Invalid server response"
        case .unauthorized:
            return "Authentication failed"
        case .notFound:
            return "Resource not found"
        case .serverError(let code):
            return "Server error (code: \(code))"
        case .httpError(let code):
            return "HTTP error (code: \(code))"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// MARK: - Request/Response Models

struct LoginRequest: Codable {
    let username: String
    let password: String
}

struct LoginResponse: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let user: User

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}

struct RefreshTokenRequest: Codable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

struct RefreshTokenResponse: Codable {
    let accessToken: String
    let expiresIn: Int

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
    }
}

struct User: Codable {
    let id: String
    let username: String
    let role: String
}

struct HealthDataBatch: Codable {
    let date: String
    let data: String
}

struct AppleLoginRequest: Codable {
    let identityToken: String
    let userIdentifier: String
    let email: String?
    let fullName: String?
}

struct UploadResponse: Codable {
    let success: Bool
    let batchId: String
    let message: String

    enum CodingKeys: String, CodingKey {
        case success
        case batchId = "batch_id"
        case message
    }
}

struct SyncStatusResponse: Codable {
    let lastSyncAt: String?
    let lastFetchAt: String?
    let totalRecords: Int
    let totalUploads: Int
    let dataTypes: [String]

    enum CodingKeys: String, CodingKey {
        case lastSyncAt = "last_sync_at"
        case lastFetchAt = "last_fetch_at"
        case totalRecords = "total_records"
        case totalUploads = "total_uploads"
        case dataTypes = "data_types"
    }
}
