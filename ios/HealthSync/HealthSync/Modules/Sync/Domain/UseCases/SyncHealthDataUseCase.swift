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

// MARK: - Sync Health Data Use Case

final class SyncHealthDataUseCase: SyncHealthDataUseCaseProtocol {
    private let healthRepository: HealthRepositoryProtocol
    private let syncRepository: SyncRepositoryProtocol
    private let encryptionService: EncryptionServiceProtocol

    private let encryptionKey: SymmetricKey
    private let batchSize = 500

    // Progress reporting
    var onProgress: ((SyncProgress) -> Void)?

    init(
        healthRepository: HealthRepositoryProtocol,
        syncRepository: SyncRepositoryProtocol,
        encryptionService: EncryptionServiceProtocol,
        encryptionKey: SymmetricKey? = nil
    ) {
        self.healthRepository = healthRepository
        self.syncRepository = syncRepository
        self.encryptionService = encryptionService

        // Use provided key or generate a new one
        if let key = encryptionKey {
            self.encryptionKey = key
        } else {
            self.encryptionKey = AESEncryptionService.generateKey()
        }
    }

    func syncData(for date: Date) async throws -> SyncResult {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: date)

        // Fetch health data
        let healthData = try await healthRepository.fetchAllData(for: date)

        // Serialize and encrypt
        let jsonData = try JSONEncoder().encode(healthData)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        // Calculate checksum
        let checksum = encryptionService.calculateChecksum(jsonString.data(using: .utf8)!)

        // Create batch (for simplicity, single batch)
        let encrypted = try encryptData(jsonString)

        let batch = HealthDataBatch(
            date: dateString,
            batchIndex: 0,
            batchTotal: 1,
            data: encrypted,
            checksum: checksum
        )

        // Upload batch
        let response = try await syncRepository.uploadBatch(batch)

        // Report progress
        onProgress?(SyncProgress(
            currentDay: 1,
            totalDays: 1,
            currentBatch: 1,
            totalBatches: 1,
            currentDataType: dateString
        ))

        let totalRecords = estimateRecordCount(encrypted)

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
                results.append(SyncResult(
                    date: DateFormatter.dateOnly.string(from: currentDate),
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
