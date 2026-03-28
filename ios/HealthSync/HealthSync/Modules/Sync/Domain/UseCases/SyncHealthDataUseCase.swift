import Foundation
import CryptoKit

// MARK: - Sync Health Data Use Case Protocol

protocol SyncHealthDataUseCaseProtocol {
    func syncData(for date: Date) async throws -> SyncResult
    func syncDataRange(from startDate: Date, to endDate: Date) async throws -> [SyncResult]
    func getSyncStatus() async throws -> SyncStatusResponse

    var onProgress: ((SyncProgress) -> Void)? { get set }
}

// MARK: - Sync Result

struct SyncResult {
    let date: String
    let batchesUploaded: Int
    let totalRecords: Int
    let success: Bool
    let errorMessage: String?
}

// MARK: - Sync Progress

struct SyncProgress {
    var currentDay: Int
    var totalDays: Int
    var currentBatch: Int
    var totalBatches: Int
    var currentDataType: String

    var overallProgress: Double {
        guard totalDays > 0 else { return 0 }
        return Double(currentDay) / Double(totalDays)
    }

    var dailyProgress: Double {
        guard totalBatches > 0 else { return 0 }
        return Double(currentBatch) / Double(totalBatches)
    }
}

// MARK: - Sync Error

enum SyncError: LocalizedError {
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "加密失败"
        }
    }
}

// MARK: - Sync Health Data Use Case

final class SyncHealthDataUseCase: SyncHealthDataUseCaseProtocol {
    private let healthRepository: HealthRepositoryProtocol
    private let syncRepository: SyncRepositoryProtocol
    private let encryptionService: EncryptionServiceProtocol
    private let getCurrentUsername: () -> String

    private var encryptionKey: SymmetricKey {
        let username = getCurrentUsername()
        if let key = EncryptionConfig.getKey(for: username) {
            return key
        }
        // Fallback to a default key (for development only)
        print("[SyncHealthDataUseCase] Warning: Using fallback key for user: \(username)")
        return AESEncryptionService.generateKey()
    }

    private let batchSize = 500

    // Progress reporting
    var onProgress: ((SyncProgress) -> Void)?

    init(
        healthRepository: HealthRepositoryProtocol,
        syncRepository: SyncRepositoryProtocol,
        encryptionService: EncryptionServiceProtocol,
        getCurrentUsername: @escaping () -> String = { "zhugong" }
    ) {
        self.healthRepository = healthRepository
        self.syncRepository = syncRepository
        self.encryptionService = encryptionService
        self.getCurrentUsername = getCurrentUsername
    }

    func syncData(for date: Date) async throws -> SyncResult {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)
        print("[SyncHealthDataUseCase] syncData started for date: \(dateString)")

        // Fetch health data
        print("[SyncHealthDataUseCase] Fetching health data...")
        let healthData = await healthRepository.fetchAllData(for: date)
        print("[SyncHealthDataUseCase] Health data fetched, has steps: \(healthData.steps != nil)")

        // Serialize and encrypt
        print("[SyncHealthDataUseCase] Encoding to JSON...")
        let jsonData = try JSONEncoder().encode(healthData)
        let jsonString = String(data: jsonData, encoding: .utf8)!
        print("[SyncHealthDataUseCase] JSON encoded, size: \(jsonString.count) bytes")

        // Create batch (for simplicity, single batch)
        print("[SyncHealthDataUseCase] Encrypting data...")
        let encrypted = try encryptData(jsonString)
        print("[SyncHealthDataUseCase] Data encrypted, encrypted size: \(encrypted.count) bytes")

        // Calculate checksum on encrypted data (must match server verification)
        guard let encryptedData = encrypted.data(using: .utf8) else {
            throw SyncError.encryptionFailed
        }
        let checksum = encryptionService.calculateChecksum(encryptedData)
        print("[SyncHealthDataUseCase] Checksum calculated on encrypted data: \(checksum)")

        let batch = HealthDataBatch(
            date: dateString,
            batchIndex: 0,
            batchTotal: 1,
            data: encrypted,
            checksum: checksum
        )

        // Upload batch
        print("[SyncHealthDataUseCase] Uploading batch...")
        let response = try await syncRepository.uploadBatch(batch)
        print("[SyncHealthDataUseCase] Upload complete, batchId: \(response.batchId), message: \(response.message)")

        // Report progress
        onProgress?(SyncProgress(
            currentDay: 1,
            totalDays: 1,
            currentBatch: 1,
            totalBatches: 1,
            currentDataType: dateString
        ))

        let totalRecords = estimateRecordCount(encrypted)
        print("[SyncHealthDataUseCase] syncData completed, totalRecords: \(totalRecords)")

        return SyncResult(
            date: dateString,
            batchesUploaded: 1,
            totalRecords: totalRecords,
            success: true,
            errorMessage: nil
        )
    }

    func syncDataRange(from startDate: Date, to endDate: Date) async throws -> [SyncResult] {
        var results: [SyncResult] = []
        var currentDay = 0

        let calendar = Calendar.current
        let totalDays = calendar.dateComponents([.day], from: startDate, to: endDate).day! + 1

        var currentDate = startDate
        while currentDate <= endDate {
            currentDay += 1

            do {
                let result = try await syncData(for: currentDate)
                results.append(result)

                // Report progress
                onProgress?(SyncProgress(
                    currentDay: currentDay,
                    totalDays: totalDays,
                    currentBatch: result.batchesUploaded,
                    totalBatches: result.batchesUploaded,
                    currentDataType: result.date
                ))

            } catch {
                // Continue with next day on error
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                results.append(SyncResult(
                    date: dateFormatter.string(from: currentDate),
                    batchesUploaded: 0,
                    totalRecords: 0,
                    success: false,
                    errorMessage: error.localizedDescription
                ))
            }

            // Move to next day
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        return results
    }

    func getSyncStatus() async throws -> SyncStatusResponse {
        return try await syncRepository.getSyncStatus()
    }

    // MARK: - Private Methods

    private func encryptData(_ jsonString: String) throws -> String {
        let data = jsonString.data(using: .utf8)!
        let encrypted = try encryptionService.encrypt(data, using: encryptionKey)
        return encrypted.toBase64()
    }

    private func estimateRecordCount(_ encryptedData: String) -> Int {
        // Rough estimate based on encrypted size
        let size = encryptedData.data(using: .utf8)!.count
        return max(1, size / 500)
    }
}
