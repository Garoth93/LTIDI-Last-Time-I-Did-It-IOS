import SwiftUI
import LTIDICore

@main
struct LTIDIApp: App {
    @State private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .tint(Color(hex: store.data.settings.accent))
                .preferredColorScheme(store.data.settings.theme.colorScheme)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.refreshToday() }
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
