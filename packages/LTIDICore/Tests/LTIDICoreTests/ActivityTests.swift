import XCTest
@testable import LTIDICore

final class ActivityTests: XCTestCase {
    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    private func date(_ iso: String) -> Date {
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: iso)!
    }

    func testDaysSinceIsNilWhenNeverDone() {
        let activity = Activity(name: "Run")
        XCTAssertNil(activity.daysSince(date("2026-01-10T12:00:00Z"), calendar: calendar))
    }

    func testDaysSinceCountsCalendarDays() {
        let activity = Activity(name: "Run", lastDone: date("2026-01-01T23:30:00Z"))
        XCTAssertEqual(activity.daysSince(date("2026-01-02T00:30:00Z"), calendar: calendar), 1)
        XCTAssertEqual(activity.daysSince(date("2026-01-01T23:59:00Z"), calendar: calendar), 0)
        XCTAssertEqual(activity.daysSince(date("2026-01-11T08:00:00Z"), calendar: calendar), 10)
    }

    func testCodableRoundTrip() throws {
        let original = Activity(name: "Ski", lastDone: date("2026-02-14T09:00:00Z"))
        let data = try JSONFileStore<Activity>.encoder.encode(original)
        let decoded = try JSONFileStore<Activity>.decoder.decode(Activity.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
