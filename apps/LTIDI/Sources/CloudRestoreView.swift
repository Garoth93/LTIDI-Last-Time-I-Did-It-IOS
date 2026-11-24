import SwiftUI
import LTIDICore

/// Restore from iCloud Drive: from Settings / empty home, or guided at first launch.
struct CloudRestoreView: View {
    let firstLaunch: Bool
    @Environment(CloudBackupService.self) private var cloud
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var choice: CloudBackupPlan.Entry?
    @State private var preview: BackupFile?
    @State private var loading = false
    @State private var loadError: String?
    @State private var confirmReplace = false

    var body: some View {
        NavigationStack {
            List {
                if firstLaunch {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "icloud.and.arrow.down.fill")
                                .font(.system(size: 40))
                                .foregroundStyle(.tint)
                            Text("Bentornato!")
                                .font(.title2.weight(.bold))
                            Text("In iCloud Drive c'è un backup di LTIDI. Vuoi ripristinare le tue attività?")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    }
                }

                Section {
                    if cloud.entries.isEmpty {
                        Text(cloud.available == false ? CloudBackupError.unavailable.errorDescription ?? "" : "Nessun backup trovato.")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(cloud.entries) { entry in
                        Button {
                            select(entry)
                        } label: {
                            HStack {
                                Image(systemName: entry.isLatest ? "clock.arrow.circlepath" : "doc.text")
                                    .foregroundStyle(.tint)
                                Text(title(entry))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if choice == entry {
                                    if loading {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "checkmark").foregroundStyle(.tint)
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("iCloud Drive › Backup › LTIDI")
                } footer: {
                    Text("Il ripristino sostituisce tutte le attività, le registrazioni e le impostazioni attuali con quelle del backup.")
                }

                if let preview, choice != nil {
                    Section {
                        LabeledContent("Attività", value: "\(preview.data.activities.count)")
                        LabeledContent("Registrazioni", value: "\(preview.data.entries.count)")
                        if let exportedAt = preview.exportedAt {
                            LabeledContent("Salvato il", value: exportedAt.formatted(
                                .dateTime.day().month(.wide).year().hour().minute().locale(Locale(identifier: "it_IT"))
                            ))
                        }
                        Button {
                            if CloudBackupPlan.shouldBackUp(store.data) {
                                confirmReplace = true
                            } else {
                                apply(preview)
                            }
                        } label: {
                            Label("Ripristina questo backup", systemImage: "arrow.counterclockwise")
                                .font(.headline)
                        }
                    }
                }

                if let message = loadError ?? cloud.lastError {
                    Section {
                        Text(message).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Ripristina da iCloud")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(firstLaunch ? "Inizia da zero" : "Chiudi") { dismiss() }
                }
            }
            .alert("Sostituire tutti i dati attuali con quelli del backup?", isPresented: $confirmReplace) {
                Button("Sostituisci", role: .destructive) {
                    if let preview { apply(preview) }
                }
                Button("Annulla", role: .cancel) {}
            }
            .task {
                await cloud.refreshEntries()
                if choice == nil, let first = cloud.entries.first {
                    select(first)
                }
            }
        }
    }

    private func title(_ entry: CloudBackupPlan.Entry) -> String {
        entry.day.map { ItalianFormat.long($0) } ?? "Ultimo backup"
    }

    private func select(_ entry: CloudBackupPlan.Entry) {
        choice = entry
        preview = nil
        loadError = nil
        loading = true
        Task {
            do {
                preview = try await cloud.load(entry)
            } catch {
                loadError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            loading = false
        }
    }

    private func apply(_ file: BackupFile) {
        cloud.restore(file)
        store.showToast("Backup ripristinato ✓")
        dismiss()
    }
}
