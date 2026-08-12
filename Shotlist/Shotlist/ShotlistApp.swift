import SwiftUI

@main
struct ShotlistApp: App {
    @StateObject private var store = ShotListStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
