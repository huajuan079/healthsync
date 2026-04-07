import AppIntents

// MARK: - App Shortcuts Provider
// 让快捷指令 App 自动发现此 App 提供的操作

@available(iOS 16.4, *)
struct HealthSyncShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SyncTodayIntent(),
            phrases: [
                "用 \(.applicationName) 同步健康数据",
                "用 \(.applicationName) 上传健康数据",
                "Sync health data with \(.applicationName)",
                "Upload health data with \(.applicationName)"
            ],
            shortTitle: "同步今日健康数据",
            systemImageName: "heart.text.square.fill"
        )
    }
}
