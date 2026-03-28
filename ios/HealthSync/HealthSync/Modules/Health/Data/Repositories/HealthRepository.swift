import Foundation
import HealthKit

// MARK: - Health Repository Protocol

protocol HealthRepositoryProtocol {
    func isHealthDataAvailable() -> Bool
    func requestAuthorization() async throws -> Bool
    func checkAuthorizationStatus() -> Bool
    func fetchAllData(for date: Date) async -> AllHealthData
    func fetchDataRange(from startDate: Date, to endDate: Date) async -> [AllHealthData]
    func getTodaySummary() async -> TodayHealthSummary
}

// MARK: - Today's Health Summary

struct TodayHealthSummary {
    let steps: Int
    let restingHeartRate: Double?
    let sleepDuration: TimeInterval?
    let syncTime: Date
}

// MARK: - Health Repository

final class HealthRepository: HealthRepositoryProtocol {
    private let healthStore: HKHealthStore

    init(healthStore: HKHealthStore) {
        self.healthStore = healthStore
    }

    func isHealthDataAvailable() -> Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    func requestAuthorization() async throws -> Bool {
        guard isHealthDataAvailable() else {
            throw HealthError.notAvailable
        }

        let typesToRead = HealthQueryFactory.shared.dataTypesToRead
        print("[HealthRepository] Requesting authorization for \(typesToRead.count) types")

        return try await withCheckedThrowingContinuation { continuation in
            healthStore.requestAuthorization(toShare: nil, read: typesToRead) { success, error in
                if let error = error {
                    print("[HealthRepository] Authorization error: \(error)")
                    continuation.resume(throwing: HealthError.queryError(error))
                } else {
                    print("[HealthRepository] Authorization success: \(success)")
                    continuation.resume(returning: success)
                }
            }
        }
    }

    func checkAuthorizationStatus() -> Bool {
        let typesToRead = HealthQueryFactory.shared.dataTypesToRead
        var allAuthorized = true

        for type in typesToRead {
            let status = healthStore.authorizationStatus(for: type)
            print("[HealthRepository] Auth status for \(type): \(status)")
            if status == .notDetermined {
                allAuthorized = false
            }
        }

        return allAuthorized
    }

    func fetchAllData(for date: Date) async -> AllHealthData {
        print("[HealthRepository] fetchAllData called for date: \(date)")
        let dateString = formatDate(date)

        print("[HealthRepository] Starting parallel data fetch...")
        async let sleep = fetchSleepData(for: date)
        async let heartRate = fetchHeartRateData(for: date)
        async let restingHR = fetchRestingHeartRate(for: date)
        async let hrv = fetchHRVData(for: date)
        async let steps = fetchStepData(for: date)
        async let workouts = fetchWorkouts(for: date)
        async let bloodOxygen = fetchBloodOxygenData(for: date)
        async let menstrual = fetchMenstrualData(for: date)
        async let weight = fetchWeightData(for: date)
        async let medications = fetchMedicationData(for: date)
        async let mindfulness = fetchMindfulnessData(for: date)

        let result = await AllHealthData(
            date: dateString,
            syncTime: Date(),
            sleep: sleep,
            heartRate: heartRate,
            restingHeartRate: restingHR,
            hrv: hrv,
            steps: steps,
            workouts: workouts,
            bloodOxygen: bloodOxygen,
            menstrual: menstrual,
            weight: weight,
            medications: medications,
            mindfulness: mindfulness
        )
        print("[HealthRepository] fetchAllData completed, steps: \(result.steps?.value ?? -1)")
        return result
    }

    func fetchDataRange(from startDate: Date, to endDate: Date) async -> [AllHealthData] {
        var dates: [Date] = []
        var currentDate = startDate

        while currentDate <= endDate {
            dates.append(currentDate)
            guard let nextDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }

        var result: [AllHealthData] = []

        for date in dates {
            let data = await fetchAllData(for: date)
            result.append(data)
        }

        return result
    }

    func getTodaySummary() async -> TodayHealthSummary {
        let today = Date()

        async let steps = fetchStepData(for: today)
        async let restingHR = fetchRestingHeartRate(for: today)
        async let sleep = fetchSleepData(for: today)

        let stepsData = await steps
        let restingHRData = await restingHR
        let sleepData = await sleep

        let totalSleepDuration = sleepData.reduce(0.0) { sum, item in
            if item.type == .asleep || item.type == .asleepCore || item.type == .asleepDeep || item.type == .asleepREM {
                return sum + item.duration
            }
            return sum
        }

        return TodayHealthSummary(
            steps: stepsData?.value ?? 0,
            restingHeartRate: restingHRData?.value,
            sleepDuration: totalSleepDuration > 0 ? totalSleepDuration : nil,
            syncTime: Date()
        )
    }

    // MARK: - Private Helper Methods

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    // MARK: - Private Fetch Methods

