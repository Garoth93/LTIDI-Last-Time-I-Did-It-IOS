import XCTest
@testable import LTIDICore

final class HomeBuilderTests: XCTestCase {
    let today = DayDate(iso: "2026-11-16")!

    private func sample() -> AppData {
        var data = AppData()
        let never = Activity(id: "never", name: "Zeta", category: "Casa", order: 2)
        let old = Activity(id: "old", name: "ape", category: "Salute", targetDays: 10, order: 0)
        let recent = Activity(id: "recent", name: "Banana", targetDays: 100, order: 1)
        let archived = Activity(id: "arch", name: "Archiviata", archived: true, order: 3)
        data.activities = [never, old, recent, archived]
        data.entries = [
            LogEntry(activityID: "old", date: today.adding(days: -30)),
            LogEntry(activityID: "recent", date: today.adding(days: -2)),
            LogEntry(activityID: "arch", date: today.adding(days: -1))
        ]
        return data
    }

    func testSortModes() {
        var data = sample()
        func ids() -> [String] { HomeBuilder.items(for: data, today: today).map(\.id) }

        data.settings.sort = .elapsedDesc
        XCTAssertEqual(ids(), ["never", "old", "recent"])
        data.settings.sort = .elapsedAsc
        XCTAssertEqual(ids(), ["recent", "old", "never"])
        data.settings.sort = .due
        XCTAssertEqual(ids(), ["old", "recent", "never"])
        data.settings.sort = .manual
        XCTAssertEqual(ids(), ["old", "recent", "never"])
        data.settings.sort = .name
        XCTAssertEqual(ids(), ["old", "recent", "never"])
    }

    func testArchivedAndSearch() {
        var data = sample()
        XCTAssertFalse(HomeBuilder.items(for: data, today: today).contains { $0.id == "arch" })
        data.settings.showArchived = true
        XCTAssertTrue(HomeBuilder.items(for: data, today: today).contains { $0.id == "arch" })
        XCTAssertEqual(HomeBuilder.items(for: data, query: "SALU", today: today).map(\.id), ["old"])
    }

    func testGroupsAndSummary() {
        let data = sample()
        let items = HomeBuilder.items(for: data, today: today)
        let groups = HomeBuilder.groups(items, byCategory: true)
        XCTAssertEqual(groups.map(\.name), ["Casa", "Salute", "Senza categoria"])
        XCTAssertEqual(HomeBuilder.groups(items, byCategory: false).first?.items.count, 3)

        let summary = HomeBuilder.summary(for: data, items: items, today: today)
        XCTAssertEqual(summary, HomeSummary(totalEntries: 3, lastSevenDays: 2, overdue: 1, soon: 0))

        let counts = HomeBuilder.globalCounts(data)
        XCTAssertNil(counts[today.adding(days: -1)], "archived activities are excluded")
        XCTAssertEqual(counts[today.adding(days: -2)], 1)
    }

    func testCanReorder() {
        var s = AppSettings()
        XCTAssertFalse(HomeBuilder.canReorder(s))
        s.sort = .manual
        XCTAssertTrue(HomeBuilder.canReorder(s))
        s.groupByCategory = true
        XCTAssertFalse(HomeBuilder.canReorder(s))
    }
}
