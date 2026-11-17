import Foundation

// Data model. The JSON shape is IDENTICAL to the PWA's localStorage /
// backup format (`AppData` in src/types.ts), so a PWA backup can be imported
// as-is and a native export can be imported back into the PWA.

public enum ThemeMode: String, Codable, CaseIterable, Sendable {
    case auto, light, dark

    public var label: String {
        switch self {
        case .auto: return "Auto"
        case .light: return "Chiaro"
        case .dark: return "Scuro"
        }
    }
}

public enum SortMode: String, Codable, CaseIterable, Sendable {
    case elapsedDesc = "elapsed-desc"
    case elapsedAsc = "elapsed-asc"
    case due
    case name
    case manual

    public var label: String {
        switch self {
        case .elapsedDesc: return "Da più tempo"
        case .elapsedAsc: return "Più recenti"
        case .due: return "Scadenza obiettivo"
        case .name: return "Nome"
        case .manual: return "Manuale (frecce)"
        }
    }
}

public enum DurationFormat: String, Codable, CaseIterable, Sendable {
    case smart, days

    public var label: String {
        switch self {
        case .smart: return "Intelligente (sett/mesi)"
        case .days: return "Sempre in giorni"
        }
    }
}

public enum HeatmapPalette: String, Codable, CaseIterable, Sendable {
    case activity, github, mono

    public var label: String {
        switch self {
        case .activity: return "Per attività"
        case .github: return "Verde GitHub"
        case .mono: return "Monocromo"
        }
    }
}

public struct Activity: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var emoji: String
    /// Hex color "#rrggbb".
    public var color: String
    public var category: String
    /// Every how many days you would like to do it (`nil` = no target).
    public var targetDays: Int?
    public var notes: String
    public var archived: Bool
    public var order: Int
    /// ISO 8601 timestamp.
    public var createdAt: String

    public init(
        id: String = IDGenerator.make(),
        name: String,
        emoji: String = "✅",
        color: String = Palette.colors[0],
        category: String = "",
        targetDays: Int? = nil,
        notes: String = "",
        archived: Bool = false,
        order: Int = 0,
        createdAt: String = IDGenerator.timestamp()
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.color = color
        self.category = category
        self.targetDays = targetDays
        self.notes = notes
        self.archived = archived
        self.order = order
        self.createdAt = createdAt
    }

    public var hasTarget: Bool { (targetDays ?? 0) > 0 }

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, color, category, targetDays, notes, archived, order, createdAt
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(emoji, forKey: .emoji)
        try c.encode(color, forKey: .color)
        try c.encode(category, forKey: .category)
        if let targetDays { try c.encode(targetDays, forKey: .targetDays) } else { try c.encodeNil(forKey: .targetDays) }
        try c.encode(notes, forKey: .notes)
        try c.encode(archived, forKey: .archived)
        try c.encode(order, forKey: .order)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

public struct LogEntry: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var activityID: String
    public var date: DayDate
    public var note: String

    public init(id: String = IDGenerator.make(), activityID: String, date: DayDate, note: String = "") {
        self.id = id
        self.activityID = activityID
        self.date = date
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case id
        case activityID = "activityId"
        case date, note
    }
}

public struct AppSettings: Codable, Equatable, Sendable {
    public var theme: ThemeMode = .auto
    public var accent: String = Palette.defaultAccent
    public var sort: SortMode = .elapsedDesc
    public var durationFormat: DurationFormat = .smart
    /// 1 = Monday, 0 = Sunday.
    public var weekStart: Int = 1
    public var heatmapPalette: HeatmapPalette = .activity
    public var heatmapWeeks: Int = 26
    public var showGlobalHeatmap = true
    public var showMiniHeatmap = true
    public var dueSoonPercent: Int = 80
    public var groupByCategory = false
    public var confirmQuickLog = false
    public var showArchived = false

    public init() {}

    enum CodingKeys: String, CodingKey {
        case theme, accent, sort, durationFormat, weekStart, heatmapPalette, heatmapWeeks
        case showGlobalHeatmap, showMiniHeatmap, dueSoonPercent, groupByCategory, confirmQuickLog, showArchived
    }

    /// Lenient: every missing or invalid field falls back to its default,
    /// like the PWA's `{ ...DEFAULT_SETTINGS, ...saved }`.
    public init(from decoder: Decoder) throws {
        self.init()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let v = c.lenientString(.theme).flatMap(ThemeMode.init(rawValue:)) { theme = v }
        if let v = c.lenientString(.accent), RGBColor(hex: v) != nil { accent = v }
        if let v = c.lenientString(.sort).flatMap(SortMode.init(rawValue:)) { sort = v }
        if let v = c.lenientString(.durationFormat).flatMap(DurationFormat.init(rawValue:)) { durationFormat = v }
        if let v = c.lenientInt(.weekStart), v == 0 || v == 1 { weekStart = v }
        if let v = c.lenientString(.heatmapPalette).flatMap(HeatmapPalette.init(rawValue:)) { heatmapPalette = v }
        if let v = c.lenientInt(.heatmapWeeks) { heatmapWeeks = min(53, max(8, v)) }
        if let v = c.lenientBool(.showGlobalHeatmap) { showGlobalHeatmap = v }
        if let v = c.lenientBool(.showMiniHeatmap) { showMiniHeatmap = v }
        if let v = c.lenientInt(.dueSoonPercent) { dueSoonPercent = min(99, max(50, v)) }
        if let v = c.lenientBool(.groupByCategory) { groupByCategory = v }
        if let v = c.lenientBool(.confirmQuickLog) { confirmQuickLog = v }
        if let v = c.lenientBool(.showArchived) { showArchived = v }
    }
}

