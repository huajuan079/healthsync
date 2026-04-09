# Unified Card Component Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新建 `HealthCard` 和 `MetricCard` 两个共享组件，将全部 4 个 Tab 的卡片统一为同一套视觉风格与结构。

**Architecture:** 在 `Shared/UI/Components/` 下新建 `HealthCardComponents.swift`，定义 `HealthCard<Content: View>`（带 icon+title header 的泛型容器）和 `MetricCard`（单指标卡）。`HealthDetailView`、`HomeView`、`WorkoutDetailView` 改用这两个组件；`SettingsView` 从 SwiftUI `List` 改为 `ScrollView + VStack + HealthCard`。所有卡片的 glass 样式统一来自已有的 `cardStyle()` modifier（定义在 `Colors.swift`）。

**Tech Stack:** Swift 5.9+, SwiftUI, Xcode 15+

---

## File Map

| 操作 | 文件 |
|---|---|
| **新建** | `ios/HealthSync/HealthSync/Shared/UI/Components/HealthCardComponents.swift` |
| **修改** | `ios/HealthSync/HealthSync/Main/HealthDetailView.swift` |
| **修改** | `ios/HealthSync/HealthSync/Main/WorkoutDetailView.swift` |
| **修改** | `ios/HealthSync/HealthSync/Main/HomeView.swift` |
| **修改** | `ios/HealthSync/HealthSync/Modules/Settings/Presentation/Views/SettingsView.swift` |

---

## Task 1: 新建 HealthCardComponents.swift

**Files:**
- Create: `ios/HealthSync/HealthSync/Shared/UI/Components/HealthCardComponents.swift`

- [ ] **Step 1: 新建文件**

创建 `ios/HealthSync/HealthSync/Shared/UI/Components/HealthCardComponents.swift`，内容如下：

```swift
import SwiftUI

// MARK: - HealthCard (Generic Container)
//
// 通用卡片容器。统一 header 结构：左侧 icon + title，右侧可选摘要文字。
// content 通过 @ViewBuilder 自由组合。

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

// MARK: - MetricCard (Single Metric)
//
// 单指标卡：左侧 icon，右侧上方 title、下方 value + unit。
// 替代原 StepsMetricCard / RestingHeartRateCard / WeightMetricCard（三者完全相同）。

struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondaryText)

                HStack(spacing: 4) {
                    Text(value)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.text)
                    if !unit.isEmpty {
                        Text(unit)
                            .font(.subheadline)
                            .foregroundColor(.secondaryText)
                    }
                }
            }

            Spacer()
        }
        .padding()
        .cardStyle()
    }
}
```

- [ ] **Step 2: 在 Xcode 中将文件加入 Target**

在 Xcode 里右键 `Shared/UI/Components/` 组 → Add Files → 选择刚建的文件，确保勾选 HealthSync target。

- [ ] **Step 3: 编译验证**

在 Xcode 中按 ⌘B。预期结果：Build Succeeded，无报错。

- [ ] **Step 4: 提交**

```bash
git add ios/HealthSync/HealthSync/Shared/UI/Components/HealthCardComponents.swift
git commit -m "feat(ios): add HealthCard and MetricCard shared components"
```

---

## Task 2: HealthDetailView — 替换 3 个重复的 MetricCard struct

**Files:**
- Modify: `ios/HealthSync/HealthSync/Main/HealthDetailView.swift`

这 3 个 struct（`StepsMetricCard`、`RestingHeartRateCard`、`WeightMetricCard`）结构完全相同，统一替换为 Task 1 新建的 `MetricCard`。

- [ ] **Step 1: 更新 HealthDataCardsView 中的调用**

找到 `HealthDataCardsView` 的 body，将 3 处调用替换：

