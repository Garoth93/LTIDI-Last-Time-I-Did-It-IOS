import Foundation

/// Italian date and duration texts, identical to the PWA (`Intl` it-IT).
/// Implemented with fixed tables so output is the same on iOS and Linux.
public enum ItalianFormat {
    public static let monthNames = [
        "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
        "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre"
    ]
    public static let monthShort = ["gen", "feb", "mar", "apr", "mag", "giu", "lug", "ago", "set", "ott", "nov", "dic"]
    /// Sunday first, like JavaScript `getDay()`.
    public static let weekdayNames = ["domenica", "lunedì", "martedì", "mercoledì", "giovedì", "venerdì", "sabato"]
    /// Monday-first one-letter labels used by the weekday chart.
    public static let weekdayInitials = ["L", "M", "M", "G", "V", "S", "D"]
    public static let monthInitials = ["G", "F", "M", "A", "M", "G", "L", "A", "S", "O", "N", "D"]

    /// "16 novembre 2026"
    public static func long(_ d: DayDate) -> String { "\(d.day) \(monthNames[d.month - 1]) \(d.year)" }

    /// "16 nov"
    public static func short(_ d: DayDate) -> String { "\(d.day) \(monthShort[d.month - 1])" }

    /// "lunedì"
    public static func weekday(_ d: DayDate) -> String { weekdayNames[d.weekdayFromSunday] }

    /// "nov 2026"
    public static func monthYear(_ d: DayDate) -> String { "\(monthShort[d.month - 1]) \(d.year)" }

    public static func relative(days: Int) -> String {
        switch days {
        case 0: return "oggi"
        case 1: return "ieri"
        case ..<0: return "tra \(-days) giorni"
        default: return "\(days) giorni fa"
        }
    }

    /// Case- and accent-insensitive comparison, like `localeCompare(…, 'it')`.
    public static func compare(_ a: String, _ b: String) -> ComparisonResult {
        a.compare(b, options: [.caseInsensitive, .diacriticInsensitive], range: nil, locale: Locale(identifier: "it_IT"))
    }
}

public struct DurationText: Equatable, Sendable {
    public let value: String
    public let unit: String

    public init(value: String, unit: String) {
        self.value = value
        self.unit = unit
    }
}

public enum ElapsedFormatter {
    /// "3 giorni", "5 settimane", "4 mesi", "1 anno 2 m".
    public static func smart(_ days: Int) -> DurationText {
        let a = abs(days)
        if a < 14 { return DurationText(value: String(days), unit: a == 1 ? "giorno" : "giorni") }
        if a < 60 {
            let w = a / 7
            return DurationText(value: String(w), unit: w == 1 ? "settimana" : "settimane")
        }
        let months = Int((Double(a) / 30.44).rounded(.down))
        let years = Int((Double(a) / 365.25).rounded(.down))
        // The PWA showed "0 anni 11 m" for exactly 365 days: treat it as months.
        if a < 365 || years == 0 {
            return DurationText(value: String(months), unit: months == 1 ? "mese" : "mesi")
        }
        let rest = Int(((Double(a) - Double(years) * 365.25) / 30.44).rounded(.down))
        return DurationText(value: String(years), unit: (years == 1 ? "anno" : "anni") + (rest != 0 ? " \(rest) m" : ""))
    }

    public static func plain(_ days: Int) -> DurationText {
        DurationText(value: String(days), unit: abs(days) == 1 ? "giorno" : "giorni")
    }

    public static func format(_ days: Int, _ mode: DurationFormat) -> DurationText {
        mode == .smart ? smart(days) : plain(days)
    }
}
