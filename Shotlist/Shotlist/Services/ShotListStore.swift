import Foundation
import SwiftUI

@MainActor
final class ShotListStore: ObservableObject {
    @Published var projects: [ShotListProject] = []
    @Published var selectedProjectID: UUID?
    @Published var globalFramingSettings: FramingSettings = .default

    private let storageKey = "shotlist.projects"
    private let settingsKey = "shotlist.framingSettings"

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
            }
        }
    }

    func importFromPaste(_ text: String, title: String?) {
        let project = ShotListParser.parse(text, projectTitle: title)
        projects.insert(project, at: 0)
        selectedProjectID = project.id
        save()
    }

    func deleteProject(_ project: ShotListProject) {
        projects.removeAll { $0.id == project.id }
        if selectedProjectID == project.id {
            selectedProjectID = projects.first?.id
        }
        save()
    }

    func toggleShot(_ shot: Shot) {
        guard var project = selectedProject,
              let index = project.shots.firstIndex(where: { $0.id == shot.id }) else { return }
        project.shots[index].isCompleted.toggle()
        selectedProject = project
    }

    func updateShotNotes(_ shot: Shot, notes: String) {
        guard var project = selectedProject,
              let index = project.shots.firstIndex(where: { $0.id == shot.id }) else { return }
        project.shots[index].notes = notes
        selectedProject = project
    }

    func updateFramingSettings(_ settings: FramingSettings) {
        globalFramingSettings = settings
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: settingsKey)
        }
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
    }
}
