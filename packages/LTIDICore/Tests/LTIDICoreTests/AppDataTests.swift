import XCTest
@testable import LTIDICore

final class AppDataTests: XCTestCase {
    let today = DayDate(iso: "2026-11-16")!

    /// A PWA backup with every kind of irregularity `normalize()` tolerates.
    let pwaBackup = """
    {
      "version": 1,
      "activities": [
        { "id": "a1", "name": "Dentista", "emoji": "🦷", "color": "#0969da", "category": "Salute",
          "targetDays": 180, "notes": "Dott. Rossi", "archived": false, "order": 2.0, "createdAt": "2026-01-01T10:00:00.000Z" },
        { "id": "a2", "name": "Corsa", "targetDays": null },
        null
      ],
      "entries": [
        { "id": "e1", "activityId": "a1", "date": "2026-05-04", "note": "pulizia" },
        { "id": "e2", "activityId": "a1", "date": "2026-5-4", "note": "" },
        { "id": "e3", "date": "2026-05-05" },
        null,
        { "activityId": "a2", "date": "2026-11-15" }
      ],
      "settings": { "theme": "dark", "sort": "unknown", "weekStart": 0, "heatmapWeeks": 40, "showArchived": true }
    }
    """

    func testImportsPWABackupLikeNormalize() throws {
        let data = try AppData.importJSON(Data(pwaBackup.utf8))

        XCTAssertEqual(data.activities.count, 2)
        let dentist = data.activities[0]
        XCTAssertEqual(dentist.order, 2)
        XCTAssertEqual(dentist.targetDays, 180)
        XCTAssertEqual(dentist.notes, "Dott. Rossi")
        let run = data.activities[1]
        XCTAssertEqual(run.emoji, "✅")
        XCTAssertEqual(run.color, Palette.colors[0])
        XCTAssertNil(run.targetDays)
        XCTAssertEqual(run.order, 1)
        XCTAssertFalse(run.archived)

        XCTAssertEqual(data.entries.count, 2)
        XCTAssertEqual(data.entries[0].note, "pulizia")
        XCTAssertEqual(data.entries[1].activityID, "a2")
        XCTAssertFalse(data.entries[1].id.isEmpty)

        XCTAssertEqual(data.settings.theme, .dark)
        XCTAssertEqual(data.settings.sort, .elapsedDesc)
        XCTAssertEqual(data.settings.weekStart, 0)
        XCTAssertEqual(data.settings.heatmapWeeks, 40)
        XCTAssertTrue(data.settings.showArchived)
        XCTAssertEqual(data.settings.dueSoonPercent, 80)
    }

    func testRejectsFilesWithoutArrays() {
        XCTAssertThrowsError(try AppData.importJSON(Data("{\"activities\": []}".utf8))) { error in
            XCTAssertEqual(error as? AppDataError, .invalidFile)
        }
        XCTAssertThrowsError(try AppData.importJSON(Data("[1,2]".utf8)))
        XCTAssertThrowsError(try AppData.importJSON(Data("not json".utf8)))
    }

    func testExportUsesPWAKeysAndRoundTrips() throws {
        var data = AppData.demo(today: today)
        data.activities[0].targetDays = nil
        let json = try data.exportJSON()

        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        let firstActivity = try XCTUnwrap((root["activities"] as? [[String: Any]])?.first)
        XCTAssertTrue(firstActivity["targetDays"] is NSNull)
        let firstEntry = try XCTUnwrap((root["entries"] as? [[String: Any]])?.first)
        XCTAssertNotNil(firstEntry["activityId"] as? String)
        XCTAssertEqual((firstEntry["date"] as? String)?.count, 10)
        XCTAssertEqual((root["settings"] as? [String: Any])?["sort"] as? String, "elapsed-desc")

        XCTAssertEqual(try AppData.importJSON(json), data)
    }

    func testDemoData() {
        let demo = AppData.demo(today: today)
        XCTAssertEqual(demo.activities.map(\.name), ["Dentista", "Parrucchiere", "Cambio lenzuola", "Chiamato i nonni"])
        XCTAssertEqual(demo.entries.count, 11)
        XCTAssertEqual(demo.categories, ["Salute", "Cura personale", "Casa", "Persone"])
    }

    func testActions() {
        var data = AppData.demo(today: today)
        let dentist = data.activities[0]
        let hair = data.activities[1]

        let entryID = data.addEntry(activityID: hair.id, date: today, note: "taglio")
        XCTAssertTrue(data.hasEntry(activityID: hair.id, on: today))
        var entry = data.entries.first { $0.id == entryID }!
        entry.note = "colore"
        data.updateEntry(entry)
        XCTAssertEqual(data.entries.first { $0.id == entryID }?.note, "colore")
        data.deleteEntry(id: entryID)
        XCTAssertFalse(data.hasEntry(activityID: hair.id, on: today))

        data.moveActivity(id: hair.id, by: -1)
        XCTAssertEqual(data.activity(id: hair.id)?.order, 0)
        XCTAssertEqual(data.activity(id: dentist.id)?.order, 1)
        data.moveActivity(id: hair.id, by: -1)
        XCTAssertEqual(data.activity(id: hair.id)?.order, 0, "cannot move above the first")

        var renamed = dentist
        renamed.name = "Dentista Rossi"
        data.saveActivity(renamed)
        XCTAssertEqual(data.activities.count, 4)
        XCTAssertEqual(data.activity(id: dentist.id)?.name, "Dentista Rossi")

        let template = data.newActivityTemplate()
        XCTAssertEqual(template.order, 4)
        XCTAssertEqual(template.color, Palette.colors[4])

        data.deleteActivity(id: dentist.id)
        XCTAssertNil(data.activity(id: dentist.id))
        XCTAssertFalse(data.entries.contains { $0.activityID == dentist.id })

        data.settings.showArchived = true
        data.resetAll(withDemo: false, today: today)
        XCTAssertTrue(data.activities.isEmpty)
        XCTAssertTrue(data.entries.isEmpty)
        XCTAssertTrue(data.settings.showArchived)
    }

    func testCSVExport() {
        let a = Activity(id: "a", name: "Cena \"speciale\"", category: "Persone")
        let data = AppData(activities: [a], entries: [
            LogEntry(activityID: "a", date: DayDate(iso: "2026-05-02")!, note: "con \"Luca\""),
            LogEntry(activityID: "a", date: DayDate(iso: "2026-01-10")!)
        ])
        XCTAssertEqual(data.exportCSV(), #"""
        data,attivita,categoria,nota
        2026-01-10,"Cena ""speciale""","Persone",""
        2026-05-02,"Cena ""speciale""","Persone","con ""Luca"""
        """#)
    }
}
