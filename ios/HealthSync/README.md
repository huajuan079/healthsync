# HealthSync iOS App

iPhone健康数据同步应用 - 将HealthKit数据加密上传到服务器

## 功能

- 📱 读取HealthKit数据（睡眠、心率、步数、运动等）
- 🔒 AES-256本地加密
- 🔄 手动/自动同步
- 🌙 深色主题
- 📊 同步状态追踪

## 开发环境

- Xcode 16+
- iOS 16+
- Swift 5.9+

## 配置

1. 修改服务器地址：

```swift
// Core/DI/AppContainer.swift
enum Config {
    static var serverURL: String = "https://your-server.com"
}
```

2. 配置加密密钥（与服务器一致）

3. 配置Info.plist权限：

```xml
<key>NSHealthShareUsageDescription</key>
<string>此应用需要访问您的健康数据</string>
<key>NSHealthUpdateUsageDescription</key>
<string>此应用需要写入健康数据</string>
```

## 构建

1. 在真机上运行（HealthKit需要真机）
2. 允许健康数据访问权限
3. 登录账户

## 后台同步

应用支持后台定时同步：

```swift
// 在 AppDelegate 或 App 入口中注册
BackgroundSyncTaskManager.shared.registerBackgroundTask()
BackgroundSyncTaskManager.shared.scheduleBackgroundSync()
```

## 项目结构

```
HealthSync/
├── App/                      # 应用入口
├── Core/                     # 核心基础设施
│   ├── DI/                   # 依赖注入
│   └── Keychain/             # 钥匙串管理
├── Modules/
│   ├── Auth/                 # 认证模块
│   ├── Health/               # HealthKit模块
│   ├── Encryption/           # 加密模块
│   ├── Sync/                 # 同步模块
│   └── Settings/             # 设置模块
├── Shared/                   # 共享组件
│   └── UI/Themes/            # UI主题
└── Main/                     # 主界面
```

## 数据类型

| 类型 | HealthKit标识 |
|------|--------------|
| 睡眠 | `HKCategoryType(.sleepAnalysis)` |
| 心率 | `HKQuantityType(.heartRate)` |
| 静息心率 | `HKQuantityType(.restingHeartRate)` |
| HRV | `HKQuantityType(.heartRateVariabilitySDNN)` |
| 步数 | `HKQuantityType(.stepCount)` |
| 运动 | `HKObjectType.workoutType()` |
| 血氧 | `HKQuantityType(.oxygenSaturation)` |
| 体重 | `HKQuantityType(.bodyMass)` |