```swift
// 步数卡片 — 将 StepsMetricCard 改为 MetricCard
if let steps = data.steps {
    MetricCard(
        icon: "figure.walk",
        title: "步数",
        value: "\(steps.value)",
        unit: "步",
        color: .stepsColor
    )
}

// 静息心率 — 将 RestingHeartRateCard 改为 MetricCard
if let restingHR = data.restingHeartRate {
    MetricCard(
        icon: "heart.fill",
        title: "静息心率",
        value: "\(Int(restingHR.value))",
        unit: "bpm",
        color: .heartRateColor
    )
}

// 体重 — 将 WeightMetricCard 改为 MetricCard
if let weight = data.weight {
    MetricCard(
        icon: "scalemass",
        title: "体重",
        value: String(format: "%.1f", weight.value),
        unit: weight.unit,
        color: .appAccent
    )
}

// 主动能量消耗 — 将 StepsMetricCard 改为 MetricCard
if let activeEnergy = data.activeEnergyBurned {
    MetricCard(
        icon: "flame.fill",
        title: "主动能量",
        value: String(format: "%.0f", activeEnergy.value),
        unit: activeEnergy.unit,
        color: .energyColor
    )
}

// 爬楼层数 — 将 StepsMetricCard 改为 MetricCard
if let flights = data.flightsClimbed {
    MetricCard(
        icon: "stairs",
        title: "爬楼层数",
        value: String(format: "%.0f", flights.value),
        unit: flights.unit,
        color: .appAccent
    )
}
```

- [ ] **Step 2: 删除 3 个已废弃的 struct**

在 `HealthDetailView.swift` 中，删除以下 3 个完整的 struct 定义（每个约 25 行）：
- `struct StepsMetricCard: View { ... }`
- `struct RestingHeartRateCard: View { ... }`
- `struct WeightMetricCard: View { ... }`

- [ ] **Step 3: 编译验证**

按 ⌘B。预期：Build Succeeded。若有 `cannot find type 'StepsMetricCard'` 等错误，说明还有遗漏的调用点，逐一修正。

- [ ] **Step 4: 提交**

```bash
git add ios/HealthSync/HealthSync/Main/HealthDetailView.swift
git commit -m "refactor(ios): replace duplicate metric card structs with shared MetricCard"
```

---

## Task 3: HealthDetailView — 将 10 个 Section 卡片迁移到 HealthCard

**Files:**
- Modify: `ios/HealthSync/HealthSync/Main/HealthDetailView.swift`

将 10 个 Section 卡片（每个都内联 4 行 glass 样式）改为使用 `HealthCard`。

- [ ] **Step 1: 替换 HeartRateDetailCard**

用以下代码完整替换 `struct HeartRateDetailCard`：

```swift
struct HeartRateDetailCard: View {
    let samples: [HeartRateData.HeartSample]

    private var averageHeartRate: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0.0) { $0 + $1.value } / Double(samples.count)
    }

    var body: some View {
        HealthCard(
            icon: "heart.fill",
            title: "心率",
            color: .heartRateColor,
            trailing: averageHeartRate.map { "平均 \(Int($0)) bpm" }
        ) {
            if samples.count > 1,
               let min = samples.map({ $0.value }).min(),
               let max = samples.map({ $0.value }).max() {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(Int(min))").font(.headline).foregroundColor(.text)
                        Text("最低").font(.caption).foregroundColor(.secondaryText)
                    }
                    VStack(spacing: 4) {
                        Text("\(Int(max))").font(.headline).foregroundColor(.text)
                        Text("最高").font(.caption).foregroundColor(.secondaryText)
                    }
                    Spacer()
                }
            }
        }
    }
}
```

- [ ] **Step 2: 替换 HRVDetailCard**

```swift
struct HRVDetailCard: View {
    let samples: [HRVData.HRVSample]

    private var averageHRV: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0.0) { $0 + $1.value } / Double(samples.count)
    }

    var body: some View {
        HealthCard(
            icon: "waveform.path",
            title: "心率变异性",
            color: .sleepColor,
            trailing: averageHRV.map { "平均 \(Int($0)) ms" }
        ) {
            if samples.count > 1,
               let min = samples.map({ $0.value }).min(),
               let max = samples.map({ $0.value }).max() {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(Int(min))").font(.headline).foregroundColor(.text)
                        Text("最低").font(.caption).foregroundColor(.secondaryText)
                    }
                    VStack(spacing: 4) {
                        Text("\(Int(max))").font(.headline).foregroundColor(.text)
                        Text("最高").font(.caption).foregroundColor(.secondaryText)
                    }
                    Spacer()
                }
            }
        }
    }
}
```

