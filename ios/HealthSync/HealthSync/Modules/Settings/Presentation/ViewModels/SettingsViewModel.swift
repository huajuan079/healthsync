import Foundation
import SwiftUI

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var serverURL: String = "http://localhost:3000"
    @Published var syncRange: Int = 7
    @Published var showingLogoutAlert = false

    private let authRepository: AuthRepositoryProtocol
    var onLogout: (() -> Void)?

    init(authRepository: AuthRepositoryProtocol, onLogout: @escaping () -> Void) {
        self.authRepository = authRepository
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

    private func loadSettings() {
        serverURL = UserDefaults.standard.string(forKey: "serverURL") ?? "http://localhost:3000"
        syncRange = UserDefaults.standard.integer(forKey: "syncRangeDays")
        if syncRange == 0 { syncRange = 7 }
    }
}
