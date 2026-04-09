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
    lazy var appleSignInUseCase: AppleSignInUseCaseProtocol = AppleSignInUseCase(authRepository: authRepository)
    lazy var syncHealthDataUseCase = SyncHealthDataUseCase(
        healthRepository: healthRepository,
        syncRepository: syncRepository,
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
    /// Debug build 默认连接本地 Mac，Release build 默认连接生产服务器
    /// 修改 DEBUG 分支的 IP 为你 Mac 的局域网 IP（用 ifconfig 查看）
    static let defaultServerURL: String = {
//        #if DEBUG
//        return "http://192.168.124.81:3000"
//        #else
        return "https://markmager.cc/healthsync"
//        #endif
    }()

    /// UserDefaults 中有覆盖值时使用覆盖值，否则用 defaultServerURL
    static var serverURL: String {
        UserDefaults.standard.string(forKey: "serverURL") ?? defaultServerURL
    }
}
