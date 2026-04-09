import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    init(container: AppContainer) {
        self.viewModel = SettingsViewModel(
            authRepository: container.authRepository,
            healthRepository: container.healthRepository,
            onLogout: { NotificationCenter.default.post(name: .didLogout, object: nil) }
        )
    }

    var body: some View {
        ZStack {
            AmbientBackground()
            ScrollView {
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("设置")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.text)
                            Text("账户与同步配置")
                                .font(.caption)
                                .foregroundColor(.secondaryText)
                        }
                        Spacer()
                    }
                    accountCard
                    syncCard
                    healthPermissionCard
                    aboutCard
                    logoutButton
                }
                .padding()
                .padding(.bottom, 100)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $viewModel.showDevPanel) {
            DevServerView(viewModel: viewModel)
        }
        .alert("退出登录", isPresented: $viewModel.showingLogoutAlert) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) { viewModel.logout() }
        } message: { Text("确定要退出登录吗？") }
        .alert("健康数据授权", isPresented: $viewModel.showingAuthAlert) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(viewModel.authAlertMessage)
        }
    }

    private var accountCard: some View {
        HealthCard(icon: "person.circle.fill", title: "账户", color: .appAccent) {
            HStack {
                if let username = UserDefaultsManager.shared.username {
                    Text("当前账号: \(username)")
                        .font(.subheadline)
                        .foregroundColor(.success)
                } else {
                    Text("已登录")
                        .font(.subheadline)
                        .foregroundColor(.success)
                }
                Spacer()
            }
        }
    }

    private var syncCard: some View {
        HealthCard(icon: "arrow.triangle.2.circlepath", title: "同步设置", color: .stepsColor) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle(isOn: Binding(
                    get: { viewModel.autoSyncEnabled },
                    set: { viewModel.toggleAutoSync($0) }
                )) {
                    Text("自动同步").foregroundColor(.text)
                }
                .tint(.appAccent)

                if viewModel.autoSyncEnabled {
                    SyncHourPicker(syncHour: viewModel.syncHour) { viewModel.updateSyncHour($0) }

                    Text("系统会在 \(String(format: "%02d:00", viewModel.syncHour)) 之后找合适时机执行后台同步，实际时间由 iOS 决定")
                        .font(.caption)
                        .foregroundColor(.tertiaryText)
                }
            }
        }
    }

    private var healthPermissionCard: some View {
        HealthCard(icon: "heart.text.square", title: "健康数据权限", color: .heartRateColor) {
            VStack(alignment: .leading, spacing: 12) {
                Button("检查授权状态") { viewModel.checkAuthorizationAndAlert() }
                    .foregroundColor(.appAccent)

                Divider().background(Color.tertiaryBackground)

                Link(destination: URL(string: "x-apple-health://")!) {
                    HStack {
                        Text("打开健康设置").foregroundColor(.appAccent)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                            .foregroundColor(.secondaryText)
                            .font(.caption)
                    }
                }

                Divider().background(Color.tertiaryBackground)

                if viewModel.isRequestingAuth {
                    HStack {
                        ProgressView().scaleEffect(0.8)
                        Text("正在请求授权...")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .padding(.leading, 8)
                    }
                } else {
                    Button("重新请求授权（首次或已删除权限时有效）") {
                        Task { await viewModel.requestHealthKitAuthorization() }
                    }
                    .foregroundColor(.secondaryText)
                    .font(.caption)
                }

                Text("💡 如果之前拒绝了授权，系统不会再次弹窗。请点击「打开健康设置」手动开启权限。")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
            }
        }
    }

    private var aboutCard: some View {
        HealthCard(icon: "info.circle", title: "关于", color: .secondaryText) {
            HStack {
                Text("版本").foregroundColor(.text)
                Spacer()
                Text("1.0.0").foregroundColor(.secondaryText)
            }
            .contentShape(Rectangle())
            .onTapGesture { viewModel.handleVersionTap() }
        }
    }

    private var logoutButton: some View {
        Button(role: .destructive) {
            viewModel.showingLogoutAlert = true
        } label: {
            HStack {
                Spacer()
                Text("退出登录")
                    .font(.body)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding()
            .cardStyle()
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SyncHourPicker (extracted to help type-checker)

private struct SyncHourPicker: View {
    let syncHour: Int
    let onChange: (Int) -> Void

    var body: some View {
        Picker("同步时间", selection: Binding(get: { syncHour }, set: onChange)) {
            ForEach(0..<24, id: \.self) { hour in
                Text(hourLabel(hour)).tag(hour)
            }
        }
        .foregroundColor(.text)
        .tint(.appAccent)
    }

    private func hourLabel(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}
