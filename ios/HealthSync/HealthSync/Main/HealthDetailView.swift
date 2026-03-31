import SwiftUI

struct HealthDetailView: View {
    @EnvironmentObject var container: AppContainer
    @StateObject private var viewModel: HealthDetailViewModel

    init(container: AppContainer) {
        self._viewModel = StateObject(wrappedValue: HealthDetailViewModel(healthRepository: container.healthRepository))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.healthData == nil {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.appAccent))
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            DateSelectorView(
                                currentDate: viewModel.formattedDate,
                                isToday: viewModel.isToday,
                                canSelectNextDay: viewModel.canSelectNextDay,
                                onPreviousDay: { viewModel.changeDay(by: -1) },
                                onNextDay: { viewModel.changeDay(by: 1) }
                            )

                            if let data = viewModel.healthData {
                                HealthDataCardsView(data: data)
                            } else {
                                EmptyStateView(onLoadData: { viewModel.loadHealthData() })
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if viewModel.healthData == nil {
                viewModel.loadHealthData()
            }
        }
    }
}

// MARK: - Date Selector

struct DateSelectorView: View {
    let currentDate: String
    let isToday: Bool
    let canSelectNextDay: Bool
    let onPreviousDay: () -> Void
    let onNextDay: () -> Void

    var body: some View {
        HStack {
            Button(action: onPreviousDay) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.appAccent)
                    .font(.title2)
            }

            Text(currentDate)
                .font(.headline)
                .foregroundColor(.text)
                .frame(maxWidth: .infinity)

            Button(action: onNextDay) {
                Image(systemName: "chevron.right")
                    .foregroundColor(canSelectNextDay ? .appAccent : .tertiaryText)
                    .font(.title2)
            }
            .disabled(!canSelectNextDay)
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }
}

// MARK: - Health Data Cards

struct HealthDataCardsView: View {
    let data: AllHealthData

    var body: some View {
        VStack(spacing: 20) {
            // 步数卡片
            if let steps = data.steps {
                StepsMetricCard(
                    icon: "figure.walk",
                    title: "步数",
                    value: "\(steps.value)",
                    unit: "步",
                    color: .stepsColor
                )
            }

            // 心率卡片
            if let heartRate = data.heartRate, !heartRate.samples.isEmpty {
                HeartRateDetailCard(samples: heartRate.samples)
            }

            // 静息心率
            if let restingHR = data.restingHeartRate {
                RestingHeartRateCard(
                    icon: "heart.fill",
                    title: "静息心率",
                    value: "\(Int(restingHR.value))",
                    unit: "bpm",
                    color: .heartRateColor
                )
            }

            // HRV
            if let hrv = data.hrv, !hrv.samples.isEmpty {
                HRVDetailCard(samples: hrv.samples)
            }

            // 睡眠卡片
            if !data.sleep.isEmpty {
                SleepDetailCard(sleepData: data.sleep)
            }

            // 运动卡片
            if !data.workouts.isEmpty {
                WorkoutListCard(workouts: data.workouts)
            }

            // 血氧
            if let bloodOxygen = data.bloodOxygen, !bloodOxygen.samples.isEmpty {
                BloodOxygenCard(samples: bloodOxygen.samples)
            }

            // 体重
            if let weight = data.weight {
                WeightMetricCard(
                    icon: "scalemass",
                    title: "体重",
                    value: String(format: "%.1f", weight.value),
                    unit: weight.unit,
                    color: .appAccent
                )
            }
        }
    }
}

// MARK: - Individual Metric Cards

struct StepsMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)

                HStack(spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.text)
                    Text(unit)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }
}

struct RestingHeartRateCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)

                HStack(spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.text)
                    Text(unit)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }
}

struct WeightMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)

                HStack(spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.text)
                    Text(unit)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }
}

// MARK: - Heart Rate Detail Card

struct HeartRateDetailCard: View {
    let samples: [HeartRateData.HeartSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.heartRateColor)
                    .font(.title2)
                Text("心率")
                    .font(.headline)
                    .foregroundColor(.text)
                Spacer()
                if let avg = averageHeartRate {
                    Text("平均 \(Int(avg)) bpm")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }

            if samples.count > 1, let min = samples.map({ $0.value }).min(),
               let max = samples.map({ $0.value }).max() {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(Int(min))")
                            .font(.headline)
                            .foregroundColor(.text)
                        Text("最低")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    VStack(spacing: 4) {
                        Text("\(Int(max))")
                            .font(.headline)
                            .foregroundColor(.text)
                        Text("最高")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }

    var averageHeartRate: Double? {
        guard !samples.isEmpty else { return nil }
        let total = samples.reduce(0.0) { $0 + $1.value }
        return total / Double(samples.count)
    }
}

// MARK: - HRV Detail Card

struct HRVDetailCard: View {
    let samples: [HRVData.HRVSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "waveform.path")
                    .foregroundColor(.sleepColor)
                    .font(.title2)
                Text("心率变异性")
                    .font(.headline)
                    .foregroundColor(.text)
                Spacer()
                if let avg = averageHRV {
                    Text("平均 \(Int(avg)) ms")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }

