import Foundation
import HealthKit

// MARK: - Health Data Protocol

protocol HealthData {}

// MARK: - Sleep Data

struct SleepData: HealthData, Codable {
    let date: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let type: SleepType
    let source: String?

    enum SleepType: String, Codable {
        case inBed
        case asleep
        case awake
        case asleepCore
        case asleepDeep
        case asleepREM
    }
}

struct HeartRateData: HealthData, Codable {
    let date: String
    let samples: [HeartSample]
    struct HeartSample: Codable { let timestamp: Date; let value: Double; let unit: String }
}

struct AllHealthData: Codable {
    let date: String
    let syncTime: Date
    let sleep: [SleepData]
    let heartRate: HeartRateData?
    let restingHeartRate: RestingHeartRateData?
    let hrv: HRVData?
    let steps: StepData?
    let workouts: [WorkoutData]
    let bloodOxygen: BloodOxygenData?
    let menstrual: [MenstrualData]
    let weight: WeightData?
    let medications: [MedicationData]
}

struct RestingHeartRateData: HealthData, Codable {
    let date: String
    let value: Double
    let timestamp: Date
}

struct HRVData: HealthData, Codable {
    let date: String
    let samples: [HRVSample]
    struct HRVSample: Codable { let timestamp: Date; let value: Double; let unit: String }
}

struct StepData: HealthData, Codable {
    let date: String
    let value: Int
    let distance: Double?
    let distanceUnit: String?
}

struct WorkoutData: HealthData, Codable, Hashable {
    let date: String
    let startDate: Date
    let endDate: Date
    let duration: TimeInterval
    let type: WorkoutType
    let distance: Double?
    let energy: Double?
    let source: String?

    enum WorkoutType: String, Codable, Hashable {
        case running, walking, cycling, swimming, hiking, yoga, fitness, other
    }
}

struct BloodOxygenData: HealthData, Codable {
    let date: String
    let samples: [OxygenSample]
    struct OxygenSample: Codable { let timestamp: Date; let value: Double; let unit: String }
}

struct WeightData: HealthData, Codable {
    let date: String
    let value: Double
    let unit: String
    let bmi: Double?
    let timestamp: Date
}

// MARK: - Menstrual Data

struct MenstrualData: HealthData, Codable {
    let date: String
    let startDate: Date
    let endDate: Date
    let flowLevel: FlowLevel?
    let symptoms: [String]?

    enum FlowLevel: String, Codable {
        case none
        case light
        case medium
        case heavy
    }
}

// MARK: - Medication Data

struct MedicationData: HealthData, Codable {
    let date: String
    let name: String
    let dosage: Double?
    let unit: String?
    let timestamp: Date
    let schedule: String?
}

