import SwiftUI
import LTIDICore

/// GitHub-style contribution grid drawn from `HeatmapGrid` (LTIDICore).
struct HeatmapView: View {
    let grid: HeatmapGrid
    let baseColor: Color
    var cell: CGFloat = 11
    var gap: CGFloat = 3
    var showLabels = true
    var onSelect: ((DayDate) -> Void)?

    private let dayLabelWidth: CGFloat = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showLabels {
                ZStack(alignment: .topLeading) {
                    ForEach(grid.monthLabels, id: \.self) { month in
                        Text(month.label)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .fixedSize()
                            .offset(x: dayLabelWidth + gap + CGFloat(month.column) * (cell + gap))
                    }
                }
                .frame(width: totalWidth, height: 11, alignment: .topLeading)
            }
            HStack(alignment: .top, spacing: gap) {
                if showLabels {
                    VStack(spacing: gap) {
                        ForEach(Array(HeatmapGrid.dayLabels(weekStart: grid.weekStart).enumerated()), id: \.offset) { item in
                            Text(item.element)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .frame(width: dayLabelWidth, height: cell)
                        }
                    }
                }
                ForEach(grid.columns.indices, id: \.self) { column in
                    VStack(spacing: gap) {
                        ForEach(grid.columns[column], id: \.date) { c in
                            cellView(c)
                        }
                    }
                }
            }
        }
        .accessibilityLabel("Griglia delle registrazioni")
    }

    private var totalWidth: CGFloat {
        (showLabels ? dayLabelWidth + gap : 0) + CGFloat(grid.columns.count) * (cell + gap)
    }

    @ViewBuilder
    private func cellView(_ c: HeatmapCell) -> some View {
        let shape = RoundedRectangle(cornerRadius: max(2, cell * 0.22), style: .continuous)
        shape
            .fill(Color.cellEmpty)
            .overlay(shape.fill(baseColor.opacity(grid.mixFraction(for: c.count))))
            .overlay {
                if c.date == grid.end {
                    shape.stroke(Color.primary.opacity(0.45), lineWidth: 1)
                }
            }
            .frame(width: cell, height: cell)
            .opacity(c.isFuture ? 0 : 1)
            .contentShape(Rectangle())
            .onTapGesture {
                if !c.isFuture { onSelect?(c.date) }
            }
            .allowsHitTesting(onSelect != nil && !c.isFuture)
    }
}

/// Horizontally scrollable heatmap that opens on the most recent weeks.
struct ScrollingHeatmap: View {
    let grid: HeatmapGrid
    let baseColor: Color
    var cell: CGFloat = 11
    var onSelect: ((DayDate) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HeatmapView(grid: grid, baseColor: baseColor, cell: cell, onSelect: onSelect)
                .padding(.vertical, 2)
        }
        .defaultScrollAnchor(.trailing)
        .id(grid.end)
    }
}
