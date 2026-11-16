import SwiftUI
import LTIDICore

struct ContentView: View {
    @Environment(ActivityStore.self) private var store
    @State private var isAdding = false
    @State private var newName = ""

    var body: some View {
        NavigationStack {
            Group {
                if store.activities.isEmpty {
                    emptyState
                } else {
                    activityList
                }
            }
            .navigationTitle("Last Time I Did It")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        newName = ""
                        isAdding = true
                    } label: {
                        Label("Aggiungi", systemImage: "plus")
                    }
                }
            }
            .alert("Nuova attività", isPresented: $isAdding) {
                TextField("Nome", text: $newName)
                Button("Annulla", role: .cancel) {}
                Button("Aggiungi") { store.add(name: newName) }
            } message: {
                Text("Cosa vuoi tenere d'occhio?")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Nessuna attività")
                .font(.title2.weight(.semibold))
            Text("Tocca + per aggiungere la prima.")
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private var activityList: some View {
        List {
            ForEach(store.activities) { activity in
                ActivityRow(activity: activity) {
                    store.markDone(activity)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        store.remove(activity)
                    } label: {
                        Label("Elimina", systemImage: "trash")
                    }
                }
            }
            if let error = store.lastError {
                Section {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct ActivityRow: View {
    let activity: Activity
    let onDone: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(activity.name)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onDone) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Fatto adesso")
        }
        .padding(.vertical, 4)
    }

    private var subtitle: String {
        guard let days = activity.daysSince() else { return "Mai fatto" }
        switch days {
        case 0: return "Fatto oggi"
        case 1: return "Fatto ieri"
        default: return "\(days) giorni fa"
        }
    }
}

#Preview {
    ContentView()
        .environment(ActivityStore(
            fileURL: FileManager.default.temporaryDirectory.appendingPathComponent("preview.json")
        ))
}
