import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject var container: AppContainer
    @StateObject private var viewModel: WorkoutDetailViewModel

    init(container: AppContainer) {
        self._viewModel = StateObject(wrappedValue: WorkoutDetailViewModel(
            healthRepository: container.healthRepository,
            syncUseCase: container.syncHealthDataUseCase
        ))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.workouts.isEmpty {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.appAccent))
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Date Selector
                            DateSelectorView(
                                currentDate: viewModel.formattedDate,
                                isToday: viewModel.isToday,
                                canSelectNextDay: viewModel.canSelectNextDay,
                                onPreviousDay: { viewModel.changeDay(by: -1) },
                                onNextDay: { viewModel.changeDay(by: 1) }
                            )

                            // Stats Card
                            WorkoutStatsCard(
                                totalWorkouts: viewModel.totalWorkouts,
                                totalDuration: viewModel.totalDuration,
                                totalCalories: viewModel.totalCalories
                            )

                            // Sync Button
                            if !viewModel.workouts.isEmpty {
                                SyncButton(
                                    isSyncing: viewModel.isSyncing,
                                    message: viewModel.syncMessage,
                                    onSync: { viewModel.syncWorkouts() }
                                )
                            }

                            // Workout List
                            if viewModel.workouts.isEmpty {
                                EmptyWorkoutView()
                            } else {
                                VStack(spacing: 12) {
                                    ForEach(viewModel.workouts, id: \.startDate) { workout in
                                        WorkoutDetailCard(workout: workout)
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if viewModel.workouts.isEmpty {
                viewModel.loadWorkouts()
            }
        }
    }
}

// MARK: - Date Selector (Shared)

// MARK: - Workout Stats Card

struct WorkoutStatsCard: View {
    let totalWorkouts: Int
    let totalDuration: TimeInterval
    let totalCalories: Double

    var body: some View {
        HStack(spacing: 20) {
            StatItem(
                icon: "figure.run",
                value: "\(totalWorkouts)",
                label: "运动",
                color: .energyColor
            )

            Divider()
                .frame(height: 40)
                .background(Color.tertiaryBackground)

            StatItem(
                icon: "clock",
                value: formatDuration(totalDuration),
                label: "时长",
                color: .appAccent
            )

            Divider()
                .frame(height: 40)
                .background(Color.tertiaryBackground)

            StatItem(
                icon: "flame.fill",
                value: "\(Int(totalCalories))",
                label: "卡路里",
                color: .heartRateColor
            )
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60

        if hours > 0 {
            return "\(hours)h\(minutes)m"
        }
        return "\(minutes)m"
    }
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            VStack(spacing: 2) {
                Text(value)
                    .font(.headline)
                    .foregroundColor(.text)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondaryText)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Sync Button

struct SyncButton: View {
    let isSyncing: Bool
    let message: String?
    let onSync: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onSync) {
                HStack(spacing: 12) {
                    if isSyncing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "icloud.and.arrow.up")
                            .font(.headline)
                    }

                    Text(isSyncing ? "正在同步..." : "同步到服务器")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(isSyncing ? Color.tertiaryText : Color.appAccent)
                .cornerRadius(12)
            }
            .disabled(isSyncing)

            if let message = message {
                Text(message)
                    .font(.caption)
                    .foregroundColor(message.contains("成功") ? Color.success : Color.warning)
                    .padding(.horizontal)
            }
        }
    }
}

// MARK: - Workout Detail Card

struct WorkoutDetailCard: View {
    let workout: WorkoutData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: workoutIcon)
                    .foregroundColor(.energyColor)
                    .font(.title2)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 4) {
                    Text(workoutTitle)
                        .font(.headline)
                        .foregroundColor(.text)
                    Text(formatTime(workout.startDate))
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                }

                Spacer()

                if let energy = workout.energy {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.caption)
                            .foregroundColor(.heartRateColor)
                        Text("\(Int(energy)) kcal")
                            .font(.subheadline)
                            .foregroundColor(.text)
                    }
                }
            }

            // Details
            HStack(spacing: 20) {
                WorkoutDetailItem(
                    icon: "clock",
                    label: "时长",
                    value: formatDuration(workout.duration)
                )

                if let distance = workout.distance {
                    WorkoutDetailItem(
                        icon: "location",
                        label: "距离",
                        value: formatDistance(distance)
                    )
                }

                Spacer()
            }
        }
        .padding()
        .background(Color.secondaryBackground)
        .cornerRadius(12)
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

    func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }

    func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    func formatDistance(_ distance: Double) -> String {
        if distance >= 1000 {
            return String(format: "%.2f km", distance / 1000)
        }
        return String(format: "%.0f m", distance)
    }
}

struct WorkoutDetailItem: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondaryText)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondaryText)
            Text(value)
                .font(.caption)
                .foregroundColor(.text)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Empty State

struct EmptyWorkoutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 60))
                .foregroundColor(.appAccent.opacity(0.3))

            Text("暂无运动记录")
                .font(.headline)
                .foregroundColor(.text)

            Text("这一天没有运动数据")
                .font(.subheadline)
                .foregroundColor(.secondaryText)
        }
        .padding()
        .frame(maxWidth: .infinity)
    }
}
