import SwiftUI
import UIKit

struct MainTabView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeContainerView().tabItem { Label("首页", systemImage: "house") }.tag(0)
            HealthDetailView().tabItem { Label("健康", systemImage: "heart") }.tag(1)
            SettingsContainerView().tabItem { Label("设置", systemImage: "gear") }.tag(2)
        }
        .tint(.appAccent)
    }
}

struct HomeContainerView: View {
    @EnvironmentObject var container: AppContainer
    var body: some View {
        HomeView(container: container)
    }
}

struct HealthDetailView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("健康数据详情")
                        .font(.headline)
                        .foregroundColor(.text)
                        .padding()
                    Text("请在首页进行数据同步")
                        .foregroundColor(.secondaryText)
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.appAccent.opacity(0.3))
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(Color.background)
            .navigationTitle("健康数据")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct SettingsContainerView: View {
    @EnvironmentObject var container: AppContainer
    var body: some View {
        NavigationStack { SettingsView(container: container) }
    }
}
