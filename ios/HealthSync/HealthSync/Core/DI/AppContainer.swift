import Foundation
import SwiftUI
import HealthKit

/// Shared HKHealthStore instance (lazy loaded)
private var sharedHealthStore: HKHealthStore?

final class AppContainer: ObservableObject {
    // Lazy initialization - only created when accessed
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

    lazy var healthRepository: HealthRepositoryProtocol = {
        // Create health store only when needed
        if sharedHealthStore == nil {
            sharedHealthStore = HKHealthStore()
        }
        return HealthRepository(healthStore: sharedHealthStore!)
    }()

    lazy var syncRepository: SyncRepositoryProtocol = SyncRepository(
        apiService: apiService
    )

    lazy var loginUseCase = LoginUseCase(authRepository: authRepository)
    lazy var syncHealthDataUseCase = SyncHealthDataUseCase(
        healthRepository: healthRepository,
        syncRepository: syncRepository,
        encryptionService: encryptionService,
        getCurrentUsername: {
            // Get username from UserDefaults
            UserDefaultsManager.shared.username ?? "zhugong"
        }
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
    private static var cachedServerURL: String?

    static var serverURL: String {
        if let cached = cachedServerURL {
            return cached
        }
        let value = UserDefaults.standard.string(forKey: "serverURL") ?? "https://markmager.cc/healthsync"
        cachedServerURL = value
        return value
    }
}
