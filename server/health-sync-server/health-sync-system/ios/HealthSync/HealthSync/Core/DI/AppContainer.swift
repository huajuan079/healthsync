import Foundation
import SwiftUI

final class AppContainer: ObservableObject {
    lazy var apiService: APIServiceProtocol = APIService(
        baseURL: Config.serverURL,
        authTokenProvider: self
    )

    lazy var encryptionService: EncryptionServiceProtocol = AESEncryptionService()
    lazy var keychainManager: KeychainManagerProtocol = KeychainManager()

    lazy var authRepository: AuthRepositoryProtocol = AuthRepository(
        apiService: apiService,
        keychainManager: keychainManager
    )

    lazy var healthRepository: HealthRepositoryProtocol = HealthRepository(
        healthStore: HKHealthStore()
    )

    lazy var syncRepository: SyncRepositoryProtocol = SyncRepository(
        apiService: apiService,
        encryptionService: encryptionService
    )

    lazy var loginUseCase = LoginUseCase(authRepository: authRepository)
    lazy var syncHealthDataUseCase = SyncHealthDataUseCase(
        healthRepository: healthRepository,
        syncRepository: syncRepository,
        encryptionService: encryptionService
    )
}

extension AppContainer: AuthTokenProvider {
    func getAccessToken() -> String? {
        try? keychainManager.get(key: .accessToken)
    }

    func getRefreshToken() -> String? {
        try? keychainManager.get(key: .refreshToken)
    }

    func setAccessToken(_ token: String) throws {
        try keychainManager.set(key: .accessToken, value: token)
    }

    func setRefreshToken(_ token: String) throws {
        try keychainManager.set(key: .refreshToken, value: token)
    }

    func clearTokens() throws {
        try keychainManager.delete(key: .accessToken)
        try keychainManager.delete(key: .refreshToken)
    }
}

enum Config {
    static var serverURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:3000"
    }

    static var syncRangeDays: Int {
        UserDefaults.standard.integer(forKey: "syncRangeDays") ?? 7
    }
}
