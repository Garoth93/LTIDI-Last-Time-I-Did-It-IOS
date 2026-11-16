import Foundation

/// Value-type container with all the non-UI rules of the app.
/// The SwiftUI layer wraps this in an observable object and persists it.
public struct ActivityList: Codable, Equatable, Sendable {
    public private(set) var activities: [Activity]

    public init(activities: [Activity] = []) {
        self.activities = activities
    }

    /// Adds a new activity. Whitespace-only names are ignored and the
    /// method returns `nil`; otherwise the created activity is returned.
    @discardableResult
    public mutating func add(name: String, lastDone: Date? = nil) -> Activity? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let activity = Activity(name: trimmed, lastDone: lastDone)
        activities.append(activity)
        return activity
    }

    /// Records that the activity with `id` was done at `date`.
    /// Unknown ids are ignored.
    public mutating func markDone(id: Activity.ID, at date: Date = Date()) {
        guard let index = activities.firstIndex(where: { $0.id == id }) else { return }
        activities[index].lastDone = date
    }

    /// Renames an activity. Whitespace-only names are ignored.
    public mutating func rename(id: Activity.ID, to name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let index = activities.firstIndex(where: { $0.id == id }) else { return }
        activities[index].name = trimmed
    }

    public mutating func remove(id: Activity.ID) {
        activities.removeAll { $0.id == id }
    }

    /// Activities ordered by "staleness": never-done first, then the ones
    /// done longest ago. Ties keep the insertion order.
    public func sortedByStaleness() -> [Activity] {
        activities.enumerated().sorted { lhs, rhs in
            switch (lhs.element.lastDone, rhs.element.lastDone) {
            case (nil, nil): return lhs.offset < rhs.offset
            case (nil, _): return true
            case (_, nil): return false
            case let (l?, r?):
                if l == r { return lhs.offset < rhs.offset }
                return l < r
            }
        }.map(\.element)
    }
}
