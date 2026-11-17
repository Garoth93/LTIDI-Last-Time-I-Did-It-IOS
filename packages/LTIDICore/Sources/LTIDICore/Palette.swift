import Foundation

public struct RGBColor: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(red: Double, green: Double, blue: Double) {
        self.red = min(1, max(0, red))
        self.green = min(1, max(0, green))
        self.blue = min(1, max(0, blue))
    }

    /// "#rrggbb" or "#rgb" (with or without "#").
    public init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, s.allSatisfy({ $0.isHexDigit }), let v = UInt32(s, radix: 16) else { return nil }
        self.init(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }

    /// Lowercase "#rrggbb".
    public var hex: String {
        "#" + [red, green, blue].map { component in
            let s = String(Int((component * 255).rounded()), radix: 16)
            return s.count == 1 ? "0" + s : s
        }.joined()
    }
}

public enum Palette {
    /// The PWA's activity color palette.
    public static let colors = [
        "#2da44e", "#0969da", "#8250df", "#bf3989", "#cf222e",
        "#bc4c00", "#d4a72c", "#1b7c83", "#57606a", "#6639ba"
    ]
    public static let github = "#2da44e"
    public static let defaultAccent = "#2da44e"
}

public struct DayPreset: Hashable, Sendable {
    public let days: Int
    public let label: String

    public init(_ days: Int, _ label: String) {
        self.days = days
        self.label = label
    }
}

public enum Presets {
    public static let emojis = [
        "🦷", "💇", "🩺", "💉", "👓", "🚗", "🛞", "🛏️", "🧹", "🪴", "📞", "👵", "🏃", "🚴", "⛷️",
        "🏋️", "📚", "🎸", "🍳", "🧺", "💊", "🐶", "✂️", "💰", "🧾", "🔋", "🧊", "🌊", "✈️", "❤️"
    ]
    /// Target chips in the activity form.
    public static let targets = [
        DayPreset(7, "1 sett"), DayPreset(14, "2 sett"), DayPreset(30, "1 mese"),
        DayPreset(90, "3 mesi"), DayPreset(180, "6 mesi"), DayPreset(365, "1 anno")
    ]
    /// "How many days ago" chips in the log dialog.
    public static let logOffsets = [
        DayPreset(0, "Oggi"), DayPreset(1, "Ieri"), DayPreset(2, "L'altro ieri"), DayPreset(7, "1 sett fa")
    ]
}

public enum Messages {
    public static func quickLogged(_ activity: Activity, again: Bool) -> String {
        "\(activity.emoji) \(activity.name): registrato oggi" + (again ? " (di nuovo)" : "")
    }

    /// Card meta suffix: "prossima tra 5 g" / "scaduta da 3 g".
    public static func due(_ nextDue: Int) -> String {
        nextDue >= 0 ? "prossima tra \(nextDue) g" : "scaduta da \(-nextDue) g"
    }

    /// Detail pill text.
    public static func targetPill(target: Int, nextDue: Int) -> String {
        nextDue >= 0
            ? "Obiettivo ogni \(target) g · mancano \(nextDue) g"
            : "Obiettivo ogni \(target) g · in ritardo di \(-nextDue) g"
    }
}
