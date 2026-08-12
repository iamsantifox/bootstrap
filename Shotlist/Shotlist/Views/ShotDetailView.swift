import SwiftUI

struct ShotDetailView: View {
    @EnvironmentObject private var store: ShotListStore
    let shot: Shot
    let categoryName: String

    @State private var localSettings: FramingSettings = .default
    @State private var notes: String = ""
    @State private var suggestion: FramingSuggestion?

    private var liveShot: Shot {
        store.selectedProject?.shots.first { $0.id == shot.id } ?? shot
    }

    var body: some View {
        List {
            Section("Shot") {
                LabeledContent("Category", value: categoryName)
                Text(liveShot.title)
                    .font(.body)
            }

            Section("Framing Setup") {
                Picker("Camera", selection: $localSettings.camera) {
                    ForEach(CameraBody.allCases) { camera in
                        Text(camera.rawValue).tag(camera)
                    }
                }
                .onChange(of: localSettings.camera) { _, newCamera in
                    let available = LensOption.availableLenses(for: newCamera)
                    if !available.contains(localSettings.lens) {
                        localSettings.lens = available[0]
                    }
                    regenerate()
                }

                Picker("Lens", selection: $localSettings.lens) {
                    ForEach(LensOption.availableLenses(for: localSettings.camera)) { lens in
                        Text(lens.rawValue).tag(lens)
                    }
                }
                .onChange(of: localSettings.lens) { _, _ in regenerate() }

                Picker("Time of Day", selection: $localSettings.timeOfDay) {
                    ForEach(TimeOfDay.allCases) { time in
                        Text(time.rawValue).tag(time)
                    }
                }
                .onChange(of: localSettings.timeOfDay) { _, _ in regenerate() }

                Picker("Weather", selection: $localSettings.weather) {
                    ForEach(WeatherCondition.allCases) { weather in
                        Text(weather.rawValue).tag(weather)
                    }
                }
                .onChange(of: localSettings.weather) { _, _ in regenerate() }

                Button("Generate Framing") {
                    regenerate()
                }
                .fontWeight(.semibold)
            }

            if let suggestion {
                Section("Framing Preview") {
                    FramingDiagramView(suggestion: suggestion)
                        .frame(height: 220)
                        .listRowInsets(EdgeInsets())
                }

                Section("Suggested Settings") {
                    LabeledContent("Lens", value: suggestion.recommendedLens.rawValue)
                    LabeledContent("Focal Length", value: suggestion.effectiveFocalLength)
                    LabeledContent("Aperture", value: suggestion.aperture)
                    LabeledContent("Shutter", value: suggestion.shutterSpeed)
                    LabeledContent("ISO", value: suggestion.iso)
                    if let nd = suggestion.ndFilter {
                        LabeledContent("ND Filter", value: nd)
                    }
                    LabeledContent("Style", value: suggestion.framingStyle.displayName)
                    LabeledContent("Horizon", value: suggestion.horizonPlacement.rawValue)
                    LabeledContent("Subject", value: suggestion.subjectPlacement.rawValue)
                }

                Section("Composition") {
                    ForEach(suggestion.compositionNotes, id: \.self) { note in
                        Label(note, systemImage: "viewfinder")
                            .font(.subheadline)
                    }
                }

                Section("Movement & Light") {
                    Label(suggestion.movementSuggestion, systemImage: "arrow.triangle.2.circlepath.camera")
                    Label(suggestion.lightingNotes, systemImage: "sun.max")
                }
            }

            Section("Notes") {
                TextField("Add shoot notes…", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
                    .onChange(of: notes) { _, newValue in
                        store.updateShotNotes(liveShot, notes: newValue)
                    }
            }
        }
        .navigationTitle("Shot Detail")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            localSettings = store.globalFramingSettings
            notes = liveShot.notes
            regenerate()
        }
    }

    private func regenerate() {
        suggestion = FramingGenerator.suggest(for: liveShot, settings: localSettings)
    }
}

#Preview {
    NavigationStack {
        ShotDetailView(
            shot: Shot(title: "Töölöntori – drone ylhäältä", categoryID: UUID()),
            categoryName: "DRONE"
        )
        .environmentObject(ShotListStore())
    }
}
