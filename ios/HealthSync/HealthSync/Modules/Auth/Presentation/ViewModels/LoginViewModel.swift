import Foundation
import SwiftUI
import AuthenticationServices

@MainActor
final class LoginViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let loginUseCase: LoginUseCaseProtocol
    private let appleSignInUseCase: AppleSignInUseCaseProtocol

    init(loginUseCase: LoginUseCaseProtocol, appleSignInUseCase: AppleSignInUseCaseProtocol) {
        self.loginUseCase = loginUseCase
        self.appleSignInUseCase = appleSignInUseCase
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

    func handleAppleSignIn(result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let authorization):
            Task { await performAppleSignIn(authorization: authorization) }
        case .failure(let error):
            errorMessage = LoginViewModel.friendlyMessage(for: error)
        }
    }

    private func performAppleSignIn(authorization: ASAuthorization) async {
        isLoading = true
        do {
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let identityToken = String(data: tokenData, encoding: .utf8) else {
                throw AppleSignInError.missingToken
            }
            let userIdentifier = credential.user
            let email = credential.email
            let fullName: String? = {
                let parts = [credential.fullName?.givenName, credential.fullName?.familyName].compactMap { $0 }
                return parts.isEmpty ? nil : parts.joined(separator: " ")
            }()

            let username = try await appleSignInUseCase.execute(
                identityToken: identityToken,
                userIdentifier: userIdentifier,
                email: email,
                fullName: fullName
            )
            UserDefaultsManager.shared.username = username
            print("[LoginViewModel] Apple user logged in: \(username)")
            isLoading = false
            NotificationCenter.default.post(name: .didLogin, object: nil)
        } catch {
            isLoading = false
            errorMessage = LoginViewModel.friendlyMessage(for: error)
        }
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
