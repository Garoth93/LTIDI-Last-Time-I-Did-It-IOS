import Foundation
import Observation
import BackgroundTasks
import LTIDICore

enum CloudBackupError: LocalizedError {
    case unavailable
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "iCloud Drive non disponibile: controlla di aver fatto l'accesso a iCloud e che iCloud Drive sia attivo per LTIDI."
        case .unreadable:
            return "Impossibile leggere il backup da iCloud Drive. Riprova tra poco."
        }
    }
}

/// Automatic backups in iCloud Drive, in the shared container
/// `iCloud.com.garoth93.backup` › Documents › LTIDI (visible in Files as
/// iCloud Drive › Backup › LTIDI). One file per day plus "latest"; written
/// a few seconds after the data change, when the app goes to background and
/// from a background refresh task. Restore from Settings, or guided at first
/// launch when the app is empty. Pure logic is in `CloudBackupPlan` (LTIDICore).
@MainActor
@Observable
final class CloudBackupService {
    static let shared = CloudBackupService()
    nonisolated static let refreshTaskID = "com.garoth93.ltidi.refresh"

    /// nil = not checked yet; false = iCloud off, not signed in or no entitlement
    /// (e.g. the Sideloadly build).
    private(set) var available: Bool?
    private(set) var isWorking = false
    private(set) var lastBackupAt: Date?
    private(set) var lastError: String?
    private(set) var entries: [CloudBackupPlan.Entry] = []

    @ObservationIgnored private var scheduled: Task<Void, Never>?

    private enum Keys {
        static let fingerprint = "cloudBackup.fingerprint"
        static let lastAt = "cloudBackup.lastAt"
        static let restoreOffered = "cloudBackup.restoreOffered"
    }

    private init() {
        lastBackupAt = UserDefaults.standard.object(forKey: Keys.lastAt) as? Date
    }

    private var store: AppStore { AppStore.shared }

    var statusText: String {
        if available == false { return "iCloud non disponibile" }
        guard let lastBackupAt else { return "Nessuno" }
        return lastBackupAt.formatted(
            .dateTime.day().month(.abbreviated).year().hour().minute().locale(Locale(identifier: "it_IT"))
        )
    }

    // MARK: - Folder

    /// Resolving the ubiquity container can block: always off the main thread.
    nonisolated static func folderURL() async -> URL? {
        await Task.detached(priority: .utility) { () -> URL? in
            guard let container = FileManager.default.url(forUbiquityContainerIdentifier: CloudBackupPlan.containerID) else {
                return nil
            }
            let folder = container
                .appendingPathComponent("Documents", isDirectory: true)
                .appendingPathComponent(CloudBackupPlan.folderName, isDirectory: true)
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            return folder
        }.value
    }

    func checkAvailability() async {
        available = await Self.folderURL() != nil
    }

    // MARK: - Backup

