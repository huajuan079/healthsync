# Unified Card Component Design

**Date:** 2026-04-09  
**Status:** Approved  
**Scope:** iOS App (`ios/HealthSync/`)

## Problem

卡片风格在 4 个 Tab 之间不一致：

1. `HealthDetailView` 和 `WorkoutDetailView` 的所有卡片都内联重复同一段 glass 样式代码（`.background(.ultraThinMaterial).cornerRadius(16).overlay(...).shadow(...)`），而 `HomeView` 已经有 `cardStyle()` modifier 可复用。
2. `StepsMetricCard`、`RestingHeartRateCard`、`WeightMetricCard` 三个 struct 结构完全相同，仅名称不同。
3. `SettingsView` 使用 SwiftUI `List` + `.listRowBackground`，与其他三个 Tab 的 Glass Card 风格完全不同。

## Solution

新建两个核心组件，4 个 Tab 统一使用。

---

## Components

### 1. `HealthCard<Content: View>`

通用卡片容器，统一 header 结构（icon + title + 可选尾部文字）。

```swift
struct HealthCard<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    var trailing: String? = nil
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                Text(title)
                    .font(.headline)
                    .foregroundColor(.text)
                Spacer()
                if let trailing {
                    Text(trailing)
                        .font(.subheadline)
                        .foregroundColor(.secondaryText)
                }
            }
            content()
        }
        .padding()
        .cardStyle()
    }
}
```

**适用卡片：** HeartRateDetailCard、HRVDetailCard、SleepDetailCard、BloodOxygenCard、WorkoutListCard、MenstrualDataCard、WristTemperatureCard、RespiratoryRateCard、BodyTemperatureCard、BloodPressureCard、TodayHealthCard、TodayWorkoutCard、SyncOptionsCard，以及 Settings 各分组。

### 2. `MetricCard`

单指标卡，左侧图标，右侧标题+数值+单位。

```swift
struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color
}
```

**替换：** `StepsMetricCard`、`RestingHeartRateCard`、`WeightMetricCard`（三个完全相同的 struct 删除，统一用 `MetricCard`）。

---

## File Structure

新建文件：

```
ios/HealthSync/HealthSync/Shared/UI/Components/HealthCardComponents.swift
```

包含 `HealthCard` 和 `MetricCard` 两个组件。

---

## Refactoring Scope

| 文件 | 改动内容 |
|---|---|
| `HealthCardComponents.swift` | **新建**：`HealthCard<Content>`、`MetricCard` |
| `HealthDetailView.swift` | 13 个卡片用 `HealthCard` 重写；删除 `StepsMetricCard`、`RestingHeartRateCard`、`WeightMetricCard`，改用 `MetricCard` |
| `WorkoutDetailView.swift` | `WorkoutStatsCard`、`WorkoutDetailCard` 内联样式替换为 `.cardStyle()` |
| `HomeView.swift` | `TodayHealthCard`、`TodayWorkoutCard` 用 `HealthCard` 替换 header；其余基本不动 |
| `SettingsView.swift` | `List` → `ScrollView + VStack`；各 Section → `HealthCard`；footer 文字移入卡片内部 |
| `Colors.swift` | **不改动**（`cardStyle()` 已正确定义） |

---

## What Does NOT Change

- `HealthMetricCard`：首页内嵌的紧凑型横排小指标卡（用在 TodayHealthCard/TodayWorkoutCard 内部），布局逻辑不同，保留。
- `DateSelectorView`：日期选择器，非内容卡，保留。
- `SyncOptionsCard` 内部的 `SyncOptionButton`：列表行样式，保留。
- `StatusCard`：同步状态卡，button 交互特殊，保留，但内联样式替换为 `.cardStyle()`。
- `WorkoutDetailCard` 内部的 `WorkoutDetailItem`、`StatItem`：子组件，保留。

---

## Settings Conversion Detail

```swift
// 改造后结构
var body: some View {
    ZStack {
        AmbientBackground()
        ScrollView {
            VStack(spacing: 16) {
                accountCard
                syncCard
                healthPermissionCard
                aboutCard
                logoutButton
            }
            .padding()
            .padding(.bottom, 100)
        }
    }
    .navigationTitle("设置")
    .navigationBarTitleDisplayMode(.inline)
}

private var accountCard: some View {
    HealthCard(icon: "person.circle.fill", title: "账户", color: .appAccent) {
        // 用户信息行
    }
}

private var syncCard: some View {
    HealthCard(icon: "arrow.triangle.2.circlepath", title: "同步设置", color: .stepsColor) {
        // Toggle + Picker
        // footer 文字作为 Text(.caption) 放在底部
    }
}
```

Section footer 文字改为 `HealthCard` 内部最后一个子 view：

```swift
Text("系统会在 \(...)之后找合适时机执行后台同步...")
    .font(.caption)
    .foregroundColor(.tertiaryText)
```

---

## Success Criteria

- 所有 4 个 Tab 的卡片在视觉上完全一致（background material、cornerRadius、border、shadow）
- `HealthDetailView` 中不再有内联的 `.background(.ultraThinMaterial)` 等样式代码
- `StepsMetricCard`、`RestingHeartRateCard`、`WeightMetricCard` 三个重复 struct 被删除
- `SettingsView` 不再使用 `List`，改为 ScrollView + HealthCard 结构
- `Colors.swift` 中的 `cardStyle()` 是唯一的卡片样式定义点
