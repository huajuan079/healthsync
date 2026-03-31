import SwiftUI
import HealthKit

struct HomeView: View {
    @ObservedObject var viewModel: HomeViewModel

    init(container: AppContainer) {
        self.viewModel = HomeViewModel(container: container)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                HeaderView(isConnected: viewModel.isConnected)
                StatusCard(lastSyncTime: viewModel.lastSyncTime, isSyncing: viewModel.isSyncing)
                TodayHealthCard(summary: viewModel.todaySummary)
                SyncOptionsCard(
                    isSyncing: viewModel.isSyncing,
                    onSyncToday: viewModel.syncToday,
                    onSyncWeek: viewModel.syncLastWeek,
                    onSyncMonth: viewModel.syncLast30Days
                )
                Spacer()
                    .frame(height: 20)
            }
            .padding()
            .padding(.bottom, 100) // Extra space for tab bar
        }
        .background(Color.background)
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .sheet(isPresented: $viewModel.showSyncStatus) {
            SyncStatusView(viewModel: viewModel.syncViewModel)
        }
        .alert("同步失败", isPresented: $viewModel.showError) {
            Button("确定", role: .cancel) {
                viewModel.syncViewModel.showError = false
            }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
        .onAppear { viewModel.loadTodaySummary() }
    }
}

// MARK: - Header View

struct HeaderView: View {
    let isConnected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("健康同步")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.text)
                Text("小炎健康助手")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
            Spacer()
            HStack(spacing: 8) {
                Circle()
                    .fill(isConnected ? Color.success : Color.error)
                    .frame(width: 8, height: 8)
                Text(isConnected ? "已连接" : "未连接")
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }
        }
    }
}

// MARK: - Status Card

struct StatusCard: View {
    let lastSyncTime: Date?
    let isSyncing: Bool

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.appAccent.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title2)
                    .foregroundColor(.appAccent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("同步状态")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)

                if isSyncing {
                    HStack(spacing: 8) {
                        ProgressView().scaleEffect(0.8)
                        Text("正在同步...")
                            .foregroundColor(.text)
                    }
                } else if let t = lastSyncTime {
                    Text("上次同步: \(t, style: .relative)")
                        .foregroundColor(.text)
                } else {
                    Text("尚未同步")
                        .foregroundColor(.text)
                }
            }
            Spacer()
        }
        .padding()
        .cardStyle()
    }
}

// MARK: - Today Health Card

struct TodayHealthCard: View {
    let summary: TodayHealthSummary?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("今日健康")
                .font(.headline)
                .foregroundColor(.text)

            HStack(spacing: 12) {
                HealthMetricCard(
                    icon: "figure.walk",
                    title: "步数",
                    value: summary?.steps != nil ? "\(summary!.steps)" : "--",
                    unit: "步",
                    color: .stepsColor
                )
                HealthMetricCard(
                    icon: "heart.fill",
                    title: "静息心率",
                    value: summary?.restingHeartRate != nil ? "\(Int(summary!.restingHeartRate!))" : "--",
                    unit: "bpm",
                    color: .heartRateColor
                )
                HealthMetricCard(
                    icon: "bed.double.fill",
                    title: "睡眠",
                    value: "--",
                    unit: "",
                    color: .sleepColor
                )
            }
        }
        .padding()
        .cardStyle()
    }
}

// MARK: - Health Metric Card

struct HealthMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
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
                if !unit.isEmpty {
                    Text(unit)
                        .font(.caption2)
                        .foregroundColor(.secondaryText)
                }
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.tertiaryBackground)
        .cornerRadius(10)
    }
}

// MARK: - Sync Options Card

struct SyncOptionsCard: View {
    let isSyncing: Bool
    let onSyncToday: () -> Void
    let onSyncWeek: () -> Void
    let onSyncMonth: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("同步选项")
                .font(.headline)
                .foregroundColor(.text)

            VStack(spacing: 8) {
                SyncOptionButton(
                    title: "立即同步今日数据",
                    icon: "sun.max.fill",
                    color: .appAccent,
                    isDisabled: isSyncing,
                    action: {
                        print("[HomeView] '同步今日' button tapped")
                        onSyncToday()
                    }
                )
                SyncOptionButton(
                    title: "同步最近7天",
                    icon: "calendar.badge.plus",
                    color: .stepsColor,
                    isDisabled: isSyncing,
                    action: {
                        print("[HomeView] '同步7天' button tapped")
                        onSyncWeek()
                    }
                )
                SyncOptionButton(
                    title: "同步最近30天",
                    icon: "calendar",
                    color: .energyColor,
                    isDisabled: isSyncing,
                    action: {
                        print("[HomeView] '同步30天' button tapped")
                        onSyncMonth()
                    }
                )
            }
        }
        .padding()
        .cardStyle()
    }
}

// MARK: - Sync Option Button

struct SyncOptionButton: View {
    let title: String
    let icon: String
    let color: Color
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .frame(width: 24)
                Text(title)
                    .foregroundColor(.text)
                Spacer()
                if isDisabled {
                    ProgressView().scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.tertiaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.tertiaryBackground.opacity(0.5))
            .cornerRadius(10)
        }
        .disabled(isDisabled)
    }
}
