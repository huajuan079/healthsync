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
        List {
            accountSection
            syncSection
            healthPermissionSection
            aboutSection
            logoutSection
        }
        .background(Color.background)
        .scrollContentBackground(.hidden)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
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

    private var accountSection: some View {
        Section {
            HStack {
                Image(systemName: "person.circle.fill").foregroundColor(.appAccent).font(.title2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("用户").font(.headline).foregroundColor(.text)
                    if let username = UserDefaultsManager.shared.username {
                        Text("当前账号: \(username)").font(.caption).foregroundColor(.success)
                    } else {
                        Text("已登录").font(.caption).foregroundColor(.success)
                    }
                }
                Spacer()
            }.padding(.vertical, 8)
        } header: {
            Text("账户").font(.subheadline).foregroundColor(.secondaryText).textCase(.none)
        }
        .listRowBackground(Color.secondaryBackground)
    }

    private var syncSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { viewModel.autoSyncEnabled },
                set: { viewModel.toggleAutoSync($0) }
            )) {
                Text("自动同步").foregroundColor(.text)
            }
            .tint(.appAccent)

            if viewModel.autoSyncEnabled {
                SyncHourPicker(syncHour: viewModel.syncHour) { viewModel.updateSyncHour($0) }
            }
        } header: {
            Text("同步设置").font(.subheadline).foregroundColor(.secondaryText).textCase(.none)
        } footer: {
            if viewModel.autoSyncEnabled {
                Text("系统会在 \(String(format: "%02d:00", viewModel.syncHour)) 之后找合适时机执行后台同步，实际时间由 iOS 决定")
                    .foregroundColor(.tertiaryText)
            }
        }
        .listRowBackground(Color.secondaryBackground)
    }

    private var healthPermissionSection: some View {
        Section {
            Button("检查授权状态") { viewModel.checkAuthorizationAndAlert() }
                .foregroundColor(.appAccent)

            Link(destination: URL(string: "x-apple-health://")!) {
                HStack {
                    Text("打开健康设置").foregroundColor(.appAccent)
                    Spacer()
                    Image(systemName: "arrow.up.right.square").foregroundColor(.secondaryText).font(.caption)
                }
            }

            if viewModel.isRequestingAuth {
                HStack {
                    Spacer()
                    ProgressView().scaleEffect(0.8)
                    Text("正在请求授权...").font(.caption).foregroundColor(.secondaryText).padding(.leading, 8)
                    Spacer()
                }
            } else {
                Button("重新请求授权（首次或已删除权限时有效）") {
                    Task { await viewModel.requestHealthKitAuthorization() }
                }
                .foregroundColor(.secondaryText)
                .font(.caption)
            }
        } header: {
            Text("健康数据权限").font(.subheadline).foregroundColor(.secondaryText).textCase(.none)
        } footer: {
            Text("💡 如果之前拒绝了授权，系统不会再次弹窗。请点击「打开健康设置」手动开启权限。")
                .foregroundColor(.tertiaryText)
        }
        .listRowBackground(Color.secondaryBackground)
    }

    private var aboutSection: some View {
        Section {
            HStack {
                Text("版本").foregroundColor(.text)
                Spacer()
                Text("1.0.0").foregroundColor(.secondaryText)
            }
            .contentShape(Rectangle())
            .onTapGesture { viewModel.handleVersionTap() }
        } header: {
            Text("关于").font(.subheadline).foregroundColor(.secondaryText).textCase(.none)
        }
        .listRowBackground(Color.secondaryBackground)
    }

    private var logoutSection: some View {
        Section {
            Button(role: .destructive) {
                viewModel.showingLogoutAlert = true
            } label: {
                HStack { Spacer(); Text("退出登录"); Spacer() }
            }
        } header: { EmptyView() }
        .listRowBackground(Color.secondaryBackground)
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

// MARK: - DevServerView

struct DevServerView: View {
    @ObservedObject var viewModel: SettingsViewModel
    @Environment(\.dismiss) private var dismiss

    private let productionURL = "https://markmager.cc/healthsync"

    var body: some View {
        NavigationStack {
            List {
                currentEnvSection
                quickSwitchSection
                customURLSection
                applySection
            }
            .background(Color.background)
            .scrollContentBackground(.hidden)
            .navigationTitle("开发者设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }.foregroundColor(.appAccent)
                }
            }
        }
    }

    private var currentEnvSection: some View {
        Section {
            HStack(spacing: 10) {
                Circle()
                    .fill(viewModel.currentEnvironmentIsLocal ? Color.success : Color.appAccent)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.currentEnvironmentIsLocal ? "本地环境" : "生产环境")
                        .font(.headline).foregroundColor(.text)
                    Text(Config.serverURL)
                        .font(.caption).foregroundColor(.secondaryText).lineLimit(1)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("当前连接").font(.subheadline).foregroundColor(.secondaryText).textCase(.none)
        }
        .listRowBackground(Color.secondaryBackground)
    }

    private var quickSwitchSection: some View {
        Section {
            Button {
                viewModel.devURLInput = Config.defaultServerURL
            } label: {
                HStack {
                    Image(systemName: "house.fill").foregroundColor(.success).frame(width: 20)
                    Text("本地默认").foregroundColor(.text)
                    Spacer()
                    Text(Config.defaultServerURL).font(.caption).foregroundColor(.tertiaryText).lineLimit(1)
                }
            }
            Button {
                viewModel.devURLInput = productionURL
            } label: {
                HStack {
                    Image(systemName: "cloud.fill").foregroundColor(.appAccent).frame(width: 20)
                    Text("生产环境").foregroundColor(.text)
                    Spacer()
                    Text(productionURL).font(.caption).foregroundColor(.tertiaryText).lineLimit(1)
                }
            }
        } header: {
            Text("快速切换").font(.subheadline).foregroundColor(.secondaryText).textCase(.none)
        }
        .listRowBackground(Color.secondaryBackground)
    }

    private var customURLSection: some View {
        Section {
            TextField("http://192.168.x.x:3000", text: $viewModel.devURLInput)
                .foregroundColor(.text)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .keyboardType(.URL)
        } header: {
            Text("自定义服务器地址").font(.subheadline).foregroundColor(.secondaryText).textCase(.none)
        } footer: {
            Text("修改后需要重新登录才能生效").foregroundColor(.tertiaryText)
        }
        .listRowBackground(Color.secondaryBackground)
    }

    private var applySection: some View {
        let urlChanged = viewModel.devURLInput != Config.serverURL
        return Section {
            Button {
                viewModel.applyDevURL()
            } label: {
                HStack {
                    Spacer()
                    Text(urlChanged ? "应用并重新登录" : "关闭").fontWeight(.medium)
                    Spacer()
                }
            }
            .foregroundColor(urlChanged ? .appAccent : .secondaryText)
        }
        .listRowBackground(Color.secondaryBackground)
    }
}