    private func fetchSleepData(for date: Date) async -> [SleepData] {
        guard let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            return []
        }

        // Check authorization status
        let authStatus = healthStore.authorizationStatus(for: sleepType)
        if authStatus == .notDetermined || authStatus == .sharingDenied {
            print("[HealthRepository] Sleep not authorized, returning empty")
            return []
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                let dateString = self.formatDate(date)

                if let error = error {
                    print("[HealthRepository] Sleep fetch error: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                guard let sleepSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let result = sleepSamples.compactMap { sample -> SleepData? in
                    let type: SleepData.SleepType
                    if #available(iOS 16.0, *) {
                        switch sample.value {
                        case 0: type = .inBed
                        case 1: type = .asleep
                        case 2: type = .awake
                        case 3: type = .asleepCore
                        case 4: type = .asleepDeep
                        case 5: type = .asleepREM
                        default: return nil
                        }
                    } else {
                        switch sample.value {
                        case 0: type = .inBed
                        case 1: type = .asleep
                        default: return nil
                        }
                    }

                    return SleepData(
                        date: dateString,
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        duration: sample.endDate.timeIntervalSince(sample.startDate),
                        type: type,
                        source: sample.sourceRevision.source.name
                    )
                }

                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }

    private func fetchHeartRateData(for date: Date) async -> HeartRateData {
        guard let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate) else {
            print("[HealthRepository] Heart rate type not available")
            return HeartRateData(date: formatDate(date), samples: [])
        }

