import Foundation

protocol LoginUseCaseProtocol {
    func execute(username: String, password: String) async throws
    func logout() throws
}

final class LoginUseCase: LoginUseCaseProtocol {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    func execute(username: String, password: String) async throws {
        guard !username.isEmpty, !password.isEmpty else {
            throw AuthError.emptyCredentials
        }
        _ = try await authRepository.login(username: username, password: password)
    }

    func logout() throws {
        try authRepository.logout()
    }
}

enum AuthError: LocalizedError {
    case emptyCredentials
    var errorDescription: String? {
        switch self {
        case .emptyCredentials: return "用户名和密码不能为空"
        }
    }
}
