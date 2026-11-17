import SwiftUI
import LTIDICore

/// Big "N giorni" / "Oggi" / "Mai registrata" text.
struct ElapsedView: View {
    let stats: ActivityStats
    let format: DurationFormat
    var large = false

    var body: some View {
        if let elapsed = stats.elapsed {
            if elapsed == 0 {
                Text("Oggi").font(bigFont)
            } else {
                let d = ElapsedFormatter.format(elapsed, format)
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(d.value).font(bigFont).monospacedDigit()
                    Text(large ? "\(d.unit) fa" : d.unit)
                        .font(large ? .title3 : .body)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("Mai registrata")
                .font(large ? .title2 : .title3)
                .foregroundStyle(.secondary)
        }
    }

    private var bigFont: Font {
        .system(size: large ? 56 : 34, weight: .bold, design: .rounded)
    }
}

struct StatusBadge: View {
    let status: ActivityStatus

    var body: some View {
        switch status {
        case .overdue: badge("in ritardo", .statusOverdue)
        case .soon: badge("a breve", .statusSoon)
        default: EmptyView()
        }
    }

    private func badge(_ text: String, _ color: Color) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(color)
            .background(color.opacity(0.15), in: Capsule())
    }
}

struct StatTile: View {
    let value: String
    let label: String
    var sub: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let sub {
                Text(sub)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
