import Foundation

public struct HomeItem: Equatable, Identifiable, Sendable {
    public let activity: Activity
    public let stats: ActivityStats
    public var id: String { activity.id }
}

public struct HomeGroup: Equatable, Identifiable, Sendable {
    /// Empty when not grouping by category.
    public let name: String
    public let items: [HomeItem]
    public var id: String { name }
}

public struct HomeSummary: Equatable, Sendable {
    public let totalEntries: Int
    public let lastSevenDays: Int
    public let overdue: Int
    public let soon: Int
}

/// Port of the home screen logic (src/components/Home.tsx).
public enum HomeBuilder {
    public static let uncategorized = "Senza categoria"

    /// Visible activities (archived / search filter) with stats, sorted by the setting.
    public static func items(for data: AppData, query: String = "", today: DayDate) -> [HomeItem] {
        let settings = data.settings
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let visible = data.activities.filter { a in
            (settings.showArchived || !a.archived) && (q.isEmpty || "\(a.name) \(a.category)".lowercased().contains(q))
        }
        let items = visible.map {
            HomeItem(activity: $0, stats: .compute(activity: $0, entries: data.entries, settings: settings, today: today))
        }
        let big = Int.max
        switch settings.sort {
        case .manual:
            return items.stableSorted { $0.activity.order < $1.activity.order }
        case .name:
            return items.stableSorted { ItalianFormat.compare($0.activity.name, $1.activity.name) == .orderedAscending }
        case .elapsedDesc:
            return items.stableSorted { ($0.stats.elapsed ?? big) > ($1.stats.elapsed ?? big) }
        case .elapsedAsc:
            return items.stableSorted { ($0.stats.elapsed ?? big) < ($1.stats.elapsed ?? big) }
        case .due:
            return items.stableSorted { ($0.stats.nextDue ?? big) < ($1.stats.nextDue ?? big) }
        }
    }

    public static func groups(_ items: [HomeItem], byCategory: Bool) -> [HomeGroup] {
        guard byCategory else { return [HomeGroup(name: "", items: items)] }
        var names: [String] = []
        var map: [String: [HomeItem]] = [:]
        for item in items {
            let key = item.activity.category.isEmpty ? uncategorized : item.activity.category
            if map[key] == nil { names.append(key) }
            map[key, default: []].append(item)
        }
        return names
            .stableSorted { ItalianFormat.compare($0, $1) == .orderedAscending }
            .map { HomeGroup(name: $0, items: map[$0] ?? []) }
    }

    public static func summary(for data: AppData, items: [HomeItem], today: DayDate) -> HomeSummary {
        let from = today.adding(days: -6)
        return HomeSummary(
            totalEntries: data.entries.count,
            lastSevenDays: data.entries.filter { $0.date >= from }.count,
            overdue: items.filter { $0.stats.status == .overdue }.count,
            soon: items.filter { $0.stats.status == .soon }.count
        )
    }

    /// Per-day counts of all non-archived activities (global heatmap).
    public static func globalCounts(_ data: AppData) -> [DayDate: Int] {
        let active = Set(data.activities.filter { !$0.archived }.map(\.id))
        return ActivityStats.countByDate(data.entries.filter { active.contains($0.activityID) }.map(\.date))
    }

    /// Up/down arrows are shown only in manual order without grouping.
    public static func canReorder(_ settings: AppSettings) -> Bool {
        settings.sort == .manual && !settings.groupByCategory
    }
}
