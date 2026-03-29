import Foundation
import SwiftUI
import HealthKit

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var serverURL: String = "http://localhost:3000"
    @Published var syncRange: Int = 7
    @Published var showingLogoutAlert = false
    @Published var showingAuthAlert = false
    @Published var authAlertMessage = ""
    @Published var isRequestingAuth = false

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
        UserDefaults.standard.set(syncRange, forKey: "syncRangeDays")
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

    private func loadSettings() {
        serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:3000"
        syncRange = UserDefaults.standard.integer(forKey: "syncRangeDays")
        if syncRange == 0 { syncRange = 7 }
    }
}
