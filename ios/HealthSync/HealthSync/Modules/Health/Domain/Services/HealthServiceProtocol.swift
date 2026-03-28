import Foundation
import HealthKit

// MARK: - Health Service Protocol

protocol HealthServiceProtocol {
    func requestAuthorization() async throws -> Bool
    func isHealthDataAvailable() -> Bool

    func fetchSleepData(for date: Date) async throws -> [SleepData]
    func fetchHeartRateData(for date: Date) async throws -> HeartRateData
    func fetchRestingHeartRate(for date: Date) async throws -> RestingHeartRateData?
    func fetchHRVData(for date: Date) async throws -> HRVData
    func fetchStepData(for date: Date) async throws -> StepData?
    func fetchWorkouts(for date: Date) async throws -> [WorkoutData]
    func fetchBloodOxygenData(for date: Date) async throws -> BloodOxygenData
    func fetchMenstrualData(for date: Date) async throws -> [MenstrualData]
    func fetchWeightData(for date: Date) async throws -> WeightData?
    func fetchMedicationData(for date: Date) async throws -> [MedicationData]
    func fetchMindfulnessData(for date: Date) async throws -> [MindfulnessData]

    func fetchAllHealthData(for date: Date) async throws -> AllHealthData
    func fetchHealthDataRange(from startDate: Date, to endDate: Date) async throws -> [AllHealthData]
}

// MARK: - Health Query Factory

final class HealthQueryFactory {
    static let shared = HealthQueryFactory()

    // Data types to read
    lazy var dataTypesToRead: Set<HKObjectType> = {
        var types = Set<HKObjectType>()

        if #available(iOS 16.0, *) {
            types.insert(HKQuantityType(.heartRate))
            types.insert(HKQuantityType(.restingHeartRate))
            types.insert(HKQuantityType(.heartRateVariabilitySDNN))
            types.insert(HKQuantityType(.stepCount))
            types.insert(HKQuantityType(.distanceWalkingRunning))
            types.insert(HKQuantityType(.oxygenSaturation))
            types.insert(HKQuantityType(.bodyMass))
            types.insert(HKQuantityType(.bodyMassIndex))
        }

        types.insert(HKObjectType.workoutType())
        types.insert(HKCategoryType(.sleepAnalysis))

        if #available(iOS 17.0, *) {
            // types.insert(HKCategoryType(.sexualActivity))
        }

        return types
    }()
}

// MARK: - Health Error

enum HealthError: LocalizedError {
    case notAvailable
    case authorizationDenied
    case authorizationNotDetermined
    case dataNotAvailable
    case queryError(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "健康数据不可用"
        case .authorizationDenied:
            return "健康数据访问被拒绝"
        case .authorizationNotDetermined:
            return "未授权健康数据访问"
        case .dataNotAvailable:
            return "没有可用的健康数据"
        case .queryError(let error):
            return "查询错误: \(error.localizedDescription)"
        case .unknown:
            return "未知错误"
        }
    }
}
