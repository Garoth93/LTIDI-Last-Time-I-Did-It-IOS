import XCTest
@testable import LTIDICore

final class FormatTests: XCTestCase {
    func testItalianDates() {
        let d = DayDate(iso: "2026-11-16")!
        XCTAssertEqual(ItalianFormat.long(d), "16 novembre 2026")
        XCTAssertEqual(ItalianFormat.short(d), "16 nov")
        XCTAssertEqual(ItalianFormat.weekday(d), "lunedì")
        XCTAssertEqual(ItalianFormat.monthYear(d), "nov 2026")
        XCTAssertEqual(ItalianFormat.relative(days: 0), "oggi")
        XCTAssertEqual(ItalianFormat.relative(days: 1), "ieri")
        XCTAssertEqual(ItalianFormat.relative(days: 5), "5 giorni fa")
    }

    func testSmartDuration() {
        XCTAssertEqual(ElapsedFormatter.smart(0), DurationText(value: "0", unit: "giorni"))
        XCTAssertEqual(ElapsedFormatter.smart(1), DurationText(value: "1", unit: "giorno"))
        XCTAssertEqual(ElapsedFormatter.smart(13), DurationText(value: "13", unit: "giorni"))
        XCTAssertEqual(ElapsedFormatter.smart(14), DurationText(value: "2", unit: "settimane"))
        XCTAssertEqual(ElapsedFormatter.smart(59), DurationText(value: "8", unit: "settimane"))
        XCTAssertEqual(ElapsedFormatter.smart(60), DurationText(value: "1", unit: "mese"))
        XCTAssertEqual(ElapsedFormatter.smart(364), DurationText(value: "11", unit: "mesi"))
        XCTAssertEqual(ElapsedFormatter.smart(365), DurationText(value: "11", unit: "mesi"))
        XCTAssertEqual(ElapsedFormatter.smart(400), DurationText(value: "1", unit: "anno 1 m"))
        XCTAssertEqual(ElapsedFormatter.smart(731), DurationText(value: "2", unit: "anni"))
    }

    func testPlainDuration() {
        XCTAssertEqual(ElapsedFormatter.plain(1), DurationText(value: "1", unit: "giorno"))
        XCTAssertEqual(ElapsedFormatter.plain(45), DurationText(value: "45", unit: "giorni"))
        XCTAssertEqual(ElapsedFormatter.format(45, .smart).unit, "settimane")
    }

    func testItalianCompareIgnoresCaseAndAccents() {
        let names = ["banana", "Èlite", "Ape"].sorted { ItalianFormat.compare($0, $1) == .orderedAscending }
        XCTAssertEqual(names, ["Ape", "banana", "Èlite"])
    }

    func testHexColors() {
        XCTAssertEqual(RGBColor(hex: "#2da44e")?.hex, "#2da44e")
        XCTAssertEqual(RGBColor(hex: "FFF")?.hex, "#ffffff")
        XCTAssertNil(RGBColor(hex: "#12345"))
        XCTAssertNil(RGBColor(hex: "#zzzzzz"))
        XCTAssertEqual(RGBColor(red: 1, green: 0.5, blue: 0).hex, "#ff8000")
    }

    func testMessages() {
        let a = Activity(name: "Dentista", emoji: "🦷")
        XCTAssertEqual(Messages.quickLogged(a, again: false), "🦷 Dentista: registrato oggi")
        XCTAssertEqual(Messages.quickLogged(a, again: true), "🦷 Dentista: registrato oggi (di nuovo)")
        XCTAssertEqual(Messages.due(3), "prossima tra 3 g")
        XCTAssertEqual(Messages.due(-2), "scaduta da 2 g")
        XCTAssertEqual(Messages.targetPill(target: 10, nextDue: -2), "Obiettivo ogni 10 g · in ritardo di 2 g")
    }
}
