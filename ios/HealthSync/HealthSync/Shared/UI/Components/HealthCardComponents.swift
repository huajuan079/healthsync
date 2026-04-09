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
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                    .accessibilityHidden(true)
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
//
// NOTE: This is a standalone full-width card. Do NOT nest inside HealthCard —
// it already applies cardStyle() internally, which would cause double-glass layering.
// For compact vertical metric cells (used inside HealthCard content), see
// HealthMetricCard in HomeView.swift.

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
                .accessibilityHidden(true)

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

#Preview {
    VStack(spacing: 16) {
        HealthCard(icon: "heart.fill", title: "心率", color: Color(red: 0.92, green: 0.30, blue: 0.40), trailing: "平均 72 bpm") {
            Text("Sample content").foregroundColor(.secondary)
        }
        MetricCard(icon: "figure.walk", title: "步数", value: "8,432", unit: "步", color: Color(red: 0.25, green: 0.65, blue: 0.90))
    }
    .padding()
    .background(Color(UIColor.systemBackground))
}