        // Check authorization status
        let authStatus = healthStore.authorizationStatus(for: heartRateType)
        print("[HealthRepository] Heart rate auth status: \(authStatus.rawValue)")
        if authStatus == .notDetermined || authStatus == .sharingDenied {
            print("[HealthRepository] Heart rate not authorized, returning empty")
            return HeartRateData(date: formatDate(date), samples: [])
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return HeartRateData(date: formatDate(date), samples: [])
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: heartRateType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                let dateString = self.formatDate(date)

                if let error = error {
                    print("[HealthRepository] Heart rate fetch error: \(error)")
                    continuation.resume(returning: HeartRateData(date: dateString, samples: []))
                    return
                }

                guard let heartSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: HeartRateData(date: dateString, samples: []))
                    return
                }

                let samples = heartSamples.map { sample in
                    HeartRateData.HeartSample(
                        timestamp: sample.startDate,
                        value: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                        unit: "count/min"
                    )
                }

                print("[HealthRepository] Heart rate samples fetched: \(samples.count)")
                continuation.resume(returning: HeartRateData(date: dateString, samples: samples))
            }

            self.healthStore.execute(query)
        }
    }

    private func fetchRestingHeartRate(for date: Date) async -> RestingHeartRateData? {
        guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else {
            return nil
        }

        // Check authorization status
        let authStatus = healthStore.authorizationStatus(for: restingHRType)
        if authStatus == .notDetermined || authStatus == .sharingDenied {
            print("[HealthRepository] Resting heart rate not authorized, returning nil")
            return nil
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: restingHRType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("[HealthRepository] Resting heart rate fetch error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let dateString = self.formatDate(date)

                let result = RestingHeartRateData(
                    date: dateString,
                    value: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                    timestamp: sample.startDate
                )

                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }

    private func fetchHRVData(for date: Date) async -> HRVData {
        guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return HRVData(date: formatDate(date), samples: [])
        }

        // Check authorization status
        let authStatus = healthStore.authorizationStatus(for: hrvType)
        if authStatus == .notDetermined || authStatus == .sharingDenied {
            print("[HealthRepository] HRV not authorized, returning empty")
            return HRVData(date: formatDate(date), samples: [])
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return HRVData(date: formatDate(date), samples: [])
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: hrvType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                let dateString = self.formatDate(date)

                if let error = error {
                    print("[HealthRepository] HRV fetch error: \(error)")
                    continuation.resume(returning: HRVData(date: dateString, samples: []))
                    return
                }

                guard let hrvSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: HRVData(date: dateString, samples: []))
                    return
                }

                let samples = hrvSamples.map { sample in
                    HRVData.HRVSample(
                        timestamp: sample.startDate,
                        value: sample.quantity.doubleValue(for: HKUnit.secondUnit(with: .milli)),
                        unit: "ms"
                    )
                }

                continuation.resume(returning: HRVData(date: dateString, samples: samples))
            }

            healthStore.execute(query)
        }
    }

    private func fetchStepData(for date: Date) async -> StepData? {
        print("[HealthRepository] fetchStepData called for date: \(date)")
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
            print("[HealthRepository] stepType not available")
            return nil
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            print("[HealthRepository] could not calculate endOfDay")
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { (continuation: CheckedContinuation<StepData?, Never>) in
            let query = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"
                let dateString = dateFormatter.string(from: date)

                if let error = error {
                    print("[HealthRepository] fetchStepData error: \(error)")
                }

                let stepCount = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                print("[HealthRepository] fetchStepData stepCount: \(stepCount)")

                let result = StepData(
                    date: dateString,
                    value: Int(stepCount),
                    distance: nil,
                    distanceUnit: nil
                )

                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }

    private func fetchWorkouts(for date: Date) async -> [WorkoutData] {
        let workoutType = HKObjectType.workoutType()

        // Check authorization status
        let authStatus = healthStore.authorizationStatus(for: workoutType)
        if authStatus == .notDetermined || authStatus == .sharingDenied {
            print("[HealthRepository] Workouts not authorized, returning empty")
            return []
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: workoutType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("[HealthRepository] Workouts fetch error: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                guard let workouts = samples as? [HKWorkout] else {
                    continuation.resume(returning: [])
                    return
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"

                let result = workouts.map { workout in
                    let type: WorkoutData.WorkoutType
                    switch workout.workoutActivityType {
                    case .running:
                        type = .running
                    case .walking:
                        type = .walking
                    case .cycling:
                        type = .cycling
                    case .swimming:
                        type = .swimming
                    case .hiking:
                        type = .hiking
                    case .yoga:
                        type = .yoga
                    case .functionalStrengthTraining, .traditionalStrengthTraining, .crossTraining:
                        type = .fitness
                    default:
                        type = .other
                    }

                    return WorkoutData(
                        date: dateFormatter.string(from: workout.startDate),
                        startDate: workout.startDate,
                        endDate: workout.endDate,
                        duration: workout.duration,
                        type: type,
                        distance: workout.totalDistance?.doubleValue(for: .meter()),
                        energy: workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()),
                        source: workout.sourceRevision.source.name
                    )
                }

                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }

    private func fetchBloodOxygenData(for date: Date) async -> BloodOxygenData {
        guard let oxygenType = HKQuantityType.quantityType(forIdentifier: .oxygenSaturation) else {
            return BloodOxygenData(date: formatDate(date), samples: [])
        }

        // Check authorization status
        let authStatus = healthStore.authorizationStatus(for: oxygenType)
        if authStatus == .notDetermined || authStatus == .sharingDenied {
            print("[HealthRepository] Blood oxygen not authorized, returning empty")
            return BloodOxygenData(date: formatDate(date), samples: [])
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return BloodOxygenData(date: formatDate(date), samples: [])
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: oxygenType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                let dateString = self.formatDate(date)

                if let error = error {
                    print("[HealthRepository] Blood oxygen fetch error: \(error)")
                    continuation.resume(returning: BloodOxygenData(date: dateString, samples: []))
                    return
                }

                guard let oxygenSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: BloodOxygenData(date: dateString, samples: []))
                    return
                }

                let samples = oxygenSamples.map { sample in
                    BloodOxygenData.OxygenSample(
                        timestamp: sample.startDate,
                        value: sample.quantity.doubleValue(for: HKUnit.percent()),
                        unit: "%"
                    )
                }

                continuation.resume(returning: BloodOxygenData(date: dateString, samples: samples))
            }

            healthStore.execute(query)
        }
    }

    private func fetchMenstrualData(for date: Date) async -> [MenstrualData] {
        // Menstrual data access may require iOS 17+
        return []
    }

    private func fetchWeightData(for date: Date) async -> WeightData? {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }

        // Check authorization status
        let authStatus = healthStore.authorizationStatus(for: weightType)
        if authStatus == .notDetermined || authStatus == .sharingDenied {
            print("[HealthRepository] Weight not authorized, returning nil")
            return nil
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: weightType, predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("[HealthRepository] Weight fetch error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }

                let dateString = self.formatDate(date)

                let result = WeightData(
                    date: dateString,
                    value: sample.quantity.doubleValue(for: .gram()) / 1000,
                    unit: "kg",
                    bmi: nil,
                    timestamp: sample.startDate
                )

                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }

    private func fetchMedicationData(for date: Date) async -> [MedicationData] {
        return []
    }

    private func fetchMindfulnessData(for date: Date) async -> [MindfulnessData] {
        guard let mindfulType = HKObjectType.categoryType(forIdentifier: .mindfulSession) else {
            return []
        }

        // Check authorization status
        let authStatus = healthStore.authorizationStatus(for: mindfulType)
        if authStatus == .notDetermined || authStatus == .sharingDenied {
            print("[HealthRepository] Mindfulness not authorized, returning empty")
            return []
        }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: mindfulType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("[HealthRepository] Mindfulness fetch error: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                guard let mindfulSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd"

                let result = mindfulSamples.map { sample in
                    MindfulnessData(
                        date: dateFormatter.string(from: sample.startDate),
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        duration: sample.endDate.timeIntervalSince(sample.startDate),
                        type: .meditation
                    )
                }

                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }
}
