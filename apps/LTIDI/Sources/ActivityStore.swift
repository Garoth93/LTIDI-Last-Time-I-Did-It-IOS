import Foundation
import Combine
import LTIDICore

/// Observable wrapper around `ActivityList` (from the LTIDICore package)
/// that persists every change as JSON in Application Support.
@MainActor
final class ActivityStore: ObservableObject {
    @Published private(set) var list: ActivityList
    @Published private(set) var lastError: String?

    private let fileStore: JSONFileStore<ActivityList>

    init(fileURL: URL = ActivityStore.defaultFileURL) {
        fileStore = JSONFileStore(url: fileURL)
        do {
            list = try fileStore.load() ?? ActivityList()
        } catch {
            list = ActivityList()
            lastError = "Impossibile leggere i dati salvati: \(error.localizedDescription)"
        }
    }

    nonisolated static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("LTIDI", isDirectory: true)
            .appendingPathComponent("activities.json")
    }

    var activities: [Activity] { list.sortedByStaleness() }

    func add(name: String) {
        mutate { $0.add(name: name) }
    }

    func markDone(_ activity: Activity, at date: Date = Date()) {
        mutate { $0.markDone(id: activity.id, at: date) }
    }

    func rename(_ activity: Activity, to name: String) {
        mutate { $0.rename(id: activity.id, to: name) }
    }

    func remove(_ activity: Activity) {
        mutate { $0.remove(id: activity.id) }
    }

    private func mutate(_ change: (inout ActivityList) -> Void) {
        var updated = list
        change(&updated)
        guard updated != list else { return }
        list = updated
        do {
            try fileStore.save(list)
            lastError = nil
        } catch {
            lastError = "Salvataggio non riuscito: \(error.localizedDescription)"
        }
    }
}
