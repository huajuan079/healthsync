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

    // New health data types
    func fetchWristTemperature(for date: Date) async throws -> WristTemperatureData?
    func fetchRespiratoryRate(for date: Date) async throws -> RespiratoryRateData?
    func fetchBodyTemperature(for date: Date) async throws -> BodyTemperatureData?
    func fetchBloodPressure(for date: Date) async throws -> BloodPressureData?
    func fetchActiveEnergyBurned(for date: Date) async throws -> ActiveEnergyData?
    func fetchStandHours(for date: Date) async throws -> StandHoursData?
    func fetchFlightsClimbed(for date: Date) async throws -> FlightsClimbedData?
    func fetchExerciseTime(for date: Date) async throws -> ExerciseTimeData?

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
            // Existing types
            types.insert(HKQuantityType(.heartRate))
            types.insert(HKQuantityType(.restingHeartRate))
            types.insert(HKQuantityType(.heartRateVariabilitySDNN))
            types.insert(HKQuantityType(.stepCount))
            types.insert(HKQuantityType(.distanceWalkingRunning))
            types.insert(HKQuantityType(.oxygenSaturation))
            types.insert(HKQuantityType(.bodyMass))
            types.insert(HKQuantityType(.bodyMassIndex))

            // Body metrics
            types.insert(HKQuantityType(.respiratoryRate))
            types.insert(HKQuantityType(.basalBodyTemperature))
            types.insert(HKQuantityType(.bloodPressureSystolic))
            types.insert(HKQuantityType(.bloodPressureDiastolic))

            // Activity metrics
            types.insert(HKQuantityType(.activeEnergyBurned))
            types.insert(HKQuantityType(.flightsClimbed))
        }

        types.insert(HKObjectType.workoutType())
        types.insert(HKCategoryType(.sleepAnalysis))
        types.insert(HKCategoryType(.menstrualFlow))

        if #available(iOS 17.0, *) {
            types.insert(HKQuantityType(.appleSleepingWristTemperature))
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
