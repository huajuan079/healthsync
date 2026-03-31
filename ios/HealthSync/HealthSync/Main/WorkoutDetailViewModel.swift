import Foundation
import HealthKit

@MainActor
final class WorkoutDetailViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var selectedDate = Date()
    @Published var workouts: [WorkoutData] = []
    @Published var errorMessage: String?
    @Published var showSyncError = false
    @Published var isSyncing = false
    @Published var syncMessage: String?
    @Published var showSyncWarnings = false
    @Published var syncWarnings: [String] = []

    private let healthRepository: HealthRepositoryProtocol
    private var syncUseCase: SyncHealthDataUseCaseProtocol

    init(healthRepository: HealthRepositoryProtocol, syncUseCase: SyncHealthDataUseCaseProtocol) {
        self.healthRepository = healthRepository
        self.syncUseCase = syncUseCase
    }

    func loadWorkouts() {
        Task {
            await fetchWorkouts()
        }
    }

    private func fetchWorkouts() async {
        isLoading = true
        errorMessage = nil

        let (data, _) = await healthRepository.fetchAllData(for: selectedDate)
        workouts = data.workouts
        isLoading = false
    }

    func syncWorkouts() {
        Task {
            await performSync()
        }
    }

    private func performSync() async {
        isSyncing = true
        syncMessage = "正在同步运动数据..."

        // Set up progress reporting
        syncUseCase.onProgress = { [weak self] progress in
            Task { @MainActor in
                self?.syncMessage = "正在同步 \(progress.currentDay)/\(progress.totalDays) 天数据..."
            }
        }

        do {
            let result = try await syncUseCase.syncData(for: selectedDate)
            isSyncing = false

            if result.success {
                syncMessage = "同步成功！已同步 \(result.totalRecords) 条记录"
                await fetchWorkouts()

                if !result.warnings.isEmpty {
                    syncWarnings = result.warnings
                    showSyncWarnings = true
                } else {
                    Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        syncMessage = nil
                    }
                }
            } else {
                errorMessage = result.errorMessage ?? "未知错误"
                showSyncError = true
                syncMessage = nil
            }
        } catch {
            isSyncing = false
            syncMessage = nil
            errorMessage = error.localizedDescription
            showSyncError = true
        }
    }

    func changeDay(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
            loadWorkouts()
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: selectedDate)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(selectedDate)
    }

    var canSelectNextDay: Bool {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) else {
            return false
        }
        return tomorrow <= Date()
    }

    var totalWorkouts: Int {
        workouts.count
    }

    var totalDuration: TimeInterval {
        workouts.reduce(0.0) { $0 + $1.duration }
    }

    var totalCalories: Double {
        workouts.compactMap { $0.energy }.reduce(0.0, +)
    }
}
