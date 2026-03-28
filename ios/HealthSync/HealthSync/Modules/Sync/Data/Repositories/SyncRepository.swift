import Foundation

protocol SyncRepositoryProtocol {
    func uploadBatch(_ batch: HealthDataBatch) async throws -> UploadResponse
    func getSyncStatus() async throws -> SyncStatusResponse
}

final class SyncRepository: SyncRepositoryProtocol {
    private let apiService: APIServiceProtocol
    init(apiService: APIServiceProtocol) {
        self.apiService = apiService
    }
    func uploadBatch(_ batch: HealthDataBatch) async throws -> UploadResponse {
        return try await apiService.request(.healthUpload(data: batch))
    }
    func getSyncStatus() async throws -> SyncStatusResponse {
        return try await apiService.request(.healthStatus)
    }
}
