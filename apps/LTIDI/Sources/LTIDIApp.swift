import SwiftUI

@main
struct LTIDIApp: App {
    @State private var store = ActivityStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
        }
    }
}
