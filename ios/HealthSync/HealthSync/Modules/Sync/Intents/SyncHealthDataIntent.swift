import AppIntents
import Foundation

// MARK: - Sync Today Intent

@available(iOS 16.0, *)
struct SyncTodayIntent: AppIntent {
    static var title: LocalizedStringResource = "同步今日健康数据"
    static var description = IntentDescription("将今日 HealthKit 数据上传到服务器")

    // 允许自动化无需用户交互即可运行
    static var authenticationPolicy: IntentAuthenticationPolicy = .alwaysAllowed

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let container = AppContainer()

        // 检查是否已登录
        guard container.getAccessToken() != nil else {
            return .result(dialog: "请先在小炎健康助手中登录")
        }

        // 请求 HealthKit 授权（已授权时会直接返回）
        _ = try await container.healthRepository.requestAuthorization()

        // 同步今天的数据
        let result = try await container.syncHealthDataUseCase.syncData(for: Date())

        if result.success {
            return .result(dialog: "同步成功，上传 \(result.totalRecords) 条记录（\(result.date)）")
        } else {
            let msg = result.errorMessage ?? "未知错误"
            throw SyncIntentError.syncFailed(msg)
        }
    }
}

// MARK: - Error

@available(iOS 16.0, *)
enum SyncIntentError: LocalizedError {
    case syncFailed(String)

    var errorDescription: String? {
        switch self {
        case .syncFailed(let msg):
            return "同步失败：\(msg)"
        }
    }
}