- [ ] **Step 3: 替换 SleepDetailCard**

```swift
struct SleepDetailCard: View {
    let sleepData: [SleepData]

    private var totalSleepDuration: String? {
        let total = sleepData.reduce(0.0) { sum, item in
            if item.type == .asleep || item.type == .asleepCore || item.type == .asleepDeep || item.type == .asleepREM {
                return sum + item.duration
            }
            return sum
        }
        guard total > 0 else { return nil }
        return String(format: "%.1f", total / 3600)
    }

    private func durationForType(_ type: SleepData.SleepType) -> TimeInterval? {
        let total = sleepData.filter { $0.type == type }.reduce(0.0) { $0 + $1.duration }
        return total > 0 ? total : nil
    }

    var body: some View {
        HealthCard(
            icon: "bed.double.fill",
            title: "睡眠",
            color: .sleepColor,
            trailing: totalSleepDuration.map { "\($0)小时" }
        ) {
            VStack(alignment: .leading, spacing: 8) {
                if let inBed = durationForType(.inBed) { SleepRow(type: "在床", duration: inBed) }
                if let asleep = durationForType(.asleep) { SleepRow(type: "入睡", duration: asleep) }
                if let deep = durationForType(.asleepDeep) { SleepRow(type: "深睡", duration: deep, color: .sleepColor) }
                if let rem = durationForType(.asleepREM) { SleepRow(type: "REM", duration: rem, color: .appAccent) }
            }
        }
    }
}
```

- [ ] **Step 4: 替换 WorkoutListCard**

```swift
struct WorkoutListCard: View {
    let workouts: [WorkoutData]

    var body: some View {
        HealthCard(icon: "figure.run", title: "运动", color: .energyColor, trailing: "\(workouts.count)次") {
            VStack(spacing: 8) {
                ForEach(Array(workouts.enumerated()), id: \.element.startDate) { index, workout in
                    WorkoutRow(workout: workout)
                    if index < workouts.count - 1 {
                        Divider().background(Color.tertiaryBackground)
                    }
                }
            }
        }
    }
}
```

- [ ] **Step 5: 替换 BloodOxygenCard**

```swift
struct BloodOxygenCard: View {
    let samples: [BloodOxygenData.OxygenSample]

    private var averageOxygen: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0.0) { $0 + $1.value } / Double(samples.count)
    }

    var body: some View {
        HealthCard(
            icon: "drop.fill",
            title: "血氧",
            color: .appAccent,
            trailing: averageOxygen.map { "平均 \(Int($0 * 100))%" }
        ) {
            if samples.count > 1,
               let min = samples.map({ $0.value }).min(),
               let max = samples.map({ $0.value }).max() {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(Int(min * 100))%").font(.headline).foregroundColor(.text)
                        Text("最低").font(.caption).foregroundColor(.secondaryText)
                    }
                    VStack(spacing: 4) {
                        Text("\(Int(max * 100))%").font(.headline).foregroundColor(.text)
                        Text("最高").font(.caption).foregroundColor(.secondaryText)
                    }
                    Spacer()
                }
            }
        }
    }
}
```

- [ ] **Step 6: 替换 MenstrualDataCard**

```swift
struct MenstrualDataCard: View {
    let menstrualData: [MenstrualData]

    var body: some View {
        HealthCard(icon: "drop.fill", title: "经期", color: .pink) {
            VStack(spacing: 8) {
                ForEach(Array(menstrualData.enumerated()), id: \.element.startDate) { index, data in
                    HStack {
                        Text(formatFlowLevel(data.flowLevel))
                            .font(.subheadline).foregroundColor(.text)
                        Spacer()
                        Text(formatTime(data.startDate))
                            .font(.caption).foregroundColor(.secondaryText)
                    }
                    if index < menstrualData.count - 1 {
                        Divider().background(Color.tertiaryBackground)
                    }
                }
            }
        }
    }

    private func formatFlowLevel(_ level: MenstrualData.FlowLevel?) -> String {
        guard let level else { return "未知" }
        switch level {
        case .none: return "未记录"
        case .light: return "少量"
        case .medium: return "中等"
        case .heavy: return "大量"
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
```

