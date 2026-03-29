import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeContainerView().tabItem { Label("首页", systemImage: "house") }.tag(0)
            HealthDetailContainerView().tabItem { Label("健康", systemImage: "heart") }.tag(1)
            WorkoutDetailContainerView().tabItem { Label("运动", systemImage: "figure.run") }.tag(2)
            SettingsContainerView().tabItem { Label("设置", systemImage: "gear") }.tag(3)
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

struct HealthDetailContainerView: View {
    @EnvironmentObject var container: AppContainer
    var body: some View {
        HealthDetailView(container: container)
    }
}

struct WorkoutDetailContainerView: View {
    @EnvironmentObject var container: AppContainer
    var body: some View {
        WorkoutDetailView(container: container)
    }
}

struct SettingsContainerView: View {
    @EnvironmentObject var container: AppContainer
    var body: some View {
        NavigationStack { SettingsView(container: container) }
    }
}
