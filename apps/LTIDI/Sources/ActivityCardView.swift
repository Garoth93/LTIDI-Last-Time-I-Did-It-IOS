import SwiftUI
import LTIDICore

/// Home card: tap the top area to open the detail, buttons below to log.
struct ActivityCardView: View {
    let item: HomeItem
    let settings: AppSettings
    let today: DayDate
    let onQuickLog: () -> Void
    let onLogWithDate: () -> Void
    let onMove: ((Int) -> Void)?

    private var activity: Activity { item.activity }
    private var stats: ActivityStats { item.stats }
    private var color: Color { Color(hex: activity.color) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: Route.activity(activity.id)) {
                mainContent
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Button(action: onQuickLog) {
                    Label("Fatto oggi", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(color)

                Button(action: onLogWithDate) {
                    Image(systemName: "calendar")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Registra con data")

                if let onMove {
                    Button { onMove(-1) } label: { Image(systemName: "arrow.up") }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Sposta su")
                    Button { onMove(1) } label: { Image(systemName: "arrow.down") }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Sposta giù")
                }
            }
        }
        .cardStyle()
        .overlay {
            if let statusColor = stats.status.color {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(statusColor.opacity(0.55), lineWidth: 1.5)
            }
        }
        .opacity(activity.archived ? 0.6 : 1)
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                Text(activity.emoji).font(.title)
                VStack(alignment: .leading, spacing: 2) {
                    Text(activity.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if !activity.category.isEmpty {
                        Text(activity.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
                StatusBadge(status: stats.status)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }

            ElapsedView(stats: stats, format: settings.durationFormat)

            Text(metaText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let progress = stats.progress {
                ProgressView(value: min(1, progress))
                    .tint(stats.status.color ?? color)
            }

            if settings.showMiniHeatmap {
                HeatmapView(
                    grid: HeatmapGrid(
                        counts: ActivityStats.countByDate(stats.dates),
                        weeks: 17,
                        weekStart: settings.weekStart,
                        end: today
                    ),
                    baseColor: heatmapBaseColor(settings.heatmapPalette, activityHex: activity.color),
                    cell: 8,
                    gap: 2,
                    showLabels: false
                )
                .padding(.top, 4)
            }
        }
        .contentShape(Rectangle())
    }

    private var metaText: AttributedString {
        var text = AttributedString(stats.last.map { "ultima volta \(ItalianFormat.long($0))" } ?? "tocca “Fatto oggi” per iniziare")
        if let nextDue = stats.nextDue {
            var due = AttributedString(" · " + Messages.due(nextDue))
            if let statusColor = stats.status.color { due.foregroundColor = statusColor }
            text += due
        }
        return text
    }
}