- [ ] **Step 7: 替换 WristTemperatureCard**

```swift
struct WristTemperatureCard: View {
    let samples: [WristTemperatureData.TemperatureSample]

    private var averageTemperature: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0.0) { $0 + $1.value } / Double(samples.count)
    }

    var body: some View {
        HealthCard(
            icon: "thermometer",
            title: "手腕温度",
            color: .orange,
            trailing: averageTemperature.map { "平均 \(String(format: "%.2f", $0))°C" }
        ) {
            if samples.count > 1,
               let min = samples.map({ $0.value }).min(),
               let max = samples.map({ $0.value }).max() {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(String(format: "%.2f", min))°C").font(.headline).foregroundColor(.text)
                        Text("最低").font(.caption).foregroundColor(.secondaryText)
                    }
                    VStack(spacing: 4) {
                        Text("\(String(format: "%.2f", max))°C").font(.headline).foregroundColor(.text)
                        Text("最高").font(.caption).foregroundColor(.secondaryText)
                    }
                    Spacer()
                }
            }
        }
    }
}
```

- [ ] **Step 8: 替换 RespiratoryRateCard**

```swift
struct RespiratoryRateCard: View {
    let samples: [RespiratoryRateData.RespiratorySample]

    private var averageRate: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0.0) { $0 + $1.value } / Double(samples.count)
    }

    var body: some View {
        HealthCard(
            icon: "lungs",
            title: "呼吸频率",
            color: .cyan,
            trailing: averageRate.map { "平均 \(Int($0)) 次/分" }
        ) {
            if samples.count > 1,
               let min = samples.map({ $0.value }).min(),
               let max = samples.map({ $0.value }).max() {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(Int(min))").font(.headline).foregroundColor(.text)
                        Text("最低").font(.caption).foregroundColor(.secondaryText)
                    }
                    VStack(spacing: 4) {
                        Text("\(Int(max))").font(.headline).foregroundColor(.text)
                        Text("最高").font(.caption).foregroundColor(.secondaryText)
                    }
                    Spacer()
                }
            }
        }
    }
}
```

- [ ] **Step 9: 替换 BodyTemperatureCard**

```swift
struct BodyTemperatureCard: View {
    let samples: [BodyTemperatureData.BodyTempSample]

    private var averageTemperature: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0.0) { $0 + $1.value } / Double(samples.count)
    }

    var body: some View {
        HealthCard(
            icon: "thermometer.sun",
            title: "体温",
            color: .red,
            trailing: averageTemperature.map { "平均 \(String(format: "%.2f", $0))°C" }
        ) {
            if samples.count > 1,
               let min = samples.map({ $0.value }).min(),
               let max = samples.map({ $0.value }).max() {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(String(format: "%.2f", min))°C").font(.headline).foregroundColor(.text)
                        Text("最低").font(.caption).foregroundColor(.secondaryText)
                    }
                    VStack(spacing: 4) {
                        Text("\(String(format: "%.2f", max))°C").font(.headline).foregroundColor(.text)
                        Text("最高").font(.caption).foregroundColor(.secondaryText)
                    }
                    Spacer()
                }
            }
        }
    }
}
```

- [ ] **Step 10: 替换 BloodPressureCard**

```swift
struct BloodPressureCard: View {
    let samples: [BloodPressureData.BloodPressureSample]

    var body: some View {
        HealthCard(icon: "heart.text.square", title: "血压", color: .purple) {
            if let latest = samples.first {
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("\(Int(latest.systolicValue))").font(.headline).foregroundColor(.text)
                        Text("收缩压").font(.caption).foregroundColor(.secondaryText)
                    }
                    VStack(spacing: 4) {
                        Text("\(Int(latest.diastolicValue))").font(.headline).foregroundColor(.text)
                        Text("舒张压").font(.caption).foregroundColor(.secondaryText)
                    }
                    Spacer()
                }
            }
        }
    }
}
```

