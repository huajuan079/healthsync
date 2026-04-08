import Foundation
import HealthKit
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var isConnected: Bool = true
    @Published var isSyncing: Bool = false
    @Published var lastSyncTime: Date?
    @Published var todaySummary: TodayHealthSummary?
    @Published var todayWorkouts: [WorkoutData] = []
    @Published var showSyncStatus: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String?

    private let healthRepository: HealthRepositoryProtocol
    private let syncUseCase: SyncHealthDataUseCase
    private var _syncViewModel: SyncViewModel?
    private var cancellables = Set<AnyCancellable>()

    var syncViewModel: SyncViewModel {
        if _syncViewModel == nil {
            _syncViewModel = SyncViewModel(syncUseCase: syncUseCase, healthRepository: healthRepository)
            setupSyncMonitoring()
        }
        return _syncViewModel!
    }

    init(container: AppContainer) {
        self.healthRepository = container.healthRepository
        self.syncUseCase = container.syncHealthDataUseCase
        loadLastSyncTime()
    }

    private func setupSyncMonitoring() {
        syncViewModel.$isSyncing
            .dropFirst()
            .sink { [weak self] syncing in
                guard let self = self else { return }
                if !syncing && self.isSyncing {
                    self.isSyncing = false
                    self.lastSyncTime = Date()
                    self.saveLastSyncTime()
                }
            }
            .store(in: &cancellables)

        syncViewModel.$showError
            .sink { [weak self] show in
                guard let self = self else { return }
                self.showError = show
                self.errorMessage = self.syncViewModel.errorMessage
            }
            .store(in: &cancellables)
    }

    func syncToday() {
        print("[HomeViewModel] syncToday() called")
        isSyncing = true
        syncViewModel.syncToday()
    }

    func syncLastWeek() {
        print("[HomeViewModel] syncLastWeek() called")
        isSyncing = true
        syncViewModel.syncLastWeek()
    }

    func syncLast30Days() {
        print("[HomeViewModel] syncLast30Days() called")
        isSyncing = true
        syncViewModel.syncLast30Days()
    }

    func loadTodaySummary() {
        Task {
            // Request HealthKit authorization proactively; system only shows dialog if not yet asked
            _ = try? await healthRepository.requestAuthorization()
            async let summary = healthRepository.getTodaySummary()
            async let allData = healthRepository.fetchAllData(for: Date())
            todaySummary = await summary
            todayWorkouts = await allData.data.workouts
        }
    }

    private func loadLastSyncTime() {
        if let t = UserDefaults.standard.object(forKey: "lastSyncTime") as? Date { lastSyncTime = t }
    }

    private func saveLastSyncTime() {
        if let t = lastSyncTime { UserDefaults.standard.set(t, forKey: "lastSyncTime") }
    }

    deinit {
        cancellables.removeAll()
    }
}
