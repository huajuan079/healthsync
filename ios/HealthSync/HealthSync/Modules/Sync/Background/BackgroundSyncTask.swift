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

    // Schedule next background sync
    func scheduleBackgroundSync() {
        let request = BGProcessingTaskRequest(identifier: taskIdentifier)

        // Schedule for approximately 11 PM
        var dateComponents = DateComponents()
        dateComponents.hour = 23
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
            print("Background sync scheduled")
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
                // Sync today's data
                _ = try await syncUseCase.syncData(for: Date())

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
}
