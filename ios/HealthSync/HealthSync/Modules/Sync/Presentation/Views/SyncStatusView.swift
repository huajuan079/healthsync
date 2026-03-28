import SwiftUI

struct SyncStatusView: View {
    @StateObject private var viewModel: SyncViewModel
    @Environment(\.dismiss) private var dismiss

    init(viewModel: SyncViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Sync status card
                    SyncStatusCard(
                        isSyncing: viewModel.isSyncing,
                        lastSyncTime: viewModel.lastSyncTime,
                        syncProgress: viewModel.syncProgress
                    )

                    // Data counts
                    if let status = viewModel.syncStatus {
                        DataCountsCard(status: status)
                    }

                    // Sync logs
                    SyncLogsSection(logs: viewModel.syncLogs)
                }
                .padding()
            }
            .background(Color.background)
            .navigationTitle("同步状态")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SyncStatusCard: View {
    let isSyncing: Bool
    let lastSyncTime: Date?
    let syncProgress: SyncProgress?

    var body: some View {
        VStack(spacing: 16) {
            // Status icon and text
            HStack(spacing: 12) {
                if isSyncing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                    Text("正在同步...")
                        .foregroundColor(.text)
                } else if let lastSyncTime = lastSyncTime {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.success)
                    Text("上次同步: \(lastSyncTime, style: .relative)")
                        .foregroundColor(.secondaryText)
                } else {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.warning)
                    Text("尚未同步")
                        .foregroundColor(.secondaryText)
                }

                Spacer()
            }

            // Progress bar
            if let progress = syncProgress {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("\(progress.currentDay)/\(progress.totalDays)")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                        Spacer()
                        Text("\(Int(progress.overallProgress * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                    }

                    ProgressView(value: progress.overallProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .appAccent))

                    Text(progress.currentDataType)
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                }
            }
        }
        .padding()
        .cardStyle()
    }
}

struct DataCountsCard: View {
    let status: SyncStatusResponse

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("已同步数据")
                .font(.headline)
                .foregroundColor(.text)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                DataCountItem(label: "总记录", value: "\(status.totalRecords)", color: .appAccent)
                DataCountItem(label: "上传次数", value: "\(status.totalUploads)", color: .stepsColor)
                DataCountItem(label: "心率", value: "✓", color: .heartRateColor)
                DataCountItem(label: "步数", value: "✓", color: .stepsColor)
                DataCountItem(label: "睡眠", value: "✓", color: .sleepColor)
                DataCountItem(label: "HRV", value: "✓", color: .energyColor)
            }
        }
        .padding()
        .cardStyle()
    }
}

struct DataCountItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundColor(color)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.tertiaryBackground)
        .cornerRadius(8)
    }
}

struct SyncLogsSection: View {
    let logs: [SyncLog]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("同步日志")
                .font(.headline)
                .foregroundColor(.text)

            if logs.isEmpty {
                Text("暂无同步记录")
                    .font(.subheadline)
                    .foregroundColor(.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(logs) { log in
                        SyncLogRow(log: log)
                    }
                }
            }
        }
        .padding()
        .cardStyle()
    }
}

struct SyncLogRow: View {
    let log: SyncLog

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: log.status == .success ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(log.status == .success ? .success : .error)
                .font(.title3)

            VStack(alignment: .leading, spacing: 4) {
                Text(log.date)
                    .font(.subheadline)
                    .foregroundColor(.text)
                Text(log.message)
                    .font(.caption)
                    .foregroundColor(.secondaryText)
            }

            Spacer()

            Text(log.time, style: .time)
                .font(.caption)
                .foregroundColor(.tertiaryText)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.tertiaryBackground.opacity(0.5))
        .cornerRadius(8)
    }
}

#Preview {
    SyncStatusView(viewModel: SyncViewModel(container: AppContainer()))
}
