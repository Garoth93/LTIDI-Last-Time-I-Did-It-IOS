import SwiftUI
import UniformTypeIdentifiers
import LTIDICore

struct SettingsView: View {
    @Environment(AppStore.self) private var store
    @State private var exportDocument: TextFileDocument?
    @State private var exportType: UTType = .json
    @State private var exportName = ""
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var pendingImport: AppData?
    @State private var confirmReset = false
    @State private var confirmDemo = false

    var body: some View {
        let settings = store.data.settings
        Form {
            Section("Aspetto") {
                Picker("Tema", selection: binding(\.theme)) {
                    ForEach(ThemeMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                ColorPicker("Colore principale", selection: accentBinding, supportsOpacity: false)
                Picker("Colori della griglia", selection: binding(\.heatmapPalette)) {
                    ForEach(HeatmapPalette.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("Tempo trascorso", selection: binding(\.durationFormat)) {
                    ForEach(DurationFormat.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                Picker("La settimana inizia di", selection: binding(\.weekStart)) {
                    Text("Lunedì").tag(1)
                    Text("Domenica").tag(0)
                }
            }

            Section("Home") {
                Picker("Ordinamento", selection: binding(\.sort)) {
                    ForEach(SortMode.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                VStack(alignment: .leading) {
                    Text("Settimane nella griglia generale: \(settings.heatmapWeeks)")
                    Slider(value: sliderBinding(\.heatmapWeeks), in: 8...53, step: 1)
                }
                VStack(alignment: .leading) {
                    Text("Avviso “a breve” al \(settings.dueSoonPercent)% dell'obiettivo")
                    Slider(value: sliderBinding(\.dueSoonPercent), in: 50...99, step: 1)
                }
                Toggle("Mostra griglia generale", isOn: binding(\.showGlobalHeatmap))
                Toggle("Mostra mini-griglia nelle schede", isOn: binding(\.showMiniHeatmap))
                Toggle("Raggruppa per categoria", isOn: binding(\.groupByCategory))
                Toggle("Mostra attività archiviate", isOn: binding(\.showArchived))
                Toggle("Chiedi conferma su “Fatto oggi”", isOn: binding(\.confirmQuickLog))
            }

            Section {
                Button {
                    startExport(json: true)
                } label: {
                    Label("Backup JSON", systemImage: "externaldrive")
                }
                Button {
                    startExport(json: false)
                } label: {
                    Label("Esporta CSV", systemImage: "tablecells")
                }
                Button {
                    isImporting = true
                } label: {
                    Label("Importa JSON (anche dalla PWA)", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Dati")
            } footer: {
                Text("I dati restano solo su questo iPhone. Esporta un backup ogni tanto: se elimini l'app i dati vanno persi. \(store.data.activities.count) attività · \(store.data.entries.count) registrazioni.")
            }

            Section {
                Button("Carica dati di esempio") { confirmDemo = true }
                Button("Cancella tutto", role: .destructive) { confirmReset = true }
            }
        }
        .navigationTitle("Impostazioni")
        .fileExporter(
            isPresented: $isExporting,
            document: exportDocument,
            contentType: exportType,
            defaultFilename: exportName
        ) { result in
            switch result {
            case .success:
                store.showToast("File esportato ✓")
            case .failure(let error):
                store.errorMessage = "Esportazione non riuscita: \(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json, .plainText]) { result in
            handleImport(result)
        }
        .alert(
            "Sostituire tutti i dati attuali con quelli del file?",
            isPresented: Binding(get: { pendingImport != nil }, set: { if !$0 { pendingImport = nil } }),
            presenting: pendingImport
        ) { newData in
            Button("Sostituisci", role: .destructive) {
                store.replaceAll(with: newData)
                store.showToast("Dati importati ✓")
            }
            Button("Annulla", role: .cancel) {}
        } message: { newData in
            Text("Il file contiene \(newData.activities.count) attività e \(newData.entries.count) registrazioni.")
        }
        .confirmationDialog("Cancellare TUTTE le attività e lo storico?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Cancella tutto", role: .destructive) { store.resetAll(withDemo: false) }
        }
        .confirmationDialog("Sostituire tutto con i dati di esempio?", isPresented: $confirmDemo, titleVisibility: .visible) {
            Button("Carica esempio", role: .destructive) { store.resetAll(withDemo: true) }
        }
    }

    // MARK: - Bindings

    private func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { store.data.settings[keyPath: keyPath] },
            set: { newValue in store.updateSettings { $0[keyPath: keyPath] = newValue } }
        )
    }

    private func sliderBinding(_ keyPath: WritableKeyPath<AppSettings, Int>) -> Binding<Double> {
        Binding(
            get: { Double(store.data.settings[keyPath: keyPath]) },
            set: { newValue in store.updateSettings { $0[keyPath: keyPath] = Int(newValue.rounded()) } }
        )
    }

    private var accentBinding: Binding<Color> {
        Binding(
            get: { Color(hex: store.data.settings.accent) },
            set: { newColor in
                if let hex = newColor.hexString { store.updateSettings { $0.accent = hex } }
            }
        )
    }

    // MARK: - Import / export

    private func startExport(json: Bool) {
        let stamp = DayDate.today().iso
        do {
            if json {
                exportDocument = TextFileDocument(data: try store.data.exportJSON())
                exportType = .json
                exportName = "ltidi-backup-\(stamp)"
            } else {
                exportDocument = TextFileDocument(data: Data(store.data.exportCSV().utf8))
                exportType = .commaSeparatedText
                exportName = "ltidi-\(stamp)"
            }
            isExporting = true
        } catch {
            store.errorMessage = "Esportazione non riuscita: \(error.localizedDescription)"
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                pendingImport = try AppData.importJSON(Data(contentsOf: url))
            } catch {
                store.errorMessage = "Impossibile importare: \(error.localizedDescription)"
            }
        case .failure(let error):
            store.errorMessage = "Impossibile importare: \(error.localizedDescription)"
        }
    }
}
