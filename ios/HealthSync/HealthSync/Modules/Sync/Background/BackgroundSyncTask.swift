import Foundation
import BackgroundTasks

// MARK: - Background Sync Task Manager

final class BackgroundSyncTaskManager {
    static let shared = BackgroundSyncTaskManager()

    private let taskIdentifier = "com.openclaw.HealthSync.background-sync"

    private init() {}

    // Register background task
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: taskIdentifier,
            using: nil
        ) { [weak self] task in
            self?.handleBackgroundTask(task as! BGProcessingTask)
        }
    }

    // Schedule background sync at user-configured hour (default 10:00)
    func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)

        let hour = UserDefaultsManager.shared.syncHour
        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = 0

        request.earliestBeginDate = Calendar.current.nextDate(
            after: Date(),
            matching: dateComponents,
            matchingPolicy: .nextTime
        )

        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
            print("Background sync scheduled for \(String(format: "%02d", hour)):00")
        } catch {
            print("Failed to schedule background sync: \(error)")
        }
    }

    // Handle background task execution
    private func handleBackgroundTask(_ task: BGProcessingTask) {
        print("Background sync task started")

        // Set expiration handler
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
            print("Background sync task expired")
        }

        // Perform sync
        Task {
            let container = AppContainer()
            let syncUseCase = container.syncHealthDataUseCase

            do {
                // Get yesterday and today dates
                let calendar = Calendar.current
                guard let yesterday = calendar.date(byAdding: .day, value: -1, to: Date()) else {
                    throw SyncError.dateCalculationFailed
                }
                let today = Date()

                print("Syncing yesterday: \(formatDate(yesterday))")
                let yesterdayResult = try await syncUseCase.syncData(for: yesterday)
                print("Yesterday sync: success=\(yesterdayResult.success), records=\(yesterdayResult.totalRecords)")

                print("Syncing today: \(formatDate(today))")
                let todayResult = try await syncUseCase.syncData(for: today)
                print("Today sync: success=\(todayResult.success), records=\(todayResult.totalRecords)")

                // Schedule next sync
                task.setTaskCompleted(success: true)
                self.scheduleBackgroundSync()

                print("Background sync completed successfully")
            } catch {
                print("Background sync failed: \(error)")
                task.setTaskCompleted(success: false)
                self.scheduleBackgroundSync()
            }
        }
    }

    // Cancel scheduled tasks
    func cancelPendingTasks() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

enum SyncError: Error {
    case dateCalculationFailed
}
