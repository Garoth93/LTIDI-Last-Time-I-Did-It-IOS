import SwiftUI

@main
struct LTIDIApp: App {
    @StateObject private var store = ActivityStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
