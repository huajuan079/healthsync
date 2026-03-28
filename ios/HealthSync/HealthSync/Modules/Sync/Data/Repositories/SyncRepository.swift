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
        print("[SyncRepository] uploadBatch called for date: \(batch.date)")
        do {
            let response = try await apiService.request(.healthUpload(data: batch))
            print("[SyncRepository] uploadBatch success")
            return response
        } catch {
            print("[SyncRepository] uploadBatch error: \(error)")
            throw error
        }
    }
    func getSyncStatus() async throws -> SyncStatusResponse {
        print("[SyncRepository] getSyncStatus called")
        do {
            let status = try await apiService.request(.healthStatus)
            print("[SyncRepository] getSyncStatus success")
            return status
        } catch {
            print("[SyncRepository] getSyncStatus error: \(error)")
            throw error
        }
    }
}
