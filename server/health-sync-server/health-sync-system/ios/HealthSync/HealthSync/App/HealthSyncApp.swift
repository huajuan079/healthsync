import SwiftUI

@main
struct HealthSyncApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(container)
                .onAppear {
                    setupAppearance()
                }
        }
    }

    private func setupAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.background)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.background)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.text)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.text)]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(Color.accent)
    }
}

struct ContentView: View {
    @EnvironmentObject var container: AppContainer
    @State private var isAuthenticated = false

    var body: some View {
        Group {
            if isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .onAppear {
            checkAuthentication()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didLogout)) { _ in
            isAuthenticated = false
        }
    }

    private func checkAuthentication() {
        isAuthenticated = container.authRepository.hasValidToken()
    }
}

extension Notification.Name {
    static let didLogout = Notification.Name("didLogout")
}