- [ ] **Step 11: 编译验证**

按 ⌘B。预期：Build Succeeded。若有 `extra argument` 或 `missing argument` 错误，检查对应卡片的调用参数。

- [ ] **Step 12: 提交**

```bash
git add ios/HealthSync/HealthSync/Main/HealthDetailView.swift
git commit -m "refactor(ios): migrate HealthDetailView section cards to HealthCard"
```

---

## Task 4: WorkoutDetailView — 替换内联 glass 样式

**Files:**
- Modify: `ios/HealthSync/HealthSync/Main/WorkoutDetailView.swift`

`WorkoutStatsCard` 和 `WorkoutDetailCard` 的布局不适合 `HealthCard`（无标准 icon+title header），只需将内联的 4 行样式代码替换为 `.cardStyle()`。

- [ ] **Step 1: 替换 WorkoutStatsCard 的样式**

找到 `struct WorkoutStatsCard` 的 body，将末尾的：

```swift
.padding()
.background(.ultraThinMaterial)
.cornerRadius(16)
.overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
.shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
```

替换为：

```swift
.padding()
.cardStyle()
```

- [ ] **Step 2: 替换 WorkoutDetailCard 的样式**

找到 `struct WorkoutDetailCard` 的 body，同样将末尾的：

```swift
.padding()
.background(.ultraThinMaterial)
.cornerRadius(16)
.overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.15), lineWidth: 1))
.shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
```

替换为：

```swift
.padding()
.cardStyle()
```

- [ ] **Step 3: 编译验证**

按 ⌘B。预期：Build Succeeded。

- [ ] **Step 4: 提交**

```bash
git add ios/HealthSync/HealthSync/Main/WorkoutDetailView.swift
git commit -m "refactor(ios): replace inline card styles with cardStyle() in WorkoutDetailView"
```

---

## Task 5: HomeView — 迁移 3 个内容卡片到 HealthCard

**Files:**
- Modify: `ios/HealthSync/HealthSync/Main/HomeView.swift`

`TodayHealthCard`、`TodayWorkoutCard`、`SyncOptionsCard` 改用 `HealthCard`，统一 header 结构。`StatusCard` 保留（button 交互特殊），但其内联样式已是 `.cardStyle()`，无需改动。

- [ ] **Step 1: 替换 TodayHealthCard**

用以下代码完整替换 `struct TodayHealthCard`：

```swift
struct TodayHealthCard: View {
    let summary: TodayHealthSummary?

    var body: some View {
        HealthCard(icon: "heart.fill", title: "今日健康", color: .heartRateColor) {
            HStack(spacing: 12) {
                HealthMetricCard(
                    icon: "figure.walk",
                    title: "步数",
                    value: summary?.steps != nil ? "\(summary!.steps)" : "--",
                    unit: "步",
                    color: .stepsColor
                )
                HealthMetricCard(
                    icon: "heart.fill",
                    title: "静息心率",
                    value: summary?.restingHeartRate != nil ? "\(Int(summary!.restingHeartRate!))" : "--",
                    unit: "bpm",
                    color: .heartRateColor
                )
                HealthMetricCard(
                    icon: "bed.double.fill",
                    title: "睡眠",
                    value: {
                        guard let d = summary?.sleepDuration else { return "--" }
                        let h = Int(d) / 3600
                        let m = (Int(d) % 3600) / 60
                        return m > 0 ? "\(h)h\(m)m" : "\(h)h"
                    }(),
                    unit: "",
                    color: .sleepColor
                )
            }
        }
    }
}
```

- [ ] **Step 2: 替换 TodayWorkoutCard**

用以下代码完整替换 `struct TodayWorkoutCard`：

