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
        } catch {
            isLoading = false
            errorMessage = (error as? AuthError)?.errorDescription ?? error.localizedDescription
        }
    }

    var isFormValid: Bool {
        !username.isEmpty && !password.isEmpty && !isLoading
    }
}