public enum AppDataError: Error, LocalizedError, Equatable {
    case invalidFile

    public var errorDescription: String? { "File non valido" }
}

public struct AppData: Codable, Equatable, Sendable {
    public var version: Int
    public var activities: [Activity]
    public var entries: [LogEntry]
    public var settings: AppSettings

    public init(activities: [Activity] = [], entries: [LogEntry] = [], settings: AppSettings = AppSettings()) {
        version = 1
        self.activities = activities
        self.entries = entries
        self.settings = settings
    }

    enum CodingKeys: String, CodingKey {
        case version, activities, entries, settings
    }

    /// Port of the PWA's `normalize()`: fills missing fields, drops invalid
    /// entries, merges settings with defaults. Throws `invalidFile` when
    /// `activities` or `entries` are not arrays.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let rawActivities = try? c.decode([Lossy<RawActivity>?].self, forKey: .activities),
              let rawEntries = try? c.decode([Lossy<RawEntry>?].self, forKey: .entries) else {
            throw AppDataError.invalidFile
        }
        version = 1
        activities = rawActivities.enumerated().compactMap { index, wrapper in
            guard let r = wrapper?.value else { return nil }
            return Activity(
                id: r.id ?? IDGenerator.make(),
                name: r.name ?? "Senza nome",
                emoji: r.emoji ?? "✅",
                color: r.color ?? Palette.colors[0],
                category: r.category ?? "",
                targetDays: r.targetDays,
                notes: r.notes ?? "",
                archived: r.archived ?? false,
                order: r.order ?? index,
                createdAt: r.createdAt ?? IDGenerator.timestamp()
            )
        }
        entries = rawEntries.compactMap { wrapper in
            guard let r = wrapper?.value,
                  let activityID = r.activityId, !activityID.isEmpty,
                  let dateString = r.date, let date = DayDate(iso: dateString) else { return nil }
            return LogEntry(id: r.id ?? IDGenerator.make(), activityID: activityID, date: date, note: r.note ?? "")
        }
        settings = (try? c.decodeIfPresent(AppSettings.self, forKey: .settings)) ?? AppSettings()
    }
}

public enum IDGenerator {
    public static func make() -> String { UUID().uuidString.lowercased() }

    public static func timestamp(_ date: Date = Date()) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

// MARK: - Lenient decoding helpers

struct Lossy<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

struct RawActivity: Decodable {
    let id, name, emoji, color, category, notes, createdAt: String?
    let targetDays: Int?
    let archived: Bool?
    let order: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, emoji, color, category, targetDays, notes, archived, order, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id)
        name = c.lenientString(.name)
        emoji = c.lenientString(.emoji)
        color = c.lenientString(.color)
        category = c.lenientString(.category)
        notes = c.lenientString(.notes)
        createdAt = c.lenientString(.createdAt)
        targetDays = c.lenientInt(.targetDays)
        archived = c.lenientBool(.archived)
        order = c.lenientInt(.order)
    }
}

struct RawEntry: Decodable {
    let id, activityId, date, note: String?

    enum CodingKeys: String, CodingKey {
        case id, activityId, date, note
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.lenientString(.id)
        activityId = c.lenientString(.activityId)
        date = c.lenientString(.date)
        note = c.lenientString(.note)
    }
}

extension KeyedDecodingContainer {
    func lenientString(_ key: Key) -> String? {
        try? decodeIfPresent(String.self, forKey: key)
    }

    func lenientInt(_ key: Key) -> Int? {
        if let i = try? decodeIfPresent(Int.self, forKey: key) { return i }
        if let d = try? decodeIfPresent(Double.self, forKey: key), d.isFinite { return Int(d.rounded()) }
        if let s = try? decodeIfPresent(String.self, forKey: key), let i = Int(s) { return i }
        return nil
    }

    func lenientBool(_ key: Key) -> Bool? {
        if let b = try? decodeIfPresent(Bool.self, forKey: key) { return b }
        if let i = lenientInt(key) { return i != 0 }
        return nil
    }
}

extension Array {
    /// Sort that keeps the original order of equal elements (like JS `Array.sort`).
    func stableSorted(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Element] {
        enumerated().sorted { lhs, rhs in
            if areInIncreasingOrder(lhs.element, rhs.element) { return true }
            if areInIncreasingOrder(rhs.element, lhs.element) { return false }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }
}
