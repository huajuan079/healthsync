import Foundation
import HealthKit

// MARK: - Health Repository Protocol

protocol HealthRepositoryProtocol {
    func isHealthDataAvailable() -> Bool
    func requestAuthorization() async throws -> Bool
    func checkAuthorizationStatus() -> Bool
    func fetchAllData(for date: Date) async -> (data: AllHealthData, warnings: [String])
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
                    print("[HealthRepository] Authorization request error: \(error)")
                    continuation.resume(throwing: HealthError.queryError(error))
                } else {
                    // 注意：success 只表示请求是否完成，不表示用户是否授权
                    // 需要调用 checkAuthorizationStatus 来确认实际授权状态
                    print("[HealthRepository] Authorization request completed: \(success)")
                    print("[HealthRepository] Note: Please check actual authorization status using checkAuthorizationStatus()")
                    continuation.resume(returning: success)
                }
            }
        }
    }

    func checkAuthorizationStatus() -> Bool {
        // HealthKit does not expose read authorization status for privacy reasons.
        // authorizationStatus(for:) only reflects *write* permission, and returns
        // .sharingDenied when the app requests read-only access (toShare: nil).
        // The correct approach is to attempt data queries directly after requestAuthorization succeeds.
        return true
    }

    func fetchAllData(for date: Date) async -> (data: AllHealthData, warnings: [String]) {
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

        // New health data types
        async let wristTemperature = fetchWristTemperature(for: date)
        async let respiratoryRate = fetchRespiratoryRate(for: date)
        async let bodyTemperature = fetchBodyTemperature(for: date)
        async let bloodPressure = fetchBloodPressure(for: date)
        async let activeEnergyBurned = fetchActiveEnergyBurned(for: date)
        async let standHours = fetchStandHours(for: date)
        async let flightsClimbed = fetchFlightsClimbed(for: date)
        async let exerciseTime = fetchExerciseTime(for: date)

        let result = AllHealthData(
            date: dateString,
            syncTime: Date(),
            sleep: await sleep,
            heartRate: await heartRate,
            restingHeartRate: await restingHR,
            hrv: await hrv,
            steps: await steps,
            workouts: await workouts,
            bloodOxygen: await bloodOxygen,
            menstrual: await menstrual,
            weight: await weight,
            medications: await medications,
            wristTemperature: await wristTemperature,
            respiratoryRate: await respiratoryRate,
            bodyTemperature: await bodyTemperature,
            bloodPressure: await bloodPressure,
            activeEnergyBurned: await activeEnergyBurned,
            standHours: await standHours,
            flightsClimbed: await flightsClimbed,
            exerciseTime: await exerciseTime
        )
        print("[HealthRepository] fetchAllData completed, steps: \(result.steps?.value ?? -1)")
        return (data: result, warnings: [])
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
            let (data, _) = await fetchAllData(for: date)
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

        print("[HealthRepository] Fetching sleep data for date: \(date)")

        let calendar = Calendar.current
        // 睡眠数据通常跨午夜，所以查询前一天晚上到今天晚上
        // 例如查询 3月29日 的睡眠，范围是 3月28日 20:00 - 3月29日 20:00
        let startOfDay = calendar.startOfDay(for: date)
        guard let startRange = calendar.date(byAdding: .hour, value: -4, to: startOfDay) else {
            return []
        }
        guard let endRange = calendar.date(byAdding: .hour, value: 20, to: startOfDay) else {
            return []
        }

        print("[HealthRepository] Sleep query range: \(startRange) to \(endRange)")

        let predicate = HKQuery.predicateForSamples(withStart: startRange, end: endRange, options: [])

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

        // 直接尝试读取数据，不检查授权状态（authorizationStatus 有时不准确）
        print("[HealthRepository] Fetching heart rate data for date: \(date)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return HeartRateData(date: formatDate(date), samples: [])
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])

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

        print("[HealthRepository] Fetching resting heart rate data for date: \(date)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])

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

        print("[HealthRepository] Fetching HRV data for date: \(date)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return HRVData(date: formatDate(date), samples: [])
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])

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

        print("[HealthRepository] Fetching workouts data for date: \(date)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])

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

        print("[HealthRepository] Fetching blood oxygen data for date: \(date)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return BloodOxygenData(date: formatDate(date), samples: [])
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])

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
        guard let menstrualType = HKObjectType.categoryType(forIdentifier: .menstrualFlow) else {
            print("[HealthRepository] Menstrual flow type not available")
            return []
        }

        print("[HealthRepository] Fetching menstrual data for date: \(date)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return []
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: menstrualType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                let dateString = self.formatDate(date)

                if let error = error {
                    print("[HealthRepository] Menstrual data fetch error: \(error)")
                    continuation.resume(returning: [])
                    return
                }

                guard let menstrualSamples = samples as? [HKCategorySample] else {
                    continuation.resume(returning: [])
                    return
                }

                let result = menstrualSamples.compactMap { sample -> MenstrualData? in
                    let flowLevel: MenstrualData.FlowLevel
                    switch sample.value {
                    case HKCategoryValueMenstrualFlow.unspecified.rawValue:
                        flowLevel = .none
                    case HKCategoryValueMenstrualFlow.light.rawValue:
                        flowLevel = .light
                    case HKCategoryValueMenstrualFlow.medium.rawValue:
                        flowLevel = .medium
                    case HKCategoryValueMenstrualFlow.heavy.rawValue:
                        flowLevel = .heavy
                    default:
                        flowLevel = .none
                    }

                    return MenstrualData(
                        date: dateString,
                        startDate: sample.startDate,
                        endDate: sample.endDate,
                        flowLevel: flowLevel,
                        symptoms: nil
                    )
                }

                print("[HealthRepository] Menstrual data samples fetched: \(result.count)")
                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }

    private func fetchWeightData(for date: Date) async -> WeightData? {
        guard let weightType = HKQuantityType.quantityType(forIdentifier: .bodyMass) else {
            return nil
        }

        print("[HealthRepository] Fetching weight data for date: \(date)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])

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

    // MARK: - New Health Data Fetch Methods

    private func fetchWristTemperature(for date: Date) async -> WristTemperatureData? {
        guard #available(iOS 17.0, *),
              let tempType = HKQuantityType.quantityType(forIdentifier: .appleSleepingWristTemperature) else {
            return nil
        }

        print("[HealthRepository] Fetching wrist temperature for date: \(date)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: tempType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("[HealthRepository] Wrist temperature fetch error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let tempSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                let samples = tempSamples.map { sample in
                    WristTemperatureData.TemperatureSample(
                        timestamp: sample.startDate,
                        value: sample.quantity.doubleValue(for: .degreeCelsius()),
                        unit: "°C"
                    )
                }

                let result = WristTemperatureData(
                    date: self.formatDate(date),
                    samples: samples
                )

                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }

    private func fetchRespiratoryRate(for date: Date) async -> RespiratoryRateData? {
        guard #available(iOS 16.0, *),
              let respiratoryType = HKQuantityType.quantityType(forIdentifier: .respiratoryRate) else {
            return nil
        }

        print("[HealthRepository] Fetching respiratory rate for date: \(date)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: respiratoryType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("[HealthRepository] Respiratory rate fetch error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let respiratorySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                let samples = respiratorySamples.map { sample in
                    RespiratoryRateData.RespiratorySample(
                        timestamp: sample.startDate,
                        value: sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute())),
                        unit: "breaths/min"
                    )
                }

                let result = RespiratoryRateData(
                    date: self.formatDate(date),
                    samples: samples
                )

                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }

    private func fetchBodyTemperature(for date: Date) async -> BodyTemperatureData? {
        guard let tempType = HKQuantityType.quantityType(forIdentifier: .basalBodyTemperature) else {
            return nil
        }

        print("[HealthRepository] Fetching body temperature for date: \(date)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])

        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: tempType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, error in
                if let error = error {
                    print("[HealthRepository] Body temperature fetch error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let tempSamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                let samples = tempSamples.map { sample in
                    BodyTemperatureData.BodyTempSample(
                        timestamp: sample.startDate,
                        value: sample.quantity.doubleValue(for: .degreeCelsius()),
                        unit: "°C"
                    )
                }

                let result = BodyTemperatureData(
                    date: self.formatDate(date),
                    samples: samples
                )

                continuation.resume(returning: result)
            }

            healthStore.execute(query)
        }
    }

    private func fetchBloodPressure(for date: Date) async -> BloodPressureData? {
        guard let systolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureSystolic),
              let diastolicType = HKQuantityType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            return nil
        }

        print("[HealthRepository] Fetching blood pressure for date: \(date)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: [])

        // Fetch both systolic and diastolic
        return await withCheckedContinuation { continuation in
            let systolicQuery = HKSampleQuery(sampleType: systolicType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, systolicSamples, error in
                if let error = error {
                    print("[HealthRepository] Blood pressure systolic fetch error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                guard let systolicSamples = systolicSamples as? [HKQuantitySample] else {
                    continuation.resume(returning: nil)
                    return
                }

                // Match with diastolic readings
                var samples: [BloodPressureData.BloodPressureSample] = []

                for systolicSample in systolicSamples {
                    // Try to find corresponding diastolic reading (within 5 minutes)
                    let matchingDiastolic = systolicSamples.first { diastolicSample in
                        let timeDiff = abs(diastolicSample.startDate.timeIntervalSince(systolicSample.startDate))
                        return timeDiff < 300 // 5 minutes
                    }

                    if let diastolic = matchingDiastolic {
                        samples.append(BloodPressureData.BloodPressureSample(
                            timestamp: systolicSample.startDate,
                            systolicValue: systolicSample.quantity.doubleValue(for: .millimeterOfMercury()),
                            diastolicValue: diastolic.quantity.doubleValue(for: .millimeterOfMercury()),
                            unit: "mmHg"
                        ))
                    }
                }

                if samples.isEmpty {
                    continuation.resume(returning: nil)
                } else {
                    let result = BloodPressureData(
                        date: self.formatDate(date),
                        samples: samples
                    )
                    continuation.resume(returning: result)
                }
            }

            healthStore.execute(systolicQuery)
        }
    }

    private func fetchActiveEnergyBurned(for date: Date) async -> ActiveEnergyData? {
        guard #available(iOS 16.0, *),
              let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else {
            return nil
        }

        print("[HealthRepository] Fetching active energy burned for date: \(date)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: energyType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error = error {
                    print("[HealthRepository] Active energy burned fetch error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                let totalEnergy = statistics?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0

                if totalEnergy > 0 {
                    let result = ActiveEnergyData(
                        date: self.formatDate(date),
                        value: totalEnergy,
                        unit: "kcal"
                    )
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(returning: nil)
                }
            }

            healthStore.execute(query)
        }
    }

    private func fetchStandHours(for date: Date) async -> StandHoursData? {
        // Stand hours are not directly available as samples
        // We'll need to use a different approach or skip for now
        return nil
    }

    private func fetchFlightsClimbed(for date: Date) async -> FlightsClimbedData? {
        guard #available(iOS 16.0, *),
              let flightsType = HKQuantityType.quantityType(forIdentifier: .flightsClimbed) else {
            return nil
        }

        print("[HealthRepository] Fetching flights climbed for date: \(date)")

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return nil
        }

        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: endOfDay, options: .strictStartDate)

        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: flightsType, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, statistics, error in
                if let error = error {
                    print("[HealthRepository] Flights climbed fetch error: \(error)")
                    continuation.resume(returning: nil)
                    return
                }

                let totalFlights = statistics?.sumQuantity()?.doubleValue(for: .count()) ?? 0

                if totalFlights > 0 {
                    let result = FlightsClimbedData(
                        date: self.formatDate(date),
                        value: totalFlights,
                        unit: "flights"
                    )
                    continuation.resume(returning: result)
                } else {
                    continuation.resume(returning: nil)
                }
            }

            healthStore.execute(query)
        }
    }

    private func fetchExerciseTime(for date: Date) async -> ExerciseTimeData? {
        // Exercise time is not directly available as samples
        // We'll need to use a different approach or skip for now
        return nil
    }

}
