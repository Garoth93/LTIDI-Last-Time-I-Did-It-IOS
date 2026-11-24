import Foundation

/// A backup file: the PWA backup format (`AppData`, with its `version`)
/// plus `app` and `exportedAt`. Unknown keys are ignored on import, so the
/// same file can be imported by the app, by Settings › Importa JSON and by
/// the PWA. Contains only activities, entries and settings: no tokens,
/// no device or account data.
public struct BackupFile: Equatable, Sendable {
    public static let appName = "LTIDI"

    public var data: AppData
    /// `nil` for plain PWA backups.
    public var exportedAt: Date?

    public init(data: AppData, exportedAt: Date? = Date()) {
        self.data = data
        self.exportedAt = exportedAt
    }

    enum ExtraKeys: String, CodingKey {
        case app, exportedAt
    }

    /// Pretty JSON, keys sorted.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// Accepts LTIDI backups and plain PWA backups. Throws `AppDataError.invalidFile`.
    public static func decode(_ raw: Data) throws -> BackupFile {
        do {
            return try JSONDecoder().decode(BackupFile.self, from: raw)
        } catch {
            throw AppDataError.invalidFile
        }
    }
}

extension BackupFile: Codable {
    public init(from decoder: Decoder) throws {
        data = try AppData(from: decoder)
        let c = try decoder.container(keyedBy: ExtraKeys.self)
        exportedAt = c.lenientString(.exportedAt).flatMap(IDGenerator.parseTimestamp)
    }

    public func encode(to encoder: Encoder) throws {
        try data.encode(to: encoder)
        var c = encoder.container(keyedBy: ExtraKeys.self)
        try c.encode(BackupFile.appName, forKey: .app)
        if let exportedAt { try c.encode(IDGenerator.timestamp(exportedAt), forKey: .exportedAt) }
    }
}

/// Automatic backups in iCloud Drive (same procedure as the other apps):
/// shared container `iCloud.com.garoth93.backup`, sub-folder "LTIDI",
/// visible in Files as iCloud Drive › Backup › LTIDI.
///
/// Files: `LTIDI-backup-yyyy-MM-dd.json` (one per day, overwritten during the
/// day, the last `keepDaily` kept) plus `LTIDI-backup-latest.json`.
/// Pure logic only: the I/O is in the app (`CloudBackupService`).
public enum CloudBackupPlan {
    public static let containerID = "iCloud.com.garoth93.backup"
    public static let folderName = "LTIDI"
    public static let prefix = "LTIDI-backup-"
    public static let latestName = "LTIDI-backup-latest.json"
    public static let keepDaily = 30

    public struct Entry: Equatable, Hashable, Identifiable, Sendable {
        public let name: String
        /// Day of the backup (`nil` for "latest").
        public let day: DayDate?
        public var id: String { name }
        public var isLatest: Bool { day == nil }
    }

    public static func dailyName(for day: DayDate) -> String {
        "\(prefix)\(day.iso).json"
    }

    /// iCloud placeholder of a file not downloaded yet: ".name.json.icloud".
    public static func realName(_ fileName: String) -> String {
        guard fileName.hasPrefix("."), fileName.hasSuffix(".icloud") else { return fileName }
        return String(fileName.dropFirst().dropLast(".icloud".count))
    }

    /// Backups found in the folder: "latest" first, then newest day first.
    public static func entries(fromFileNames names: [String]) -> [Entry] {
        var latest: Entry?
        var daily: [Entry] = []
        for raw in Set(names.map(realName)) {
            if raw == latestName {
                latest = Entry(name: raw, day: nil)
            } else if raw.hasPrefix(prefix), raw.hasSuffix(".json") {
                let stamp = String(raw.dropFirst(prefix.count).dropLast(".json".count))
                if let day = DayDate(iso: stamp), dailyName(for: day) == raw {
                    daily.append(Entry(name: raw, day: day))
                }
            }
        }
        daily.sort { ($0.day ?? DayDate(dayNumber: 0)) > ($1.day ?? DayDate(dayNumber: 0)) }
        return (latest.map { [$0] } ?? []) + daily
    }

    /// Daily files beyond the newest `keep` ("latest" is never pruned).
    public static func namesToPrune(_ names: [String], keep: Int = keepDaily) -> [String] {
        let daily = entries(fromFileNames: names).filter { !$0.isLatest }
        return daily.count > keep ? daily[keep...].map(\.name) : []
    }

    /// Fingerprint of the content (not of the export time): unchanged
    /// fingerprint = no new backup needed.
    public static func fingerprint(_ data: AppData) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let bytes = try? encoder.encode(data) else { return "" }
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in bytes {
            hash ^= UInt64(byte)
            hash = hash &* 0x100_0000_01b3
        }
        return String(hash, radix: 16) + "-" + String(bytes.count)
    }

    /// An empty app never overwrites existing backups.
    public static func shouldBackUp(_ data: AppData) -> Bool {
        !data.activities.isEmpty || !data.entries.isEmpty
    }
}
