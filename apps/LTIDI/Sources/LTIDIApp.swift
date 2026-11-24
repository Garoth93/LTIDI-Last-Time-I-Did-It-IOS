import SwiftUI
import LTIDICore

@main
struct LTIDIApp: App {
    @State private var store = AppStore.shared
    @State private var cloud = CloudBackupService.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(cloud)
                .tint(Color(hex: store.data.settings.accent))
                .preferredColorScheme(store.data.settings.theme.colorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                store.refreshToday()
                CloudBackupService.scheduleBackgroundRefresh()
            case .background:
                CloudBackupService.scheduleBackgroundRefresh()
                Task { await cloud.backup(force: false) }
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(CloudBackupService.refreshTaskID)) {
            await CloudBackupService.shared.runBackgroundRefresh()
        }
    }
}

extension ThemeMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .auto: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
