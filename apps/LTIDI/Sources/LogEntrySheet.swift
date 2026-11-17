import SwiftUI
import LTIDICore

/// Register an activity on any past date, or edit / delete a registration.
struct LogEntrySheet: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let target: LogTarget
    @State private var date: Date
    @State private var note: String

    init(target: LogTarget) {
        self.target = target
        _date = State(initialValue: target.date.date())
        _note = State(initialValue: target.entry?.note ?? "")
    }

    var body: some View {
        let activity = store.data.activity(id: target.activityID)
        let today = store.today
        let selected = DayDate(date: date)
        NavigationStack {
            Form {
                Section("Quando?") {
                    DatePicker("Data", selection: $date, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.graphical)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Presets.logOffsets, id: \.self) { preset in
                                let day = today.adding(days: -preset.days)
                                ChipButton(title: preset.label, isSelected: selected == day) {
                                    date = day.date()
                                }
                            }
                        }
                    }
                }
                Section("Nota (opzionale)") {
                    TextField("es. pulizia + controllo", text: $note)
                }
                if let entry = target.entry {
                    Section {
                        Button("Elimina registrazione", role: .destructive) {
                            store.deleteEntry(id: entry.id)
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(activity.map { "\($0.emoji) \($0.name)" } ?? "Registrazione")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annulla") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(target.entry == nil ? "Registra" : "Salva") {
                        save()
                        dismiss()
                    }
                    .disabled(activity == nil)
                }
            }
        }
    }

    private func save() {
        let day = min(DayDate(date: date), store.today)
        if var entry = target.entry {
            entry.date = day
            entry.note = note
            store.updateEntry(entry)
        } else {
            store.addEntry(activityID: target.activityID, date: day, note: note)
        }
    }
}
