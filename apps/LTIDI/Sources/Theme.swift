import SwiftUI
import UIKit
import LTIDICore

extension Color {
    /// "#rrggbb" → Color (sRGB). Invalid strings use `fallback`.
    init(hex: String, fallback: Color = .green) {
        if let rgb = RGBColor(hex: hex) {
            self.init(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
        } else {
            self = fallback
        }
    }

    /// Light/dark pair taken from the PWA stylesheet.
    static func dynamic(light: String, dark: String) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = RGBColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
                ?? RGBColor(red: 0.5, green: 0.5, blue: 0.5)
            return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        })
    }

    static let statusOK = dynamic(light: "#1a7f37", dark: "#3fb950")
    static let statusSoon = dynamic(light: "#bf8700", dark: "#d29922")
    static let statusOverdue = dynamic(light: "#cf222e", dark: "#f85149")
    static let cellEmpty = dynamic(light: "#ebedf0", dark: "#21262d")

    static let appBackground = Color(uiColor: .systemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let chipFill = Color(uiColor: .tertiarySystemFill)

    /// "#rrggbb" of this color (used by ColorPicker bindings).
    var hexString: String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        return RGBColor(red: Double(r), green: Double(g), blue: Double(b)).hex
    }
}

extension ActivityStatus {
    /// Only "a breve" and "in ritardo" are highlighted.
    var color: Color? {
        switch self {
        case .soon: return .statusSoon
        case .overdue: return .statusOverdue
        default: return nil
        }
    }
}

/// Heatmap base color for the chosen palette.
func heatmapBaseColor(_ palette: HeatmapPalette, activityHex: String) -> Color {
    switch palette {
    case .activity: return Color(hex: activityHex)
    case .github: return Color(hex: Palette.github)
    case .mono: return .primary
    }
}

extension View {
    /// Rounded card on the grouped background (iOS standard look).
    func cardStyle() -> some View {
        padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
