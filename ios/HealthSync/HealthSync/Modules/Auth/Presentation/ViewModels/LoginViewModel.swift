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
            errorMessage = LoginViewModel.friendlyMessage(for: error)
        }
    }

    func warmUpConnection() {
        guard let url = URL(string: Config.serverURL) else { return }
        URLSession.shared.dataTask(with: URLRequest(url: url)) { _, _, _ in }.resume()
    }

    var isFormValid: Bool {
        !username.isEmpty && !password.isEmpty && !isLoading
    }

    private static func friendlyMessage(for error: Error) -> String {
        if let authError = error as? AuthError {
            return authError.errorDescription ?? error.localizedDescription
        }
        let code = (error as NSError).code
        switch code {
        case NSURLErrorTimedOut:
            return "连接超时，请检查网络或服务器地址"
        case NSURLErrorCannotConnectToHost, NSURLErrorNetworkConnectionLost:
            return "无法连接服务器，请检查网络"
        case NSURLErrorNotConnectedToInternet:
            return "当前无网络连接"
        default:
            return error.localizedDescription
        }
    }
}
