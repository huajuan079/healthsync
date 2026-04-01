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

    // New health data types
    let wristTemperature: WristTemperatureData?
    let respiratoryRate: RespiratoryRateData?
    let bodyTemperature: BodyTemperatureData?
    let bloodPressure: BloodPressureData?
    let activeEnergyBurned: ActiveEnergyData?
    let standHours: StandHoursData?
    let flightsClimbed: FlightsClimbedData?
    let exerciseTime: ExerciseTimeData?
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

// MARK: - Wrist Temperature Data

struct WristTemperatureData: HealthData, Codable {
    let date: String
    let samples: [TemperatureSample]
    struct TemperatureSample: Codable { let timestamp: Date; let value: Double; let unit: String }
}

// MARK: - Respiratory Rate Data

struct RespiratoryRateData: HealthData, Codable {
    let date: String
    let samples: [RespiratorySample]
    struct RespiratorySample: Codable { let timestamp: Date; let value: Double; let unit: String }
}

// MARK: - Body Temperature Data

struct BodyTemperatureData: HealthData, Codable {
    let date: String
    let samples: [BodyTempSample]
    struct BodyTempSample: Codable { let timestamp: Date; let value: Double; let unit: String }
}

// MARK: - Blood Pressure Data

struct BloodPressureData: HealthData, Codable {
    let date: String
    let samples: [BloodPressureSample]
    struct BloodPressureSample: Codable {
        let timestamp: Date
        let systolicValue: Double
        let diastolicValue: Double
        let unit: String
    }
}

// MARK: - Active Energy Burned Data

struct ActiveEnergyData: HealthData, Codable {
    let date: String
    let value: Double
    let unit: String
}

// MARK: - Stand Hours Data

struct StandHoursData: HealthData, Codable {
    let date: String
    let value: Int
}

// MARK: - Flights Climbed Data

struct FlightsClimbedData: HealthData, Codable {
    let date: String
    let value: Double
    let unit: String
}

// MARK: - Exercise Time Data

struct ExerciseTimeData: HealthData, Codable {
    let date: String
    let value: TimeInterval
    let unit: String
}

