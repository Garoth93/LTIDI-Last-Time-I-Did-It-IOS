import SwiftUI
import LTIDICore

struct ActivityDetailView: View {
    @Environment(AppStore.self) private var store
    let activityID: String
    let onEdit: () -> Void
    @State private var logTarget: LogTarget?
    /// `nil` = last 12 months.
    @State private var year: Int?

    var body: some View {
        Group {
            if let activity = store.data.activity(id: activityID) {
                content(activity)
            } else {
                ContentUnavailableView("Attività non trovata", systemImage: "questionmark.circle")
            }
        }
        .background(Color.appBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Modifica", action: onEdit)
            }
        }
        .sheet(item: $logTarget) { target in
            LogEntrySheet(target: target)
        }
    }

    private func content(_ activity: Activity) -> some View {
        let data = store.data
        let today = store.today
        let settings = data.settings
        let stats = ActivityStats.compute(activity: activity, entries: data.entries, settings: settings, today: today)
        let color = Color(hex: activity.color)

        return ScrollView {
            VStack(spacing: 16) {
                hero(activity, stats: stats, color: color, settings: settings, today: today)
                heatmapPanel(activity, stats: stats, settings: settings, today: today)
                statsGrid(stats)
                Panel("Giorni tra una volta e l'altra") {
                    IntervalChart(values: stats.intervals, color: color, target: activity.targetDays)
                }
                Panel("Per giorno della settimana") {
                    BarsChart(values: stats.byWeekday, labels: ItalianFormat.weekdayInitials, color: color)
                }
                Panel("Per mese") {
                    BarsChart(values: stats.byMonth, labels: ItalianFormat.monthInitials, color: color)
                }
                if stats.byYear.count > 1 {
                    Panel("Per anno") {
                        BarsChart(values: stats.byYear.map(\.count), labels: stats.byYear.map { String($0.year) }, color: color)
                    }
                }
                historyPanel(activity, rows: ActivityStats.history(activityID: activity.id, entries: data.entries), color: color)
            }
            .padding()
        }
        .navigationTitle(activity.name)
    }

    // MARK: - Sections

    private func hero(_ a: Activity, stats: ActivityStats, color: Color, settings: AppSettings, today: DayDate) -> some View {
        VStack(spacing: 8) {
            Text(a.emoji).font(.system(size: 56))
            Text(a.name)
                .font(.title.weight(.bold))
                .multilineTextAlignment(.center)
            if !a.category.isEmpty {
                Text(a.category).font(.subheadline).foregroundStyle(.secondary)
            }
            ElapsedView(stats: stats, format: settings.durationFormat, large: true)
            if let last = stats.last, let elapsed = stats.elapsed {
                Text("\(ItalianFormat.weekday(last)) \(ItalianFormat.long(last)) · \(elapsed) giorni")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let nextDue = stats.nextDue, let target = a.targetDays {
                let pillColor = stats.status.color ?? Color.statusOK
                Text(Messages.targetPill(target: target, nextDue: nextDue))
                    .font(.footnote.weight(.medium))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .foregroundStyle(pillColor)
                    .background(pillColor.opacity(0.15), in: Capsule())
            }
            if let progress = stats.progress {
                ProgressView(value: min(1, progress))
                    .tint(stats.status.color ?? color)
                    .padding(.vertical, 4)
            }
            HStack(spacing: 10) {
                Button {
                    store.requestQuickLog(a)
                } label: {
                    Label("Fatto oggi", systemImage: "checkmark").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(color)

                Button {
                    logTarget = LogTarget(activityID: a.id, entry: nil, date: today)
                } label: {
                    Label("Altra data", systemImage: "calendar").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .controlSize(.large)
            .padding(.top, 4)
            if !a.notes.isEmpty {
                Text(a.notes)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .cardStyle()
    }

    private func heatmapPanel(_ a: Activity, stats: ActivityStats, settings: AppSettings, today: DayDate) -> some View {
        let years = Array(Set([today.year] + stats.byYear.map(\.year))).sorted(by: >)
        let end = year.flatMap { DayDate(year: $0, month: 12, day: 31) } ?? today
        return Panel {
            HStack {
                Text("Attività").font(.headline)
                Spacer()
                Picker("Periodo", selection: $year) {
                    Text("Ultimi 12 mesi").tag(Int?.none)
                    ForEach(years, id: \.self) { y in
                        Text(String(y)).tag(Int?.some(y))
                    }
                }
                .pickerStyle(.menu)
            }
            ScrollingHeatmap(
                grid: HeatmapGrid(counts: ActivityStats.countByDate(stats.dates), weeks: 53, weekStart: settings.weekStart, end: end),
                baseColor: heatmapBaseColor(settings.heatmapPalette, activityHex: a.color),
                cell: 12,
                onSelect: { day in logTarget = LogTarget(activityID: a.id, entry: nil, date: day) }
            )
            Text("Tocca un giorno per registrare in quella data.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statsGrid(_ s: ActivityStats) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            StatTile(value: "\(s.count)", label: "volte in totale")
            StatTile(value: rounded(s.average), label: "intervallo medio", sub: "giorni")
            StatTile(value: rounded(s.median), label: "mediana", sub: "giorni")
            StatTile(value: s.minInterval.map { String($0) } ?? "—", label: "intervallo min", sub: "giorni")
            StatTile(value: s.maxInterval.map { String($0) } ?? "—", label: "intervallo max", sub: "giorni")
            StatTile(value: perYearText(s.perYear), label: "all'anno (stima)")
            StatTile(value: s.first.map { ItalianFormat.monthYear($0) } ?? "—", label: "prima volta")
            StatTile(
                value: s.pauseVsAverage.map { ($0 >= 0 ? "+" : "") + String($0) } ?? "—",
                label: "pausa attuale vs media",
                sub: s.isLongestPause ? "🔥 la pausa più lunga di sempre" : "giorni"
            )
        }
    }

    private func historyPanel(_ a: Activity, rows: [HistoryRow], color: Color) -> some View {
        Panel {
            HStack(spacing: 6) {
                Text("Storico").font(.headline)
                Text("(\(rows.count))").foregroundStyle(.secondary)
            }
            if rows.isEmpty {
                Text("Nessuna registrazione.").foregroundStyle(.secondary)
            }
            ForEach(rows) { row in
                Button {
                    logTarget = LogTarget(activityID: a.id, entry: row.entry, date: row.entry.date)
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(color).frame(width: 8, height: 8)
                        Text(ItalianFormat.long(row.entry.date))
                        Text(row.entry.note)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(row.gap.map { "+\($0) g" } ?? "prima")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if row.id != rows.last?.id {
                    Divider()
                }
            }
        }
    }

    // MARK: - Formatting

    private func rounded(_ value: Double?) -> String {
        value.map { String(Int($0.rounded())) } ?? "—"
    }

    private func perYearText(_ value: Double?) -> String {
        guard let value else { return "—" }
        let digits = value < 10 ? 1 : 0
        return value.formatted(.number.precision(.fractionLength(digits)).locale(Locale(identifier: "it_IT")))
    }
}
