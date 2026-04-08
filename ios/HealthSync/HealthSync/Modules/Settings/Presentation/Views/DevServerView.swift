import SwiftUI

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
