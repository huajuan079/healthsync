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
    @Published var showSyncStatus: Bool = false

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
        // Use Combine to monitor sync state changes efficiently
        syncViewModel.$isSyncing
            .dropFirst() // Skip initial value
            .sink { [weak self] syncing in
                guard let self = self else { return }
                if !syncing && self.isSyncing {
                    self.isSyncing = false
                    self.lastSyncTime = Date()
                    self.saveLastSyncTime()
                }
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
            let summary = await healthRepository.getTodaySummary()
            todaySummary = summary
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
