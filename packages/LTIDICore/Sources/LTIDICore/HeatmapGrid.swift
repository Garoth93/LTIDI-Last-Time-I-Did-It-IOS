import Foundation

public struct HeatmapCell: Hashable, Sendable {
    public let date: DayDate
    public let count: Int
    public let isFuture: Bool
}

public struct HeatmapMonthLabel: Hashable, Sendable {
    public let column: Int
    public let label: String
}

/// GitHub-contributions-style grid: columns = weeks, rows = weekdays.
/// Port of src/components/Heatmap.tsx (layout only, drawing is in the app).
public struct HeatmapGrid: Equatable, Sendable {
    public let columns: [[HeatmapCell]]
    public let monthLabels: [HeatmapMonthLabel]
    public let maxCount: Int
    public let end: DayDate
    public let weekStart: Int

    /// Percent of the base color mixed into the empty cell color, per level.
    public static let mixPercent = [0, 30, 55, 78, 100]

    public init(counts: [DayDate: Int], weeks: Int, weekStart: Int, end: DayDate) {
        let weeks = max(1, weeks)
        let endDow = ((end.weekdayFromSunday - weekStart) % 7 + 7) % 7
        let start = end.adding(days: -(weeks - 1) * 7 - endDow)
        var columns: [[HeatmapCell]] = []
        var labels: [HeatmapMonthLabel] = []
        var maxCount = 0
        var lastMonth = -1
        for w in 0..<weeks {
            var column: [HeatmapCell] = []
            for d in 0..<7 {
                let date = start.adding(days: w * 7 + d)
                let count = counts[date] ?? 0
                maxCount = max(maxCount, count)
                column.append(HeatmapCell(date: date, count: count, isFuture: date > end))
            }
            let month = column[0].date.month
            if month != lastMonth {
                if w < weeks - 1 { labels.append(HeatmapMonthLabel(column: w, label: ItalianFormat.monthShort[month - 1])) }
                lastMonth = month
            }
            columns.append(column)
        }
        self.columns = columns
        self.monthLabels = labels
        self.maxCount = maxCount
        self.end = end
        self.weekStart = weekStart
    }

    /// 0 (empty) … 4 (max).
    public func level(for count: Int) -> Int {
        if count == 0 { return 0 }
        if maxCount <= 1 { return 4 }
        return min(4, Int((Double(count) / Double(maxCount) * 4).rounded(.up)))
    }

    public func mixFraction(for count: Int) -> Double {
        Double(HeatmapGrid.mixPercent[level(for: count)]) / 100
    }

    public static func dayLabels(weekStart: Int) -> [String] {
        weekStart == 1 ? ["L", "", "M", "", "V", "", ""] : ["", "L", "", "M", "", "V", ""]
    }
}
