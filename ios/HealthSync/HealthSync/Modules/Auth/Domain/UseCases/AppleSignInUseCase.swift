import Foundation

protocol AppleSignInUseCaseProtocol {
    func execute(identityToken: String, userIdentifier: String, email: String?, fullName: String?) async throws -> String
}

final class AppleSignInUseCase: AppleSignInUseCaseProtocol {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    /// Returns the username assigned by the server (e.g. "apple_xxxxxxxx")
    func execute(identityToken: String, userIdentifier: String, email: String?, fullName: String?) async throws -> String {
        let response = try await authRepository.appleLogin(
            identityToken: identityToken,
            userIdentifier: userIdentifier,
            email: email,
            fullName: fullName
        )
        return response.user.username
    }
}

enum AppleSignInError: LocalizedError {
    case invalidCredential
    case missingToken

    var errorDescription: String? {
        switch self {
        case .invalidCredential: return "Apple 登录凭证无效"
        case .missingToken: return "未能获取 Apple 授权 token"
        }
    }
}