```swift
struct TodayWorkoutCard: View {
    let workouts: [WorkoutData]

    private var totalDuration: TimeInterval { workouts.reduce(0) { $0 + $1.duration } }
    private var totalCalories: Double { workouts.compactMap(\.energy).reduce(0, +) }

    var body: some View {
        HealthCard(icon: "figure.run", title: "今日运动", color: .energyColor) {
            HStack(spacing: 20) {
                HealthMetricCard(
                    icon: "figure.run",
                    title: "运动",
                    value: "\(workouts.count)",
                    unit: "次",
                    color: .energyColor
                )
                HealthMetricCard(
                    icon: "clock",
                    title: "时长",
                    value: formatDuration(totalDuration),
                    unit: "",
                    color: .appAccent
                )
                HealthMetricCard(
                    icon: "flame.fill",
                    title: "卡路里",
                    value: "\(Int(totalCalories))",
                    unit: "千卡",
                    color: .heartRateColor
                )
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        if hours > 0 { return "\(hours)h\(minutes)m" }
        return "\(minutes)m"
    }
}
```

- [ ] **Step 3: 替换 SyncOptionsCard**

用以下代码完整替换 `struct SyncOptionsCard`：

```swift
struct SyncOptionsCard: View {
    let isSyncing: Bool
    let onSyncToday: () -> Void
    let onSyncWeek: () -> Void
    let onSyncMonth: () -> Void

    var body: some View {
        HealthCard(icon: "arrow.triangle.2.circlepath", title: "同步选项", color: .appAccent) {
            VStack(spacing: 8) {
                SyncOptionButton(
                    title: "立即同步今日数据",
                    icon: "sun.max.fill",
                    color: .appAccent,
                    isDisabled: isSyncing,
                    action: {
                        print("[HomeView] '同步今日' button tapped")
                        onSyncToday()
                    }
                )
                SyncOptionButton(
                    title: "同步最近7天",
                    icon: "calendar.badge.plus",
                    color: .stepsColor,
                    isDisabled: isSyncing,
                    action: {
                        print("[HomeView] '同步7天' button tapped")
                        onSyncWeek()
                    }
                )
                SyncOptionButton(
                    title: "同步最近30天",
                    icon: "calendar",
                    color: .energyColor,
                    isDisabled: isSyncing,
                    action: {
                        print("[HomeView] '同步30天' button tapped")
                        onSyncMonth()
                    }
                )
            }
        }
    }
}
```

- [ ] **Step 4: 编译验证**

按 ⌘B。预期：Build Succeeded。

- [ ] **Step 5: 提交**

```bash
git add ios/HealthSync/HealthSync/Main/HomeView.swift
git commit -m "refactor(ios): migrate HomeView cards to HealthCard"
```

---

## Task 6: SettingsView — List 改为 ScrollView + HealthCard

**Files:**
- Modify: `ios/HealthSync/HealthSync/Modules/Settings/Presentation/Views/SettingsView.swift`

将整个 `SettingsView` 的 body 及各 section computed property 替换如下。`SyncHourPicker` private struct 保留不动。

- [ ] **Step 1: 替换 body**

找到 `var body: some View` 块，替换为：

```swift
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
    .sheet(isPresented: $viewModel.showDevPanel) {
        DevServerView(viewModel: viewModel)
    }
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
```

- [ ] **Step 2: 替换 accountSection → accountCard**

删除原 `private var accountSection: some View`，新建：

```swift
private var accountCard: some View {
    HealthCard(icon: "person.circle.fill", title: "账户", color: .appAccent) {
        HStack {
            if let username = UserDefaultsManager.shared.username {
                Text("当前账号: \(username)")
                    .font(.subheadline)
                    .foregroundColor(.success)
            } else {
                Text("已登录")
                    .font(.subheadline)
                    .foregroundColor(.success)
            }
            Spacer()
        }
    }
}
```

- [ ] **Step 3: 替换 syncSection → syncCard**

删除原 `private var syncSection: some View`，新建：

