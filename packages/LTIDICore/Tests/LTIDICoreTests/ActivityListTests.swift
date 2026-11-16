import XCTest
@testable import LTIDICore

final class ActivityListTests: XCTestCase {
    func testAddTrimsAndRejectsEmptyNames() {
        var list = ActivityList()
        XCTAssertNil(list.add(name: "   "))
        XCTAssertTrue(list.activities.isEmpty)

        let added = list.add(name: "  Bike  ")
        XCTAssertEqual(added?.name, "Bike")
        XCTAssertEqual(list.activities.count, 1)
        XCTAssertNil(list.activities[0].lastDone)
    }

    func testMarkDoneUpdatesOnlyTarget() {
        var list = ActivityList()
        let a = list.add(name: "A")!
        let b = list.add(name: "B")!
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        list.markDone(id: a.id, at: now)
        list.markDone(id: UUID(), at: now) // unknown id: ignored

        XCTAssertEqual(list.activities.first { $0.id == a.id }?.lastDone, now)
        XCTAssertNil(list.activities.first { $0.id == b.id }?.lastDone)
    }

    func testRenameAndRemove() {
        var list = ActivityList()
        let a = list.add(name: "A")!
        list.rename(id: a.id, to: "  ")
        XCTAssertEqual(list.activities[0].name, "A")
        list.rename(id: a.id, to: " Alpha ")
        XCTAssertEqual(list.activities[0].name, "Alpha")

        list.remove(id: a.id)
        XCTAssertTrue(list.activities.isEmpty)
    }

    func testSortedByStalenessPutsNeverDoneFirstThenOldest() {
        var list = ActivityList()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let recent = list.add(name: "recent", lastDone: base)!
        let never = list.add(name: "never")!
        let old = list.add(name: "old", lastDone: base.addingTimeInterval(-86_400 * 30))!

        let sorted = list.sortedByStaleness().map(\.id)
        XCTAssertEqual(sorted, [never.id, old.id, recent.id])
    }

    func testListCodableRoundTrip() throws {
        var list = ActivityList()
        list.add(name: "Run", lastDone: Date(timeIntervalSince1970: 1_700_000_000))
        list.add(name: "Ski")

        let data = try JSONFileStore<ActivityList>.encoder.encode(list)
        let decoded = try JSONFileStore<ActivityList>.decoder.decode(ActivityList.self, from: data)
        XCTAssertEqual(decoded, list)
    }
}
