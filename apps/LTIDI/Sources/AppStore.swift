import Foundation
import Observation
import LTIDICore

struct ToastMessage: Identifiable {
    let id = UUID()
    let text: String
    let undo: (@MainActor () -> Void)?
}

/// App state: wraps `AppData` (LTIDICore) and saves every change as JSON
/// in Application Support, in the same format as the PWA backup.
@MainActor
@Observable
final class AppStore {
    private(set) var data: AppData
    private(set) var toast: ToastMessage?
    /// Incremented on every quick log (drives haptic feedback).
    private(set) var quickLogCount = 0
    /// Refreshed when the app comes to the foreground.
    private(set) var today: DayDate = .today()
    var errorMessage: String?
    /// Set when "Chiedi conferma su Fatto oggi" is on.
    var pendingQuickLog: Activity?

    @ObservationIgnored private let fileStore: JSONFileStore<AppData>
    @ObservationIgnored private var toastTask: Task<Void, Never>?

    init(fileURL: URL = AppStore.defaultFileURL) {
        fileStore = JSONFileStore(url: fileURL)
        let today = DayDate.today()
        do {
            if let saved = try fileStore.load() {
                data = saved
            } else {
                // First launch: sample data, like the PWA.
                data = .demo(today: today)
                try? fileStore.save(data)
            }
        } catch {
            // Never overwrite unreadable data: move it aside and start from the sample.
            let backup = fileURL.deletingPathExtension()
                .appendingPathExtension("corrupt-\(Int(Date().timeIntervalSince1970)).json")
            try? FileManager.default.moveItem(at: fileURL, to: backup)
            data = .demo(today: today)
            errorMessage = "I dati salvati non erano leggibili. Una copia è stata conservata come \(backup.lastPathComponent)."
        }
    }

    nonisolated static var defaultFileURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LTIDI", isDirectory: true)
            .appendingPathComponent("data.json")
    }

    func refreshToday() {
        let now = DayDate.today()
        if now != today { today = now }
    }

    // MARK: - Mutations

    func update(_ change: (inout AppData) -> Void) {
        var copy = data
        change(&copy)
        guard copy != data else { return }
        data = copy
        do {
            try fileStore.save(data)
        } catch {
            errorMessage = "Salvataggio non riuscito: \(error.localizedDescription)"
        }
    }

    func requestQuickLog(_ activity: Activity) {
        if data.settings.confirmQuickLog {
            pendingQuickLog = activity
        } else {
            quickLog(activity)
        }
    }

    func quickLog(_ activity: Activity) {
        refreshToday()
        let day = today
        let again = data.hasEntry(activityID: activity.id, on: day)
        var newID = ""
        update { newID = $0.addEntry(activityID: activity.id, date: day) }
        quickLogCount += 1
        let entryID = newID
        showToast(Messages.quickLogged(activity, again: again)) { [weak self] in
            self?.deleteEntry(id: entryID)
        }
    }

    func saveActivity(_ activity: Activity) { update { $0.saveActivity(activity) } }

    func deleteActivity(id: String) { update { $0.deleteActivity(id: id) } }

    func moveActivity(id: String, by direction: Int) { update { $0.moveActivity(id: id, by: direction) } }

    func addEntry(activityID: String, date: DayDate, note: String) {
        update { _ = $0.addEntry(activityID: activityID, date: date, note: note) }
    }

    func updateEntry(_ entry: LogEntry) { update { $0.updateEntry(entry) } }

    func deleteEntry(id: String) { update { $0.deleteEntry(id: id) } }

    func updateSettings(_ change: (inout AppSettings) -> Void) { update { change(&$0.settings) } }

    func replaceAll(with newData: AppData) { update { $0 = newData } }

    func resetAll(withDemo: Bool) {
        refreshToday()
        let day = today
        update { $0.resetAll(withDemo: withDemo, today: day) }
    }

    // MARK: - Toast

    func showToast(_ text: String, undo: (@MainActor () -> Void)? = nil) {
        let message = ToastMessage(text: text, undo: undo)
        toast = message
        toastTask?.cancel()
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4.5))
            guard !Task.isCancelled else { return }
            self?.dismissToast(id: message.id)
        }
    }

    func dismissToast(id: UUID) {
        if toast?.id == id { toast = nil }
    }

    func performUndo() {
        guard let undo = toast?.undo else { return }
        toastTask?.cancel()
        toast = nil
        undo()
    }
}
