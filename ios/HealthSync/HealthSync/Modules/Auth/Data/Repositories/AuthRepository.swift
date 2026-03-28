import Foundation

protocol AuthRepositoryProtocol {
    func hasValidToken() -> Bool
    func login(username: String, password: String) async throws -> LoginResponse
    func logout() throws
}

final class AuthRepository: AuthRepositoryProtocol {
    private let apiService: APIServiceProtocol
    private let keychainManager: KeychainManagerProtocol

    init(apiService: APIServiceProtocol, keychainManager: KeychainManagerProtocol) {
        self.apiService = apiService
        self.keychainManager = keychainManager
    }

    func hasValidToken() -> Bool {
        return keychainManager.hasValidToken()
    }

    func login(username: String, password: String) async throws -> LoginResponse {
        let response: LoginResponse = try await apiService.request(.login(username: username, password: password))
        try keychainManager.set(key: .accessToken, value: response.accessToken)
        try keychainManager.set(key: .refreshToken, value: response.refreshToken)
        if let api = apiService as? APIService { api.setAuthToken(response.accessToken) }
        return response
    }

    func logout() throws {
        try keychainManager.delete(key: .accessToken)
        try keychainManager.delete(key: .refreshToken)
        if let api = apiService as? APIService { api.setAuthToken(nil) }
    }
}
