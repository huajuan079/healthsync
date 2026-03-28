import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: SettingsViewModel

    init(container: AppContainer) {
        self.viewModel = SettingsViewModel(
            authRepository: container.authRepository,
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
                        Text("已登录").font(.caption).foregroundColor(.success)
                    }
                    Spacer()
                }.padding(.vertical, 8)
            } header: { Text("账户") }

            Section {
                Picker("同步范围", selection: $viewModel.syncRange) {
                    Text("7天").tag(7)
                    Text("30天").tag(30)
                    Text("全部").tag(-1)
                }
                .onChange(of: viewModel.syncRange) { _ in viewModel.saveSettings() }
                HStack {
                    Text("自动同步").foregroundColor(.text)
                    Spacer()
                    Text("每天 23:00").foregroundColor(.secondaryText)
                }
            } header: { Text("同步设置") }

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
            } header: { Text("服务器") } footer: {
                Text("修改服务器地址后需要重新登录").foregroundColor(.tertiaryText)
            }

            Section {
                Button("重新授权健康数据") { }.foregroundColor(.appAccent)
            } header: { Text("健康数据") }

            Section {
                HStack {
                    Text("版本").foregroundColor(.text)
                    Spacer()
                    Text("1.0.0").foregroundColor(.secondaryText)
                }
            } header: { Text("关于") }

            Section {
                Button(role: .destructive) {
                    viewModel.showingLogoutAlert = true
                } label: {
                    HStack { Spacer(); Text("退出登录"); Spacer() }
                }
            }
        }
        .background(Color.background)
        .scrollContentBackground(.hidden)
        .navigationTitle("设置")
        .alert("退出登录", isPresented: $viewModel.showingLogoutAlert) {
            Button("取消", role: .cancel) {}
            Button("退出", role: .destructive) { viewModel.logout() }
        } message: { Text("确定要退出登录吗？") }
    }
}