```swift
private var syncCard: some View {
    HealthCard(icon: "arrow.triangle.2.circlepath", title: "同步设置", color: .stepsColor) {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: Binding(
                get: { viewModel.autoSyncEnabled },
                set: { viewModel.toggleAutoSync($0) }
            )) {
                Text("自动同步").foregroundColor(.text)
            }
            .tint(.appAccent)

            if viewModel.autoSyncEnabled {
                SyncHourPicker(syncHour: viewModel.syncHour) { viewModel.updateSyncHour($0) }

                Text("系统会在 \(String(format: "%02d:00", viewModel.syncHour)) 之后找合适时机执行后台同步，实际时间由 iOS 决定")
                    .font(.caption)
                    .foregroundColor(.tertiaryText)
            }
        }
    }
}
```

- [ ] **Step 4: 替换 healthPermissionSection → healthPermissionCard**

删除原 `private var healthPermissionSection: some View`，新建：

```swift
private var healthPermissionCard: some View {
    HealthCard(icon: "heart.text.square", title: "健康数据权限", color: .heartRateColor) {
        VStack(alignment: .leading, spacing: 12) {
            Button("检查授权状态") { viewModel.checkAuthorizationAndAlert() }
                .foregroundColor(.appAccent)

            Divider().background(Color.tertiaryBackground)

            Link(destination: URL(string: "x-apple-health://")!) {
                HStack {
                    Text("打开健康设置").foregroundColor(.appAccent)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .foregroundColor(.secondaryText)
                        .font(.caption)
                }
            }

            Divider().background(Color.tertiaryBackground)

            if viewModel.isRequestingAuth {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("正在请求授权...")
                        .font(.caption)
                        .foregroundColor(.secondaryText)
                        .padding(.leading, 8)
                }
            } else {
                Button("重新请求授权（首次或已删除权限时有效）") {
                    Task { await viewModel.requestHealthKitAuthorization() }
                }
                .foregroundColor(.secondaryText)
                .font(.caption)
            }

            Text("💡 如果之前拒绝了授权，系统不会再次弹窗。请点击「打开健康设置」手动开启权限。")
                .font(.caption)
                .foregroundColor(.tertiaryText)
        }
    }
}
```

- [ ] **Step 5: 替换 aboutSection → aboutCard**

删除原 `private var aboutSection: some View`，新建：

```swift
private var aboutCard: some View {
    HealthCard(icon: "info.circle", title: "关于", color: .secondaryText) {
        HStack {
            Text("版本").foregroundColor(.text)
            Spacer()
            Text("1.0.0").foregroundColor(.secondaryText)
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.handleVersionTap() }
    }
}
```

- [ ] **Step 6: 替换 logoutSection → logoutButton**

删除原 `private var logoutSection: some View`，新建：

```swift
private var logoutButton: some View {
    Button(role: .destructive) {
        viewModel.showingLogoutAlert = true
    } label: {
        HStack {
            Spacer()
            Text("退出登录")
                .font(.body)
                .fontWeight(.medium)
            Spacer()
        }
        .padding()
        .cardStyle()
    }
    .buttonStyle(.plain)
}
```

- [ ] **Step 7: 编译验证**

按 ⌘B。预期：Build Succeeded。常见错误：
- `'accountSection' is not a member of 'SettingsView'` → 检查 body 里是否还有残留的旧属性名，替换为新名称
- `'List' cannot be used here` → 确认 body 里已完全替换为 ScrollView

- [ ] **Step 8: 提交**

```bash
git add ios/HealthSync/HealthSync/Modules/Settings/Presentation/Views/SettingsView.swift
git commit -m "refactor(ios): convert SettingsView from List to ScrollView + HealthCard"
```

---

## 完成验证

所有 task 完成后，在模拟器中依次检查 4 个 Tab：

- [ ] 首页：StatusCard（同步状态）、今日健康、今日运动、同步选项 — 卡片外观一致
- [ ] 健康：各指标卡（步数、心率、HRV、睡眠等）— 统一 icon+title header，无内联 glass 样式代码
- [ ] 运动：统计卡、每条运动卡 — 外观与其他 Tab 一致
- [ ] 设置：账户、同步设置、健康权限、关于 — 改为 glass card 风格，无 List 分组线

确认 `HealthDetailView.swift` 中无 `.background(.ultraThinMaterial)` 残留（可用 Xcode 全文搜索验证）。
