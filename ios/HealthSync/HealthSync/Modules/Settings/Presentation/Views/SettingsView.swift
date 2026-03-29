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
                Text("账户")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .textCase(.none)
            }
            .listRowBackground(Color.secondaryBackground)

            Section {
                HStack {
                    Text("同步范围").foregroundColor(.text)
                    Spacer()
                    Picker("", selection: $viewModel.syncRange) {
                        Text("7天").tag(7)
                        Text("30天").tag(30)
                        Text("全部").tag(-1)
                    }
                    .foregroundColor(.text)
                    .onChange(of: viewModel.syncRange) { _ in viewModel.saveSettings() }
                }
                HStack {
                    Text("自动同步").foregroundColor(.text)
                    Spacer()
                    Text("每天 23:00").foregroundColor(.secondaryText)
                }
            } header: {
                Text("同步设置")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .textCase(.none)
            }
            .listRowBackground(Color.secondaryBackground)

            Section {
                HStack {
                    Text("服务器地址").foregroundColor(.text)
                    Spacer()
                    TextField("", text: $viewModel.serverURL)
                        .multilineTextAlignment(.trailing).foregroundColor(.secondaryText)
                        .textInputAutocapitalization(.never)
                }
                .onChange(of: viewModel.serverURL) { _ in viewModel.saveSettings() }
                Button("测试连接") { }.foregroundColor(.appAccent)
            } header: {
                Text("服务器")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .textCase(.none)
            } footer: {
                Text("修改服务器地址后需要重新登录").foregroundColor(.tertiaryText)
            }
            .listRowBackground(Color.secondaryBackground)

            Section {
                Button("检查授权状态") {
                    viewModel.checkAuthorizationAndAlert()
                }
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
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("正在请求授权...")
                            .font(.caption)
                            .foregroundColor(.secondaryText)
                            .padding(.leading, 8)
                        Spacer()
                    }
                } else {
                    Button("重新请求授权（首次或已删除权限时有效）") {
                        Task {
                            await viewModel.requestHealthKitAuthorization()
                        }
                    }
                    .foregroundColor(.secondaryText)
                    .font(.caption)
                }
            } header: {
                Text("健康数据权限")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .textCase(.none)
            } footer: {
                Text("💡 如果之前拒绝了授权，系统不会再次弹窗。请点击「打开健康设置」手动开启权限。").foregroundColor(.tertiaryText)
            }
            .listRowBackground(Color.secondaryBackground)

            Section {
                HStack {
                    Text("版本").foregroundColor(.text)
                    Spacer()
                    Text("1.0.0").foregroundColor(.secondaryText)
                }
            } header: {
                Text("关于")
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)
                    .textCase(.none)
            }
            .listRowBackground(Color.secondaryBackground)

            Section {
                Button(role: .destructive) {
                    viewModel.showingLogoutAlert = true
                } label: {
                    HStack { Spacer(); Text("退出登录"); Spacer() }
                }
            } header: { EmptyView() }
            .listRowBackground(Color.secondaryBackground)
        }
        .background(Color.background)
        .scrollContentBackground(.hidden)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
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
}
