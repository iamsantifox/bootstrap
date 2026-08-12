import Foundation
import SwiftUI

@MainActor
final class ShotListStore: ObservableObject {
    @Published var projects: [ShotListProject] = []
    @Published var selectedProjectID: UUID?
    @Published var globalFramingSettings: FramingSettings = .default
    @Published var routeStartTime: Date = Date()
    @Published var cachedRoutePlan: RoutePlan?

    private let storageKey = "shotlist.projects"
    private let settingsKey = "shotlist.framingSettings"
    private let routeStartKey = "shotlist.routeStartTime"

    init() {
        load()
    }

    var selectedProject: ShotListProject? {
        get {
            guard let id = selectedProjectID else { return projects.first }
            return projects.first { $0.id == id }
        }
        set {
            guard let project = newValue else { return }
            if let index = projects.firstIndex(where: { $0.id == project.id }) {
                projects[index] = project
                save()
                refreshRoutePlan()
            }
        }
    }

    func importFromPaste(_ text: String, title: String?) {
        var project = ShotListParser.parse(text, projectTitle: title)
        let plan = RoutePlanner.plan(for: project, startTime: routeStartTime)
        project = RoutePlanner.applyRouteOrder(to: project, plan: plan)
        projects.insert(project, at: 0)
        selectedProjectID = project.id
        cachedRoutePlan = plan
        save()
    }

    func deleteProject(_ project: ShotListProject) {
        projects.removeAll { $0.id == project.id }
        if selectedProjectID == project.id {
            selectedProjectID = projects.first?.id
            refreshRoutePlan()
        }
        save()
    }

    func toggleShot(_ shot: Shot) {
        guard var project = selectedProject,
              let index = project.shots.firstIndex(where: { $0.id == shot.id }) else { return }
        project.shots[index].isCompleted.toggle()
        selectedProject = project
        refreshRoutePlan()
    }

    func updateShotNotes(_ shot: Shot, notes: String) {
        guard var project = selectedProject,
              let index = project.shots.firstIndex(where: { $0.id == shot.id }) else { return }
        project.shots[index].notes = notes
        selectedProject = project
    }

    func updateShotFraming(_ shot: Shot, settings: FramingSettings) {
        guard var project = selectedProject,
              let index = project.shots.firstIndex(where: { $0.id == shot.id }) else { return }
        project.shots[index].framingSettings = settings
        selectedProject = project
    }

    func updateFramingSettings(_ settings: FramingSettings) {
        globalFramingSettings = settings
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
    }

    func updateRouteStartTime(_ date: Date) {
        routeStartTime = date
        UserDefaults.standard.set(date, forKey: routeStartKey)
        refreshRoutePlan()
    }

    func updateRouteStartLocation(_ key: String) {
        guard var project = selectedProject else { return }
        project.routeStartLocationKey = key
        selectedProject = project
        refreshRoutePlan()
    }

    func refreshRoutePlan() {
        guard let project = selectedProject else {
            cachedRoutePlan = nil
            return
        }
        let plan = RoutePlanner.plan(
            for: project,
            startTime: routeStartTime,
            startLocationKey: project.routeStartLocationKey
        )
        cachedRoutePlan = plan
        var updated = RoutePlanner.applyRouteOrder(to: project, plan: plan)
        if let index = projects.firstIndex(where: { $0.id == updated.id }) {
            projects[index] = updated
            save()
        }
    }

    func exportPDF() -> Data? {
        guard let project = selectedProject else { return nil }
        return PDFExporter.generatePDF(for: project, routePlan: cachedRoutePlan)
    }

    private func save() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ShotListProject].self, from: data) {
            projects = decoded
            selectedProjectID = decoded.first?.id
        }
        if let data = UserDefaults.standard.data(forKey: settingsKey),
           let settings = try? JSONDecoder().decode(FramingSettings.self, from: data) {
            globalFramingSettings = settings
        }
        if let date = UserDefaults.standard.object(forKey: routeStartKey) as? Date {
            routeStartTime = date
        }
        refreshRoutePlan()
    }
}