            if samples.count > 1, let min = samples.map({ $0.value }).min(),
               let max = samples.map({ $0.value }).max() {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(Int(min))")
                            .font(.headline)
                            .foregroundColor(.text)
                        Text("最低")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    VStack(spacing: 4) {
                        Text("\(Int(max))")
                            .font(.headline)
                            .foregroundColor(.text)
                        Text("最高")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }

    var averageHRV: Double? {
        guard !samples.isEmpty else { return nil }
        let total = samples.reduce(0.0) { $0 + $1.value }
        return total / Double(samples.count)
    }
}

// MARK: - Sleep Detail Card

struct SleepDetailCard: View {
    let sleepData: [SleepData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "bed.double.fill")
                    .foregroundColor(.sleepColor)
                    .font(.title2)
                Text("睡眠")
                    .font(.headline)
                    .foregroundColor(.text)
                Spacer()
                if let total = totalSleepDuration {
                    Text("\(total)小时")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                if let inBed = durationForType(.inBed) {
                    SleepRow(type: "在床", duration: inBed)
                }
                if let asleep = durationForType(.asleep) {
                    SleepRow(type: "入睡", duration: asleep)
                }
                if let deep = durationForType(.asleepDeep) {
                    SleepRow(type: "深睡", duration: deep, color: .sleepColor)
                }
                if let rem = durationForType(.asleepREM) {
                    SleepRow(type: "REM", duration: rem, color: .appAccent)
                }
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }

    var totalSleepDuration: String? {
        let total = sleepData.reduce(0.0) { sum, item in
            if item.type == .asleep || item.type == .asleepCore || item.type == .asleepDeep || item.type == .asleepREM {
                return sum + item.duration
            }
            return sum
        }
        guard total > 0 else { return nil }
        return String(format: "%.1f", total / 3600)
    }

    func durationForType(_ type: SleepData.SleepType) -> TimeInterval? {
        let total = sleepData.filter { $0.type == type }
            .reduce(0.0) { $0 + $1.duration }
        return total > 0 ? total : nil
    }
}

struct SleepRow: View {
    let type: String
    let duration: TimeInterval
    var color: Color = .secondaryText

    var body: some View {
        HStack {
            Text(type)
                .font(.subheadline)
                .foregroundColor(.secondaryText)
            Spacer()
            Text(formatDuration(duration))
                .font(.subheadline)
                .foregroundColor(color)
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        if hours > 0 {
            return "\(hours)小时\(minutes)分"
        }
        return "\(minutes)分钟"
    }
}

// MARK: - Workout List Card

struct WorkoutListCard: View {
    let workouts: [WorkoutData]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "figure.run")
                    .foregroundColor(.energyColor)
                    .font(.title2)
                Text("运动")
                    .font(.headline)
                    .foregroundColor(.text)
                Spacer()
                Text("\(workouts.count)次")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
            }

            VStack(spacing: 8) {
                ForEach(Array(workouts.enumerated()), id: \.element.startDate) { index, workout in
                    WorkoutRow(workout: workout)
                    if index < workouts.count - 1 {
                        Divider()
                            .background(Color.tertiaryBackground)
                    }
                }
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }
}

struct WorkoutRow: View {
    let workout: WorkoutData

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: workoutIcon)
                .foregroundColor(.energyColor)
                .font(.title3)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(workoutTitle)
                    .font(.subheadline)
                    .foregroundColor(.text)
                Text(workoutDuration)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }

            Spacer()

            if let energy = workout.energy {
                Text("\(Int(energy)) kcal")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
    }

    var workoutIcon: String {
        switch workout.type {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "bicycle"
        case .swimming: return "figure.pool.swim"
        case .hiking: return "figure.hiking"
        case .yoga: return "figure.yoga"
        case .fitness: return "dumbbell.fill"
        case .other: return "figure.strengthtraining.traditional"
        }
    }

    var workoutTitle: String {
        switch workout.type {
        case .running: return "跑步"
        case .walking: return "步行"
        case .cycling: return "骑行"
        case .swimming: return "游泳"
        case .hiking: return "徒步"
        case .yoga: return "瑜伽"
        case .fitness: return "健身"
        case .other: return "其他运动"
        }
    }

    var workoutDuration: String {
        let minutes = Int(workout.duration) / 60
        return "\(minutes)分钟"
    }
}

// MARK: - Blood Oxygen Card

struct BloodOxygenCard: View {
    let samples: [BloodOxygenData.OxygenSample]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.appAccent)
                    .font(.title2)
                Text("血氧")
                    .font(.headline)
                    .foregroundColor(.text)
                Spacer()
                if let avg = averageOxygen {
                    Text("平均 \(Int(avg * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }

            if samples.count > 1, let min = samples.map({ $0.value }).min(),
               let max = samples.map({ $0.value }).max() {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(Int(min * 100))%")
                            .font(.headline)
                            .foregroundColor(.text)
                        Text("最低")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    VStack(spacing: 4) {
                        Text("\(Int(max * 100))%")
                            .font(.headline)
                            .foregroundColor(.text)
                        Text("最高")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }

    var averageOxygen: Double? {
        guard !samples.isEmpty else { return nil }
        let total = samples.reduce(0.0) { $0 + $1.value }
        return total / Double(samples.count)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let onLoadData: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 60))
                .foregroundColor(.appAccent.opacity(0.3))

            Text("暂无数据")
                .font(.headline)
                .foregroundColor(.text)

            Text("点击按钮加载健康数据")
                .font(.subheadline)
                .foregroundColor(.secondaryText)

            Button(action: onLoadData) {
                Text("加载数据")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.appAccent)
                    .cornerRadius(10)
            }
        }
        .padding()
    }
}
