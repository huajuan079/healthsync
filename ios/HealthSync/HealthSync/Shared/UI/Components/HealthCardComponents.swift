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
