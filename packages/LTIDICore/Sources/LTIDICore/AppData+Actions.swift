import Foundation

// Port of the PWA's `actions` (src/store.ts) as value-type mutations.

extension AppData {
    public func activity(id: String) -> Activity? {
        activities.first { $0.id == id }
    }

    /// Distinct non-empty categories in insertion order (for suggestions).
    public var categories: [String] {
        var seen = Set<String>()
        return activities.compactMap { a in
            guard !a.category.isEmpty, seen.insert(a.category).inserted else { return nil }
            return a.category
        }
    }

    /// A blank activity like the PWA's "Nuova attività" form.
    public func newActivityTemplate() -> Activity {
        Activity(name: "", color: Palette.colors[activities.count % Palette.colors.count], order: activities.count)
    }

    /// Insert or replace (matched by id).
    public mutating func saveActivity(_ activity: Activity) {
        if let index = activities.firstIndex(where: { $0.id == activity.id }) {
            activities[index] = activity
        } else {
            activities.append(activity)
        }
    }

    /// Removes the activity and all its entries.
    public mutating func deleteActivity(id: String) {
        activities.removeAll { $0.id == id }
        entries.removeAll { $0.activityID == id }
    }

    public mutating func reorder(ids: [String]) {
        for i in activities.indices {
            if let position = ids.firstIndex(of: activities[i].id) {
                activities[i].order = position
            }
        }
    }

    /// Moves an activity up (-1) or down (+1) in manual order.
    public mutating func moveActivity(id: String, by direction: Int) {
        var ids = activities.stableSorted { $0.order < $1.order }.map(\.id)
        guard let i = ids.firstIndex(of: id) else { return }
        let j = i + direction
        guard j >= 0, j < ids.count else { return }
        ids.swapAt(i, j)
        reorder(ids: ids)
    }

    @discardableResult
    public mutating func addEntry(activityID: String, date: DayDate, note: String = "") -> String {
        let entry = LogEntry(activityID: activityID, date: date, note: note)
        entries.append(entry)
        return entry.id
    }

    public mutating func updateEntry(_ entry: LogEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
        }
    }

    public mutating func deleteEntry(id: String) {
        entries.removeAll { $0.id == id }
    }

    public func hasEntry(activityID: String, on date: DayDate) -> Bool {
        entries.contains { $0.activityID == activityID && $0.date == date }
    }

    /// `withDemo == true` loads the sample data (settings reset to defaults,
    /// like the PWA); otherwise clears activities and entries, keeping settings.
    public mutating func resetAll(withDemo: Bool, today: DayDate) {
        self = withDemo ? AppData.demo(today: today) : AppData(settings: settings)
    }

    /// The PWA's first-run sample data.
    public static func demo(today: DayDate) -> AppData {
        let activities = [
            Activity(name: "Dentista", emoji: "🦷", color: "#0969da", category: "Salute", targetDays: 180, order: 0),
            Activity(name: "Parrucchiere", emoji: "💇", color: "#bf3989", category: "Cura personale", targetDays: 35, order: 1),
            Activity(name: "Cambio lenzuola", emoji: "🛏️", color: "#8250df", category: "Casa", targetDays: 14, order: 2),
            Activity(name: "Chiamato i nonni", emoji: "📞", color: "#2da44e", category: "Persone", targetDays: 10, order: 3)
        ]
        let plan: [(Int, Int)] = [(0, 160), (0, 350), (1, 30), (1, 66), (1, 101), (2, 6), (2, 20), (2, 35), (3, 3), (3, 12), (3, 25)]
        let entries = plan.map { LogEntry(activityID: activities[$0.0].id, date: today.adding(days: -$0.1)) }
        return AppData(activities: activities, entries: entries, settings: AppSettings())
    }

    // MARK: - Import / export

    /// Pretty JSON in the PWA backup format.
    public func exportJSON() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// Accepts a PWA backup (or a native export). Throws `AppDataError.invalidFile`.
    public static func importJSON(_ data: Data) throws -> AppData {
        do {
            return try JSONDecoder().decode(AppData.self, from: data)
        } catch {
            throw AppDataError.invalidFile
        }
    }

    /// Same columns as the PWA: data,attivita,categoria,nota.
    public func exportCSV() -> String {
        let byID = Dictionary(activities.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        func escape(_ s: String) -> String { "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        let rows = entries.stableSorted { $0.date < $1.date }.map { e -> String in
            let a = byID[e.activityID]
            return [e.date.iso, escape(a?.name ?? ""), escape(a?.category ?? ""), escape(e.note)].joined(separator: ",")
        }
        return (["data,attivita,categoria,nota"] + rows).joined(separator: "\n")
    }
}
