import XCTest
@testable import LTIDICore

final class ActivityStatsTests: XCTestCase {
    let today = DayDate(iso: "2026-11-16")!

    private func entries(_ activity: Activity, daysAgo: [Int]) -> [LogEntry] {
        daysAgo.map { LogEntry(activityID: activity.id, date: today.adding(days: -$0)) }
    }

    func testIntervalsAverageMedianAndStatus() {
        let a = Activity(name: "Nonni", targetDays: 10)
        let other = Activity(name: "Altro")
        let all = entries(a, daysAgo: [25, 12, 3, 3]) + entries(other, daysAgo: [1])
        let s = ActivityStats.compute(activity: a, entries: all, settings: AppSettings(), today: today)

        XCTAssertEqual(s.count, 4)
        XCTAssertEqual(s.last, today.adding(days: -3))
        XCTAssertEqual(s.first, today.adding(days: -25))
        XCTAssertEqual(s.elapsed, 3)
        XCTAssertEqual(s.intervals, [13, 9])
        XCTAssertEqual(s.average, 11)
        XCTAssertEqual(s.median, 11)
        XCTAssertEqual(s.minInterval, 9)
        XCTAssertEqual(s.maxInterval, 13)
        XCTAssertEqual(s.status, .ok)
        XCTAssertEqual(s.progress, 0.3)
        XCTAssertEqual(s.nextDue, 7)
        XCTAssertEqual(s.byWeekday.reduce(0, +), 4)
        XCTAssertEqual(s.byMonth.reduce(0, +), 4)
        XCTAssertEqual(s.byYear, [YearCount(year: 2026, count: 4)])
        XCTAssertEqual(s.pauseVsAverage, -8)
        XCTAssertFalse(s.isLongestPause)
        XCTAssertEqual(s.perYear!, 4.0 / 26.0 * 365, accuracy: 0.0001)
    }

    func testSoonAndOverdueThresholds() {
        let a = Activity(name: "A", targetDays: 10)
        var settings = AppSettings()
        settings.dueSoonPercent = 80
        let soon = ActivityStats.compute(activity: a, entries: entries(a, daysAgo: [8]), settings: settings, today: today)
        XCTAssertEqual(soon.status, .soon)
        let overdue = ActivityStats.compute(activity: a, entries: entries(a, daysAgo: [10]), settings: settings, today: today)
        XCTAssertEqual(overdue.status, .overdue)
        XCTAssertEqual(overdue.nextDue, 0)
    }

    func testNeverAndNoTarget() {
        let a = Activity(name: "A", targetDays: 10)
        let never = ActivityStats.compute(activity: a, entries: [], settings: AppSettings(), today: today)
        XCTAssertEqual(never.status, .never)
        XCTAssertNil(never.elapsed)
        XCTAssertNil(never.average)
        XCTAssertNil(never.perYear)

        let b = Activity(name: "B")
        let noTarget = ActivityStats.compute(activity: b, entries: entries(b, daysAgo: [40, 2]), settings: AppSettings(), today: today)
        XCTAssertEqual(noTarget.status, .none)
        XCTAssertNil(noTarget.progress)
        XCTAssertTrue(ActivityStats.compute(activity: b, entries: entries(b, daysAgo: [50, 45]), settings: AppSettings(), today: today).isLongestPause)
    }

    func testOddMedian() {
        let a = Activity(name: "A")
        let s = ActivityStats.compute(activity: a, entries: entries(a, daysAgo: [30, 20, 15, 5]), settings: AppSettings(), today: today)
        XCTAssertEqual(s.intervals, [10, 5, 10])
        XCTAssertEqual(s.median, 10)
    }

    func testHistoryNewestFirstWithGaps() {
        let a = Activity(name: "A")
        let rows = ActivityStats.history(activityID: a.id, entries: entries(a, daysAgo: [10, 1, 4]))
        XCTAssertEqual(rows.map(\.entry.date), [today.adding(days: -1), today.adding(days: -4), today.adding(days: -10)])
        XCTAssertEqual(rows.map(\.gap), [3, 6, nil])
    }
}
