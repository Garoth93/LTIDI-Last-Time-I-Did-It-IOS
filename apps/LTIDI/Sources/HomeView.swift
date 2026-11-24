import SwiftUI
import LTIDICore

struct HomeView: View {
    @Environment(AppStore.self) private var store
    @State private var query = ""
    @State private var logTarget: LogTarget?
    @State private var showRestore = false
    let onNewActivity: () -> Void

    var body: some View {
        let data = store.data
        let today = store.today
        let items = HomeBuilder.items(for: data, query: query, today: today)
        let groups = HomeBuilder.groups(items, byCategory: data.settings.groupByCategory)
        let canReorder = HomeBuilder.canReorder(data.settings)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if data.settings.showGlobalHeatmap && !data.activities.isEmpty {
                    GlobalPanel(
                        summary: HomeBuilder.summary(for: data, items: items, today: today),
                        grid: HeatmapGrid(
                            counts: HomeBuilder.globalCounts(data),
                            weeks: data.settings.heatmapWeeks,
                            weekStart: data.settings.weekStart,
                            end: today
                        ),
                        baseColor: heatmapBaseColor(data.settings.heatmapPalette, activityHex: data.settings.accent)
                    )
                }

                if data.activities.isEmpty {
                    EmptyHomeView(
                        onNew: onNewActivity,
                        onRestore: { showRestore = true },
                        onDemo: { store.resetAll(withDemo: true) }
                    )
                } else if items.isEmpty {
                    ContentUnavailableView.search(text: query)
                }

                ForEach(groups) { group in
                    if !group.name.isEmpty {
                        Text(group.name)
                            .font(.title3.weight(.semibold))
                            .padding(.top, 6)
                    }
                    ForEach(group.items) { item in
                        let move: ((Int) -> Void)? = canReorder
                            ? { direction in store.moveActivity(id: item.id, by: direction) }
                            : nil
                        ActivityCardView(
                            item: item,
                            settings: data.settings,
                            today: today,
                            onQuickLog: { store.requestQuickLog(item.activity) },
                            onLogWithDate: { logTarget = LogTarget(activityID: item.id, entry: nil, date: today) },
                            onMove: move
                        )
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 80)
        }
        .background(Color.appBackground)
        .navigationTitle("LTIDI")
        .searchable(text: $query, prompt: "Cerca…")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(value: Route.settings) {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Impostazioni")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: onNewActivity) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Nuova attività")
            }
        }
        .sheet(item: $logTarget) { target in
            LogEntrySheet(target: target)
        }
        .sheet(isPresented: $showRestore) {
            CloudRestoreView(firstLaunch: false)
        }
    }
}

private struct GlobalPanel: View {
    let summary: HomeSummary
    let grid: HeatmapGrid
    let baseColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)], alignment: .leading, spacing: 6) {
                count(summary.totalEntries, "registrazioni")
                count(summary.lastSevenDays, "negli ultimi 7 giorni")
                if summary.overdue > 0 { count(summary.overdue, "in ritardo", color: .statusOverdue) }
                if summary.soon > 0 { count(summary.soon, "a breve", color: .statusSoon) }
            }
            ScrollingHeatmap(grid: grid, baseColor: baseColor)
        }
        .cardStyle()
    }

    private func count(_ value: Int, _ label: String, color: Color = .primary) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("\(value)").font(.subheadline.weight(.bold)).foregroundStyle(color)
            Text(label).font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

private struct EmptyHomeView: View {
    let onNew: () -> Void
    let onRestore: () -> Void
    let onDemo: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Quando l'hai fatto l'ultima volta?", systemImage: "calendar.badge.clock")
        } description: {
            Text("Aggiungi le cose che vuoi tenere d'occhio: dentista, parrucchiere, cambio olio, chiamare la nonna…")
        } actions: {
            Button("Aggiungi la prima attività", action: onNew)
                .buttonStyle(.borderedProminent)
            Button("Ripristina da iCloud", action: onRestore)
            Button("Carica dati di esempio", action: onDemo)
        }
        .padding(.top, 40)
    }
}
