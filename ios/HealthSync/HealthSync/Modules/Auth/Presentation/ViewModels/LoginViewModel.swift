import Foundation
import SwiftUI

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let loginUseCase: LoginUseCaseProtocol

    init(loginUseCase: LoginUseCaseProtocol) {
        self.loginUseCase = loginUseCase
    }

    func login() {
        Task { await performLogin() }
    }

    private func performLogin() async {
        isLoading = true
        do {
            try await loginUseCase.execute(username: username, password: password)
            // Save username for encryption key lookup
            UserDefaultsManager.shared.username = username
            print("[LoginViewModel] Username saved: \(username)")
            isLoading = false
            // Notify that login succeeded
            NotificationCenter.default.post(name: .didLogin, object: nil)
        } catch {
            isLoading = false
            errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
        }
    }

    func warmUpConnection() {
        guard let url = URL(string: Config.serverURL) else { return }
        URLSession.shared.dataTask(with: URLRequest(url: url)) { _, _, _ in }.resume()
    }

    var isFormValid: Bool {
        !username.isEmpty && !password.isEmpty && !isLoading
    }
}
