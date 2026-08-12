import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ShotListStore

    var body: some View {
        TabView {
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

            NavigationStack {
                RoutePlanView()
            }
            .tabItem {
                Label("Route", systemImage: "map")
            }

            NavigationStack {
                ImportShotListView()
            }
            .tabItem {
                Label("Import", systemImage: "doc.on.clipboard")
            }

            NavigationStack {
                GearSettingsView()
            }
            .tabItem {
                Label("Gear", systemImage: "camera.aperture")
            }
        }
        .tint(.orange)
    }
}

struct EmptyProjectView: View {
    var body: some View {
        ContentUnavailableView {
            Label("No Shot List", systemImage: "film.stack")
        } description: {
            Text("Paste a shot list in the Import tab to get started.")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(ShotListStore())
}
