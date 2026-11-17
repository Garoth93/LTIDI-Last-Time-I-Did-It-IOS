import SwiftUI
import Charts

/// Days between consecutive registrations, with the target as a dashed line.
struct IntervalChart: View {
    let values: [Int]
    let color: Color
    let target: Int?

    var body: some View {
        if values.count < 2 {
            Text("Servono almeno 3 registrazioni per vedere l'andamento.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Chart {
                ForEach(targetLine, id: \.self) { t in
                    RuleMark(y: .value("Obiettivo", t))
                        .foregroundStyle(.secondary)
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
                ForEach(Array(values.enumerated()), id: \.offset) { point in
                    AreaMark(x: .value("Volta", point.offset), y: .value("Giorni", point.element))
                        .foregroundStyle(color.opacity(0.12))
                    LineMark(x: .value("Volta", point.offset), y: .value("Giorni", point.element))
                        .foregroundStyle(color)
                    PointMark(x: .value("Volta", point.offset), y: .value("Giorni", point.element))
                        .foregroundStyle(color)
                        .symbolSize(24)
                }
            }
            .chartXAxis(.hidden)
            .frame(height: 120)
        }
    }

    private var targetLine: [Int] {
        guard let target, target > 0 else { return [] }
        return [target]
    }
}

/// Simple bar chart with fixed labels (weekday, month, year).
struct BarsChart: View {
    let values: [Int]
    let labels: [String]
    let color: Color

    var body: some View {
        Chart(Array(values.enumerated()), id: \.offset) { item in
            BarMark(x: .value("Periodo", String(item.offset)), y: .value("Volte", item.element))
                .foregroundStyle(color.opacity(item.element > 0 ? 1 : 0.15))
                .annotation(position: .top) {
                    if item.element > 0 {
                        Text("\(item.element)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
        }
        .chartXAxis {
            AxisMarks(values: values.indices.map { String($0) }) { value in
                AxisValueLabel {
                    if let key = value.as(String.self), let index = Int(key), labels.indices.contains(index) {
                        Text(labels[index])
                    }
                }
            }
        }
        .chartYAxis(.hidden)
        .frame(height: 110)
    }
}
