import Foundation
import HealthKit
import SwiftUI

@MainActor
final class SyncViewModel: ObservableObject {
    @Published var isSyncing: Bool = false
    @Published var syncProgress: SyncProgress?
    @Published var syncStatus: SyncStatusResponse?
    @Published var lastSyncTime: Date?
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    @Published var syncLogs: [SyncLog] = []

    private let syncUseCase: SyncHealthDataUseCase
    private let healthRepository: HealthRepositoryProtocol

    init(
        syncUseCase: SyncHealthDataUseCase,
        healthRepository: HealthRepositoryProtocol
    ) {
        self.syncUseCase = syncUseCase
        self.healthRepository = healthRepository

        loadLastSyncTime()

        // Set up progress reporting
        syncUseCase.onProgress = { [weak self] progress in
            Task { @MainActor in
                self?.syncProgress = progress
            }
        }
    }

    convenience init(container: AppContainer) {
        self.init(
            syncUseCase: container.syncHealthDataUseCase,
            healthRepository: container.healthRepository
        )
    }

    func syncToday() {
        print("[SyncViewModel] syncToday() called")
        Task {
            await requestAuthorizationAndSync(for: Date())
        }
    }

    func syncLastWeek() {
        print("[SyncViewModel] syncLastWeek() called")
        Task {
            await performSyncRange(days: 7)
        }
    }

    func syncLast30Days() {
        print("[SyncViewModel] syncLast30Days() called")
        Task {
            await performSyncRange(days: 30)
        }
    }

    // Request authorization first, then sync
    private func requestAuthorizationAndSync(for date: Date) async {
        print("[SyncViewModel] requestAuthorizationAndSync called for date: \(date)")

        // Check actual HealthKit authorization status
        let isFullyAuthorized = await healthRepository.checkAuthorizationStatus()
        print("[SyncViewModel] isFullyAuthorized: \(isFullyAuthorized)")

        if !isFullyAuthorized {
            do {
                print("[SyncViewModel] Requesting HealthKit authorization...")
                let granted = try await healthRepository.requestAuthorization()
                UserDefaults.standard.set(granted, forKey: "healthkit_authorized")
                print("[SyncViewModel] Authorization granted: \(granted)")

                if !granted {
                    errorMessage = "需要健康数据权限才能同步"
                    showError = true
                    print("[SyncViewModel] Authorization denied, returning")
                    return
                }
            } catch {
                print("[SyncViewModel] Authorization error: \(error)")
                errorMessage = "请求权限失败: \(error.localizedDescription)"
                showError = true
                return
            }
        }

        await performSync(for: date)
    }

    func refreshStatus() {
        Task {
            await fetchSyncStatus()
        }
    }

    private func performSync(for date: Date) async {
        print("[SyncViewModel] performSync called for date: \(date)")
        isSyncing = true
        errorMessage = nil

        do {
            print("[SyncViewModel] Calling syncUseCase.syncData...")
            let result = try await syncUseCase.syncData(for: date)
            print("[SyncViewModel] syncData completed, result.success: \(result.success)")

            if result.success {
                lastSyncTime = Date()
                saveLastSyncTime()

                syncLogs.insert(SyncLog(
                    date: result.date,
                    time: Date(),
                    status: .success,
                    message: "成功同步 \(result.totalRecords) 条记录"
                ), at: 0)

                if syncLogs.count > 10 {
                    syncLogs.removeLast()
                }

                await fetchSyncStatus()
            } else {
                errorMessage = result.errorMessage ?? "同步失败"
                showError = true
                print("[SyncViewModel] Sync failed: \(result.errorMessage ?? "unknown")")
            }
        } catch {
            print("[SyncViewModel] Sync error: \(error)")
            errorMessage = error.localizedDescription
            showError = true

            syncLogs.insert(SyncLog(
                date: formatDate(date),
                time: Date(),
                status: .failure,
                message: error.localizedDescription
            ), at: 0)
        }

        isSyncing = false
        syncProgress = nil
        print("[SyncViewModel] performSync finished")
    }

    private func performSyncRange(days: Int) async {
        // Check authorization first
        let isAuthorized = UserDefaults.standard.bool(forKey: "healthkit_authorized")

        if !isAuthorized {
            do {
                let granted = try await healthRepository.requestAuthorization()
                UserDefaults.standard.set(granted, forKey: "healthkit_authorized")

                if !granted {
                    errorMessage = "需要健康数据权限才能同步"
                    showError = true
                    isSyncing = false
                    return
                }
            } catch {
                errorMessage = "请求权限失败: \(error.localizedDescription)"
                showError = true
                isSyncing = false
                return
            }
        }

        isSyncing = true
        errorMessage = nil

        let calendar = Calendar.current
        let endDate = Date()
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: endDate) else {
            isSyncing = false
            return
        }

        do {
            let results = try await syncUseCase.syncDataRange(from: startDate, to: endDate)

            let successCount = results.filter { $0.success }.count
            let totalRecords = results.reduce(0) { $0 + $1.totalRecords }

            lastSyncTime = Date()
            saveLastSyncTime()

            syncLogs.insert(SyncLog(
                date: "\(formatDate(startDate)) - \(formatDate(endDate))",
                time: Date(),
                status: .success,
                message: "成功同步 \(successCount)/\(days) 天，共 \(totalRecords) 条记录"
            ), at: 0)

            await fetchSyncStatus()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }

        isSyncing = false
        syncProgress = nil
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func fetchSyncStatus() async {
        do {
            syncStatus = try await syncUseCase.getSyncStatus()
        } catch {
            // Ignore status fetch errors
        }
    }

    private func loadLastSyncTime() {
        if let timestamp = UserDefaults.standard.object(forKey: "lastSyncTime") as? Date {
            lastSyncTime = timestamp
        }
    }

    private func saveLastSyncTime() {
        if let time = lastSyncTime {
            UserDefaults.standard.set(time, forKey: "lastSyncTime")
        }
    }
}

// MARK: - Sync Log

struct SyncLog: Identifiable {
    let id = UUID()
    let date: String
    let time: Date
    let status: SyncLogStatus
    let message: String
}

enum SyncLogStatus {
    case success
    case failure
    case syncing
}
