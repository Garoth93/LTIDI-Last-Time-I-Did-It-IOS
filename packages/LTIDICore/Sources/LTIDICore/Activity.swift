import Foundation

/// A tracked activity: something you do from time to time and want to
/// remember when you last did it ("Last Time I Did It").
public struct Activity: Codable, Identifiable, Equatable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    /// Date of the most recent completion, `nil` if never done.
    public var lastDone: Date?

    public init(id: UUID = UUID(), name: String, lastDone: Date? = nil) {
        self.id = id
        self.name = name
        self.lastDone = lastDone
    }

    /// Whole days elapsed since `lastDone`, measured on calendar days
    /// (so "yesterday at 23:00" vs "today at 01:00" counts as 1 day).
    /// Returns `nil` when the activity was never done.
    public func daysSince(_ now: Date = Date(), calendar: Calendar = .current) -> Int? {
        guard let lastDone else { return nil }
        let start = calendar.startOfDay(for: lastDone)
        let end = calendar.startOfDay(for: now)
        return calendar.dateComponents([.day], from: start, to: end).day
    }
}
