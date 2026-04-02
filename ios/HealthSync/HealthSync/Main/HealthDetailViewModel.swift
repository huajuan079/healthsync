import Foundation
import HealthKit

@MainActor
final class HealthDetailViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var selectedDate = Date()
    @Published var healthData: AllHealthData?
    @Published var errorMessage: String?

    private let healthRepository: HealthRepositoryProtocol

    init(healthRepository: HealthRepositoryProtocol) {
        self.healthRepository = healthRepository
    }

    func loadHealthData() {
        Task {
            await fetchHealthData()
        }
    }

    private func fetchHealthData() async {
        isLoading = true
        errorMessage = nil

        // Check authorization status first
        let isAuthorized = healthRepository.checkAuthorizationStatus()
        print("[HealthDetailViewModel] Authorization status: \(isAuthorized)")

        if !isAuthorized {
            print("[HealthDetailViewModel] Requesting authorization...")
            do {
                let granted = try await healthRepository.requestAuthorization()
                print("[HealthDetailViewModel] Authorization granted: \(granted)")

                // Re-check actual authorization status after request
                let nowAuthorized = healthRepository.checkAuthorizationStatus()
                if !nowAuthorized {
                    errorMessage = "需要授权访问健康数据"
                    isLoading = false
                    return
                }
            } catch {
                print("[HealthDetailViewModel] Authorization error: \(error)")
                errorMessage = "授权失败: \(error.localizedDescription)"
                isLoading = false
                return
            }
        }

        let (data, _) = await healthRepository.fetchAllData(for: selectedDate)
        healthData = data
        isLoading = false
    }

    func changeDay(by days: Int) {
        if let newDate = Calendar.current.date(byAdding: .day, value: days, to: selectedDate) {
            selectedDate = newDate
            loadHealthData()
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
}
