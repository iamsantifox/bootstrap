import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ShotListStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            NavigationStack {
                if let project = store.selectedProject {
                    ShotListView(project: project)
                } else {
                    EmptyProjectView()
                }
            }
            .tabItem {
                Label("Shots", systemImage: "list.bullet.clipboard")
            }
            .tag(AppTab.shots)

            NavigationStack {
                RoutePlanView()
            }
            .tabItem {
                Label("Route", systemImage: "map")
            }
            .tag(AppTab.route)

            NavigationStack {
                ImportShotListView()
            }
            .tabItem {
                Label("Import", systemImage: "doc.on.clipboard")
            }
            .tag(AppTab.importList)

            NavigationStack {
                GearSettingsView()
            }
            .tabItem {
                Label("Gear", systemImage: "camera.aperture")
            }
            .tag(AppTab.gear)
        }
        .tint(.orange)
    }
}

struct EmptyProjectView: View {
    @EnvironmentObject private var store: ShotListStore

    var body: some View {
        ContentUnavailableView {
            Label("No Shot List", systemImage: "film.stack")
        } description: {
            Text("Paste a shot list in the Import tab to get started.")
        } actions: {
            Button("Go to Import") {
                store.selectedTab = .importList
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ShotListStore())
}
