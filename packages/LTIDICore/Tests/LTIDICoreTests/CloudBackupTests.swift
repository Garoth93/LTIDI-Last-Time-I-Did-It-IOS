import XCTest
@testable import LTIDICore

final class CloudBackupTests: XCTestCase {
    let today = DayDate(iso: "2026-11-24")!

    func testNamesAndEntries() {
        let d1 = CloudBackupPlan.dailyName(for: today)
        let d0 = CloudBackupPlan.dailyName(for: today.adding(days: -1))
        XCTAssertEqual(d1, "LTIDI-backup-2026-11-24.json")
        let names = [d0, "." + d1 + ".icloud", CloudBackupPlan.latestName, "altro.txt",
                     "LTIDI-backup-xx.json", "LTIDI-backup-2026-02-30.json", "Tessere-backup-2026-11-24.json"]
        let entries = CloudBackupPlan.entries(fromFileNames: names)
        XCTAssertEqual(entries.map(\.name), [CloudBackupPlan.latestName, d1, d0])
        XCTAssertTrue(entries[0].isLatest)
        XCTAssertEqual(entries[1].day, today)
        XCTAssertEqual(CloudBackupPlan.realName(".a.json.icloud"), "a.json")
        XCTAssertEqual(CloudBackupPlan.realName("a.json"), "a.json")
    }

    func testPruneKeepsNewestThirtyAndLatest() {
        let names = (0..<35).map { CloudBackupPlan.dailyName(for: today.adding(days: -$0)) } + [CloudBackupPlan.latestName]
        let prune = CloudBackupPlan.namesToPrune(names)
        XCTAssertEqual(prune.count, 5)
        XCTAssertFalse(prune.contains(CloudBackupPlan.latestName))
        XCTAssertTrue(prune.contains(CloudBackupPlan.dailyName(for: today.adding(days: -34))))
        XCTAssertFalse(prune.contains(CloudBackupPlan.dailyName(for: today.adding(days: -29))))
        XCTAssertTrue(CloudBackupPlan.namesToPrune(Array(names.prefix(3))).isEmpty)
    }

    func testFingerprintTracksContent() {
        var data = AppData.demo(today: today)
        let first = CloudBackupPlan.fingerprint(data)
        XCTAssertEqual(first, CloudBackupPlan.fingerprint(data))
        data.addEntry(activityID: data.activities[0].id, date: today)
        XCTAssertNotEqual(first, CloudBackupPlan.fingerprint(data))
        XCTAssertNotEqual(first, CloudBackupPlan.fingerprint(AppData()))
    }

    func testEmptyAppNeverBacksUp() {
        XCTAssertFalse(CloudBackupPlan.shouldBackUp(AppData()))
        XCTAssertTrue(CloudBackupPlan.shouldBackUp(AppData.demo(today: today)))
    }

    func testBackupFileRoundTripAndPWACompatibility() throws {
        let data = AppData.demo(today: today)
        let exportedAt = Date(timeIntervalSince1970: 1_795_000_000)
        let raw = try BackupFile(data: data, exportedAt: exportedAt).encoded()

        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: raw) as? [String: Any])
        XCTAssertEqual(root["app"] as? String, "LTIDI")
        XCTAssertEqual(root["version"] as? Int, 1)
        XCTAssertNotNil(root["exportedAt"] as? String)
        XCTAssertEqual((root["activities"] as? [Any])?.count, 4)
        XCTAssertNil(root["token"])

        let decoded = try BackupFile.decode(raw)
        XCTAssertEqual(decoded.data, data)
        XCTAssertEqual(decoded.exportedAt, exportedAt)
        // The same file goes through the plain import used for PWA backups.
        XCTAssertEqual(try AppData.importJSON(raw), data)
    }

    func testPlainPWABackupDecodesWithoutDate() throws {
        let raw = try AppData.demo(today: today).exportJSON()
        let decoded = try BackupFile.decode(raw)
        XCTAssertNil(decoded.exportedAt)
        XCTAssertEqual(decoded.data.activities.count, 4)
        XCTAssertThrowsError(try BackupFile.decode(Data("{}".utf8)))
    }

    func testParseTimestamps() {
        XCTAssertNotNil(IDGenerator.parseTimestamp("2026-01-01T10:00:00Z"))
        XCTAssertNotNil(IDGenerator.parseTimestamp("2026-01-01T10:00:00.000Z"))
        XCTAssertNil(IDGenerator.parseTimestamp("ieri"))
    }
}
