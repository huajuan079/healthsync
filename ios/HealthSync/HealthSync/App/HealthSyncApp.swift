import SwiftUI
import UIKit

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
        // Configure tab bar appearance
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.secondaryBackground)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance

        // Configure navigation bar
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.secondaryBackground)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor(Color.text)]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor(Color.text)]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(Color.appAccent)
    }
}

struct ContentView: View {
    @EnvironmentObject var container: AppContainer
    @State private var isAuthenticated = false
    @State private var isCheckingAuth = false

    var body: some View {
        Group {
            if isCheckingAuth {
                // Show loading during auth check
                ZStack {
                    Color.background.ignoresSafeArea()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.appAccent))
                }
            } else if isAuthenticated {
                MainTabView()
                    .ignoresSafeArea(.keyboard) // Only ignore keyboard, not tab bar
            } else {
                LoginView(container: container)
            }
        }
        .task {
            await checkAuthentication()
        }
        .onReceive(NotificationCenter.default.publisher(for: .didLogin)) { _ in
            isAuthenticated = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .didLogout)) { _ in
            isAuthenticated = false
        }
    }

    private func checkAuthentication() async {
        isCheckingAuth = true
        // Small delay to prevent blocking UI
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        isAuthenticated = container.authRepository.hasValidToken()
        isCheckingAuth = false
    }
}

extension Notification.Name {
    static let didLogout = Notification.Name("didLogout")
    static let didLogin = Notification.Name("didLogin")
}
