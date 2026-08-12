import Foundation
import SwiftUI

@MainActor
final class ShotListStore: ObservableObject {
    @Published var projects: [ShotListProject] = []
    @Published var selectedProjectID: UUID?
    @Published var globalFramingSettings: FramingSettings = .default
    @Published var routeStartTime: Date = Date()
    @Published var cachedRoutePlan: RoutePlan?
    @Published var selectedTab: AppTab = .shots

    private let storageKey = "shotlist.projects"
    private let settingsKey = "shotlist.framingSettings"
    private let routeStartKey = "shotlist.routeStartTime"
    private let selectedProjectKey = "shotlist.selectedProjectID"

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
            upsert(project, refreshRoute: false)
        }
    }

    func importFromPaste(_ text: String, title: String?) {
        var project = ShotListParser.parse(text, projectTitle: title)
        let plan = RoutePlanner.plan(for: project, startTime: routeStartTime)
        project = RoutePlanner.applyRouteOrder(to: project, plan: plan)
        projects.insert(project, at: 0)
        selectProject(id: project.id)
        cachedRoutePlan = plan
        selectedTab = .shots
        save()
    }

    func deleteProject(_ project: ShotListProject) {
        projects.removeAll { $0.id == project.id }
        if selectedProjectID == project.id {
            selectedProjectID = projects.first?.id
            persistSelectedProjectID()
        }
        save()
        refreshRoutePlan()
    }

    func toggleShot(_ shot: Shot) {
        guard var project = projectContaining(shotID: shot.id),
              let index = project.shots.firstIndex(where: { $0.id == shot.id }) else { return }
        project.shots[index].isCompleted.toggle()
        upsert(project, refreshRoute: true)
    }

    func updateShotNotes(_ shot: Shot, notes: String) {
        guard var project = projectContaining(shotID: shot.id),
              let index = project.shots.firstIndex(where: { $0.id == shot.id }) else { return }
        project.shots[index].notes = notes
        upsert(project, refreshRoute: false)
    }

    func updateShotMetadata(
        _ shot: Shot,
        title: String? = nil,
        shotSize: ShotSize? = nil,
        cameraAngle: CameraAngle? = nil,
        locationKey: String? = nil
    ) {
        guard var project = projectContaining(shotID: shot.id),
              let index = project.shots.firstIndex(where: { $0.id == shot.id }) else { return }
        if let title { project.shots[index].title = title }
        if let shotSize { project.shots[index].shotSize = shotSize }
        if let cameraAngle { project.shots[index].cameraAngle = cameraAngle }
        if let locationKey {
            project.shots[index].locationKey = locationKey == ShootLocation.unmappedKey ? ShootLocation.unmappedKey : locationKey
        }
        upsert(project, refreshRoute: locationKey != nil)
    }

    func updateShotFraming(_ shot: Shot, settings: FramingSettings) {
        guard var project = projectContaining(shotID: shot.id),
              let index = project.shots.firstIndex(where: { $0.id == shot.id }) else { return }
        project.shots[index].framingSettings = settings
        upsert(project, refreshRoute: false)
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
        upsert(project, refreshRoute: true)
    }

    func reorderRouteStops(from source: IndexSet, to destination: Int) {
        guard var project = selectedProject,
              var plan = cachedRoutePlan else { return }
        var keys = plan.stops.map(\.location.key)
        keys.move(fromOffsets: source, toOffset: destination)
        project.customRouteOrder = keys
        upsert(project, refreshRoute: false)

        plan = RoutePlanner.plan(
            for: project,
            startTime: routeStartTime,
            startLocationKey: project.routeStartLocationKey
        )
        cachedRoutePlan = plan
        let updated = RoutePlanner.applyRouteOrder(to: project, plan: plan)
        if let index = projects.firstIndex(where: { $0.id == updated.id }) {
            projects[index] = updated
            save()
        }
    }

    func resetCustomRouteOrder() {
        guard var project = selectedProject else { return }
        project.customRouteOrder = nil
        upsert(project, refreshRoute: true)
    }

    func selectProject(id: UUID) {
        selectedProjectID = id
        persistSelectedProjectID()
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

        let updated = RoutePlanner.applyRouteOrder(to: project, plan: plan)
        if let index = projects.firstIndex(where: { $0.id == updated.id }) {
            projects[index] = updated
            save()
        }
    }

    func exportPDF() -> Data? {
        guard let project = selectedProject else { return nil }
        return PDFExporter.generatePDF(for: project, routePlan: cachedRoutePlan)
    }

    func liveShot(id: UUID, fallback: Shot, in projectID: UUID?) -> Shot {
        if let projectID,
           let project = projects.first(where: { $0.id == projectID }),
           let shot = project.shots.first(where: { $0.id == id }) {
            return shot
        }
        if let shot = selectedProject?.shots.first(where: { $0.id == id }) {
            return shot
        }
        return fallback
    }

    private func projectContaining(shotID: UUID) -> ShotListProject? {
        if let selected = selectedProject, selected.shots.contains(where: { $0.id == shotID }) {
            return selected
        }
        return projects.first { $0.shots.contains(where: { $0.id == shotID }) }
    }

    private func upsert(_ project: ShotListProject, refreshRoute: Bool) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        } else {
            projects.insert(project, at: 0)
        }
        save()
        if refreshRoute {
            refreshRoutePlan()
        }
    }

    private func persistSelectedProjectID() {
        if let selectedProjectID {
            UserDefaults.standard.set(selectedProjectID.uuidString, forKey: selectedProjectKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedProjectKey)
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(projects) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        persistSelectedProjectID()
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([ShotListProject].self, from: data) {
            projects = decoded
            if let saved = UserDefaults.standard.string(forKey: selectedProjectKey),
               let uuid = UUID(uuidString: saved),
               decoded.contains(where: { $0.id == uuid }) {
                selectedProjectID = uuid
            } else {
                selectedProjectID = decoded.first?.id
            }
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

enum AppTab: Hashable {
    case shots
    case route
    case importList
    case gear
}
