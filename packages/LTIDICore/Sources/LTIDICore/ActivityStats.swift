import Foundation

public enum ActivityStatus: String, Sendable {
    /// Done at least once, no target.
    case none
    case ok
    case soon
    case overdue
    /// Never done.
    case never
}

public struct YearCount: Equatable, Identifiable, Sendable {
    public let year: Int
    public let count: Int
    public var id: Int { year }
}

public struct HistoryRow: Equatable, Identifiable, Sendable {
    public let entry: LogEntry
    /// Days since the previous (older) entry; `nil` for the first one.
    public let gap: Int?
    public var id: String { entry.id }
}

/// Port of `computeStats` (src/stats.ts).
public struct ActivityStats: Equatable, Sendable {
    /// Ascending, duplicates kept.
    public let dates: [DayDate]
    public let count: Int
    public let first: DayDate?
    public let last: DayDate?
    public let elapsed: Int?
    public let intervals: [Int]
    public let average: Double?
    public let median: Double?
    public let minInterval: Int?
    public let maxInterval: Int?
    public let status: ActivityStatus
    /// elapsed / target
    public let progress: Double?
    /// Days left to the target (negative = overdue).
    public let nextDue: Int?
    public let byYear: [YearCount]
    /// Monday … Sunday.
    public let byWeekday: [Int]
    /// January … December.
    public let byMonth: [Int]
    /// Estimated times per year.
    public let perYear: Double?

    /// Current pause minus the rounded average interval.
    public var pauseVsAverage: Int? {
        guard let elapsed, let average else { return nil }
        return elapsed - Int(average.rounded())
    }

    public var isLongestPause: Bool {
        guard let elapsed, let maxInterval else { return false }
        return elapsed > maxInterval
    }

    public static func compute(activity: Activity, entries: [LogEntry], settings: AppSettings, today: DayDate) -> ActivityStats {
        let dates = entries.filter { $0.activityID == activity.id }.map(\.date).sorted()
        let count = dates.count
        let first = dates.first
        let last = dates.last
        let elapsed = last.map { DayDate.daysBetween($0, today) }

        var unique: [DayDate] = []
        for d in dates where unique.last != d { unique.append(d) }
        let intervals = zip(unique, unique.dropFirst()).map { DayDate.daysBetween($0, $1) }
        let sorted = intervals.sorted()
        let average: Double? = intervals.isEmpty ? nil : Double(intervals.reduce(0, +)) / Double(intervals.count)
        let median: Double?
        if sorted.isEmpty {
            median = nil
        } else if sorted.count % 2 == 1 {
            median = Double(sorted[(sorted.count - 1) / 2])
        } else {
            median = Double(sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        }

        var status = ActivityStatus.none
        var progress: Double?
        var nextDue: Int?
        if let elapsed {
            if let target = activity.targetDays, target > 0 {
                let p = Double(elapsed) / Double(target)
                progress = p
                nextDue = target - elapsed
                status = p >= 1 ? .overdue : (p * 100 >= Double(settings.dueSoonPercent) ? .soon : .ok)
            }
        } else {
            status = .never
        }

        var years: [Int: Int] = [:]
        var byWeekday = Array(repeating: 0, count: 7)
        var byMonth = Array(repeating: 0, count: 12)
        for d in dates {
            years[d.year, default: 0] += 1
            byWeekday[d.weekdayFromMonday] += 1
            byMonth[d.month - 1] += 1
        }
        let byYear = years.keys.sorted().map { YearCount(year: $0, count: years[$0] ?? 0) }
        let perYear = first.map { Double(count) / Double(max(1, DayDate.daysBetween($0, today) + 1)) * 365 }

        return ActivityStats(
            dates: dates, count: count, first: first, last: last, elapsed: elapsed,
            intervals: intervals, average: average, median: median,
            minInterval: sorted.first, maxInterval: sorted.last,
            status: status, progress: progress, nextDue: nextDue,
            byYear: byYear, byWeekday: byWeekday, byMonth: byMonth, perYear: perYear
        )
    }

    public static func countByDate(_ dates: [DayDate]) -> [DayDate: Int] {
        var counts: [DayDate: Int] = [:]
        for d in dates { counts[d, default: 0] += 1 }
        return counts
    }

    /// Entries of one activity, newest first, with the gap to the previous one.
    public static func history(activityID: String, entries: [LogEntry]) -> [HistoryRow] {
        let list = entries.filter { $0.activityID == activityID }.stableSorted { $0.date > $1.date }
        return list.indices.map { i in
            let gap = i + 1 < list.count ? DayDate.daysBetween(list[i + 1].date, list[i].date) : nil
            return HistoryRow(entry: list[i], gap: gap)
        }
    }
}
