import SwiftUI
import LTIDICore

/// "Nuova attività" / "Modifica attività" sheet.
struct ActivityFormView: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let isNew: Bool
    let onDeleted: () -> Void

    @State private var draft: Activity
    @State private var targetText: String
    @State private var confirmDelete = false

    init(activity: Activity, isNew: Bool, onDeleted: @escaping () -> Void) {
        self.isNew = isNew
        self.onDeleted = onDeleted
        _draft = State(initialValue: activity)
        _targetText = State(initialValue: activity.targetDays.map { String($0) } ?? "")
    }

    var body: some View {
        let accent = Color(hex: store.data.settings.accent)
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        TextField("✅", text: $draft.emoji)
                            .font(.largeTitle)
                            .multilineTextAlignment(.center)
                            .frame(width: 64)
                        TextField("Nome (es. Dentista)", text: $draft.name)
                            .font(.title3)
                    }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 6), spacing: 6) {
                        ForEach(Presets.emojis, id: \.self) { emoji in
                            Button {
                                draft.emoji = emoji
                            } label: {
                                Text(emoji)
                                    .font(.title2)
                                    .frame(maxWidth: .infinity, minHeight: 40)
                                    .background(draft.emoji == emoji ? accent.opacity(0.2) : Color.clear,
                                                in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    Text("Icona e nome")
                }

                Section("Colore") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                        ForEach(Palette.colors, id: \.self) { hex in
                            Button {
                                draft.color = hex
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex))
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        if draft.color.lowercased() == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Colore \(hex)")
                        }
                    }
                    ColorPicker("Colore personalizzato", selection: colorBinding, supportsOpacity: false)
                }

                Section {
                    TextField("es. Salute", text: $draft.category)
                    let suggestions = store.data.categories
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(suggestions, id: \.self) { category in
                                    ChipButton(title: category, isSelected: draft.category == category) {
                                        draft.category = category
                                    }
                                }
                            }
                        }
                    }
                } header: {
                    Text("Categoria")
                } footer: {
                    Text("Opzionale, per raggruppare.")
                }

                Section {
                    TextField("es. 180", text: $targetText)
                        .keyboardType(.numberPad)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Presets.targets, id: \.self) { preset in
                                ChipButton(title: preset.label, isSelected: parsedTarget == preset.days) {
                                    targetText = String(preset.days)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Obiettivo: ogni N giorni")
                } footer: {
                    Text("Vuoto = nessun obiettivo. Serve per gli avvisi “a breve” e “in ritardo”.")
                }

                Section("Note") {
                    TextField("es. Dott. Rossi, tel. ...", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                if !isNew {
                    Section {
                        Toggle("Archiviata (nascosta dalla home)", isOn: $draft.archived)
                    }
                    Section {
                        Button("Elimina attività", role: .destructive) {
                            confirmDelete = true
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "Nuova attività" : "Modifica attività")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Salva") { save() }
                        .disabled(trimmedName.isEmpty)
                }
            }
            .alert("Eliminare “\(draft.name)” e tutto il suo storico?", isPresented: $confirmDelete) {
                Button("Elimina", role: .destructive) {
                    store.deleteActivity(id: draft.id)
                    dismiss()
                    onDeleted()
                }
                Button("Annulla", role: .cancel) {}
            }
            .onChange(of: draft.emoji) { _, newValue in
                if newValue.count > 2 { draft.emoji = String(newValue.prefix(2)) }
            }
        }
    }

    private var trimmedName: String {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var parsedTarget: Int? {
        Int(targetText.trimmingCharacters(in: .whitespaces)).map { max(1, $0) }
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { Color(hex: draft.color) },
            set: { newColor in
                if let hex = newColor.hexString { draft.color = hex }
            }
        )
    }

    private func save() {
        var activity = draft
        activity.name = trimmedName
        activity.category = activity.category.trimmingCharacters(in: .whitespacesAndNewlines)
        activity.targetDays = parsedTarget
        if activity.emoji.trimmingCharacters(in: .whitespaces).isEmpty { activity.emoji = "✅" }
        store.saveActivity(activity)
        dismiss()
    }
}
