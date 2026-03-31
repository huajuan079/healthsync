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
