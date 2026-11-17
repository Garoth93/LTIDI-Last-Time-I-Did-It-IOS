import XCTest
@testable import LTIDICore

final class HeatmapGridTests: XCTestCase {
    func testLayoutMondayStart() {
        let end = DayDate(iso: "2026-11-18")! // Wednesday
        let counts = [DayDate(iso: "2026-11-10")!: 2, DayDate(iso: "2026-11-17")!: 1]
        let grid = HeatmapGrid(counts: counts, weeks: 2, weekStart: 1, end: end)

        XCTAssertEqual(grid.columns.count, 2)
        XCTAssertEqual(grid.columns[0].first?.date.iso, "2026-11-09")
        XCTAssertEqual(grid.columns[1].last?.date.iso, "2026-11-22")
        XCTAssertEqual(grid.columns[1].filter(\.isFuture).count, 4)
        XCTAssertEqual(grid.maxCount, 2)
        XCTAssertEqual(grid.level(for: 0), 0)
        XCTAssertEqual(grid.level(for: 1), 2)
        XCTAssertEqual(grid.level(for: 2), 4)
        XCTAssertEqual(grid.mixFraction(for: 2), 1)
        XCTAssertEqual(grid.monthLabels, [HeatmapMonthLabel(column: 0, label: "nov")])
    }

    func testSundayStartAndSingleCountLevel() {
        let end = DayDate(iso: "2026-11-18")!
        let grid = HeatmapGrid(counts: [end: 1], weeks: 3, weekStart: 0, end: end)
        XCTAssertEqual(grid.columns[0].first?.date.iso, "2026-11-01")
        XCTAssertEqual(grid.columns[0].first?.date.weekdayFromSunday, 0)
        XCTAssertEqual(grid.level(for: 1), 4)
        XCTAssertEqual(HeatmapGrid.dayLabels(weekStart: 0), ["", "L", "", "M", "", "V", ""])
    }

    func testMonthLabelsAcrossMonths() {
        let grid = HeatmapGrid(counts: [:], weeks: 10, weekStart: 1, end: DayDate(iso: "2026-11-16")!)
        XCTAssertEqual(grid.monthLabels.map(\.label), ["set", "ott", "nov"])
    }
}