    /// After a change: back up a few seconds later (many edits, one write).
    func scheduleBackup() {
        scheduled?.cancel()
        scheduled = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled else { return }
            await self?.backup(force: false)
        }
    }

    /// Writes the backup if the content changed since the last one (or `force`).
    /// An empty app never overwrites existing backups.
    @discardableResult
    func backup(force: Bool) async -> Bool {
        let data = store.data
        guard CloudBackupPlan.shouldBackUp(data) else {
            if force { lastError = "L'app è vuota: non c'è niente da salvare." }
            return false
        }
        let fingerprint = CloudBackupPlan.fingerprint(data)
        if !force, fingerprint == UserDefaults.standard.string(forKey: Keys.fingerprint) { return false }
        guard let encoded = try? BackupFile(data: data).encoded() else { return false }

        isWorking = true
        defer { isWorking = false }
        guard let folder = await Self.folderURL() else {
            available = false
            if force { lastError = CloudBackupError.unavailable.errorDescription }
            return false
        }
        available = true
        let day = DayDate.today()
        let failure = await Task.detached(priority: .utility) { () -> String? in
            do {
                try Self.coordinatedWrite(encoded, to: folder.appendingPathComponent(CloudBackupPlan.dailyName(for: day)))
                try Self.coordinatedWrite(encoded, to: folder.appendingPathComponent(CloudBackupPlan.latestName))
                let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
                for name in CloudBackupPlan.namesToPrune(names) {
                    Self.coordinatedDelete(folder.appendingPathComponent(name))
                }
                return nil
            } catch {
                return error.localizedDescription
            }
        }.value

        if let failure {
            lastError = "Backup su iCloud non riuscito: \(failure)"
            return false
        }
        let now = Date()
        lastError = nil
        lastBackupAt = now
        UserDefaults.standard.set(now, forKey: Keys.lastAt)
        UserDefaults.standard.set(fingerprint, forKey: Keys.fingerprint)
        return true
    }

    nonisolated private static func coordinatedWrite(_ data: Data, to url: URL) throws {
        var coordinationError: NSError?
        var writeError: Error?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { target in
            do { try data.write(to: target, options: .atomic) } catch { writeError = error }
        }
        if let error = coordinationError ?? writeError { throw error }
    }

    nonisolated private static func coordinatedDelete(_ url: URL) {
        var coordinationError: NSError?
        NSFileCoordinator(filePresenter: nil).coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { target in
            try? FileManager.default.removeItem(at: target)
        }
    }

    // MARK: - Restore

    /// Backups in the iCloud folder: "latest" first, then newest day.
    func refreshEntries() async {
        guard let folder = await Self.folderURL() else {
            available = false
            entries = []
            return
        }
        available = true
        let names = await Task.detached(priority: .userInitiated) {
            (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        }.value
        entries = CloudBackupPlan.entries(fromFileNames: names)
    }

    /// Downloads (if needed) and decodes a backup.
    func load(_ entry: CloudBackupPlan.Entry) async throws -> BackupFile {
        guard let folder = await Self.folderURL() else { throw CloudBackupError.unavailable }
        let url = folder.appendingPathComponent(entry.name)
        let raw = try await Task.detached(priority: .userInitiated) { () async throws -> Data in
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
            // The coordinated read waits for the download of the iCloud file.
            for _ in 0..<60 {
                var coordinationError: NSError?
                var output: Data?
                NSFileCoordinator(filePresenter: nil).coordinate(readingItemAt: url, options: [], error: &coordinationError) { target in
                    output = try? Data(contentsOf: target)
                }
                if let output { return output }
                try await Task.sleep(for: .milliseconds(500))
            }
            throw CloudBackupError.unreadable
        }.value
        return try BackupFile.decode(raw)
    }

    /// Replaces all the data with the backup.
    func restore(_ file: BackupFile) {
        // The restored content is already in iCloud: no need to write it again.
        UserDefaults.standard.set(CloudBackupPlan.fingerprint(file.data), forKey: Keys.fingerprint)
        store.replaceAll(with: file.data)
        lastError = nil
    }

    // MARK: - First launch

    /// Empty app + backups in iCloud: offer the guided restore (asked once).
    func shouldOfferRestore() async -> Bool {
        guard !CloudBackupPlan.shouldBackUp(store.data),
              !UserDefaults.standard.bool(forKey: Keys.restoreOffered) else { return false }
        await refreshEntries()
        guard !entries.isEmpty, !CloudBackupPlan.shouldBackUp(store.data) else { return false }
        UserDefaults.standard.set(true, forKey: Keys.restoreOffered)
        return true
    }

    // MARK: - Background refresh

    func runBackgroundRefresh() async {
        Self.scheduleBackgroundRefresh()
        await backup(force: false)
    }

    nonisolated static func scheduleBackgroundRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: refreshTaskID)
        request.earliestBeginDate = Date().addingTimeInterval(6 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }
}
