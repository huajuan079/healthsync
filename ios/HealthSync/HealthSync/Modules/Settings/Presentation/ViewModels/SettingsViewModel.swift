import Foundation
import SwiftUI
import HealthKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var serverURL: String = Config.defaultServerURL
    @Published var autoSyncEnabled: Bool = false
    @Published var syncHour: Int = 10
    @Published var showingLogoutAlert = false
    @Published var showingAuthAlert = false
    @Published var authAlertMessage = ""
    @Published var isRequestingAuth = false

    // Dev panel
    @Published var showDevPanel = false
    @Published var devURLInput = ""
    private var versionTapCount = 0
    private var versionTapTimer: Timer?

    var isConnected: Bool { authRepository.hasValidToken() }

    var currentEnvironmentIsLocal: Bool {
        !Config.serverURL.contains("markmager.cc")
    }

    private let authRepository: AuthRepositoryProtocol
    private let healthRepository: HealthRepositoryProtocol
    var onLogout: (() -> Void)?

    init(
        authRepository: AuthRepositoryProtocol,
        healthRepository: HealthRepositoryProtocol,
        onLogout: @escaping () -> Void
    ) {
        self.authRepository = authRepository
        self.healthRepository = healthRepository
        self.onLogout = onLogout
        loadSettings()
    }

    func saveSettings() {
        UserDefaults.standard.set(serverURL, forKey: "serverURL")
    }

    func handleVersionTap() {
        versionTapTimer?.invalidate()
        versionTapCount += 1
        if versionTapCount >= 5 {
            versionTapCount = 0
            devURLInput = Config.serverURL
            showDevPanel = true
        } else {
            versionTapTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
                DispatchQueue.main.async { self?.versionTapCount = 0 }
            }
        }
    }

    func applyDevURL() {
        let trimmed = devURLInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let changed = trimmed != Config.serverURL
        UserDefaults.standard.set(trimmed, forKey: "serverURL")
        showDevPanel = false
        if changed { logout() }
    }

    func logout() {
        do { try authRepository.logout() }
        catch { print("Logout failed: \(error)") }
        onLogout?()
    }

    // 检查授权状态并提示
    func checkAuthorizationAndAlert() {
        let isAuthorized = healthRepository.checkAuthorizationStatus()

        if isAuthorized {
            authAlertMessage = "✅ 所有健康数据权限已授予！\n\n您现在可以正常同步健康数据了。"
        } else {
            authAlertMessage = "⚠️ 部分健康数据权限未授予\n\n由于 iOS 系统限制，App 无法再次弹出授权窗口。\n\n请手动开启：\n1. 打开 iPhone「设置」→「健康」\n2. 点击「数据访问与设备」→「HealthSync」\n3. 开启所有数据类型的开关\n\n或点击「打开健康设置」直接打开健康 App"
        }
        showingAuthAlert = true
    }

    func requestHealthKitAuthorization() async {
        isRequestingAuth = true
        do {
            print("[SettingsViewModel] Requesting HealthKit authorization...")
            // 先尝试调用授权请求（会弹出系统弹窗）
            let requestSuccess = try await healthRepository.requestAuthorization()
            print("[SettingsViewModel] Authorization request completed: \(requestSuccess)")

            // 请求完成后，检查实际的授权状态
            let isAuthorized = healthRepository.checkAuthorizationStatus()
            print("[SettingsViewModel] Actual authorization status: \(isAuthorized)")
            UserDefaults.standard.set(isAuthorized, forKey: "healthkit_authorized")

            if isAuthorized {
                authAlertMessage = "✅ 健康数据授权成功！\n\n现在可以同步您的健康数据了。"
            } else {
                authAlertMessage = "⚠️ 部分健康数据权限未授予\n\n由于 iOS 系统限制，如果之前拒绝了授权，系统不会再次弹出授权窗口。\n\n请手动开启权限：\n1. 打开 iPhone「设置」→「健康」\n2. 点击「数据访问与设备」→「HealthSync」\n3. 开启所有数据类型的开关\n\n或点击下方「打开健康设置」按钮"
            }
        } catch {
            print("[SettingsViewModel] Authorization error: \(error)")
            authAlertMessage = "授权请求失败：\(error.localizedDescription)\n\n请点击下方「打开健康设置」手动开启权限。"
        }
        isRequestingAuth = false
        showingAuthAlert = true
    }

    func toggleAutoSync(_ enabled: Bool) {
        autoSyncEnabled = enabled
        UserDefaultsManager.shared.autoSyncEnabled = enabled
        if enabled {
            BackgroundSyncTaskManager.shared.scheduleBackgroundSync()
        } else {
            BackgroundSyncTaskManager.shared.cancelPendingTasks()
        }
    }

    func updateSyncHour(_ hour: Int) {
        syncHour = hour
        UserDefaultsManager.shared.syncHour = hour
        if autoSyncEnabled {
            BackgroundSyncTaskManager.shared.cancelPendingTasks()
            BackgroundSyncTaskManager.shared.scheduleBackgroundSync()
        }
    }

    private func loadSettings() {
        serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? Config.defaultServerURL
        autoSyncEnabled = UserDefaultsManager.shared.autoSyncEnabled
        syncHour = UserDefaultsManager.shared.syncHour
    }
}
