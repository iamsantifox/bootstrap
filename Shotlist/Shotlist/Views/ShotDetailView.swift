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
                if liveShot.shotSize != .unknown {
                    LabeledContent("Shot size", value: liveShot.shotSize.displayName)
                }
                if liveShot.cameraAngle != .unknown {
                    LabeledContent("Angle", value: liveShot.cameraAngle.rawValue)
                }
                if let key = liveShot.locationKey, let location = ShootLocation.lookup(key: key) {
                    LabeledContent("Location", value: location.name)
                }
                LabeledContent("Est. time", value: "\(liveShot.estimatedMinutes(categoryName: categoryName)) min")
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
                    saveAndRegenerate()
                }

                Toggle("Auto-select lens for shot", isOn: $localSettings.useAutoLens)
                    .onChange(of: localSettings.useAutoLens) { _, _ in saveAndRegenerate() }

                if !localSettings.useAutoLens {
                    Picker("Lens", selection: $localSettings.lens) {
                        ForEach(LensOption.availableLenses(for: localSettings.camera)) { lens in
                            Text(lens.rawValue).tag(lens)
                        }
                    }
                    .onChange(of: localSettings.lens) { _, _ in saveAndRegenerate() }
                }

                Picker("Frame rate", selection: $localSettings.frameRate) {
                    ForEach(FrameRate.allCases) { rate in
                        Text(rate.displayName).tag(rate)
                    }
                }
                .onChange(of: localSettings.frameRate) { _, _ in saveAndRegenerate() }

                Picker("Aspect ratio", selection: $localSettings.aspectRatio) {
                    ForEach(AspectRatio.allCases) { ratio in
                        Text(ratio.rawValue).tag(ratio)
                    }
                }
                .onChange(of: localSettings.aspectRatio) { _, _ in saveAndRegenerate() }

                Picker("Time of Day", selection: $localSettings.timeOfDay) {
                    ForEach(TimeOfDay.allCases) { time in
                        Text(time.rawValue).tag(time)
                    }
                }
                .onChange(of: localSettings.timeOfDay) { _, _ in saveAndRegenerate() }

                Picker("Weather", selection: $localSettings.weather) {
                    ForEach(WeatherCondition.allCases) { weather in
                        Text(weather.rawValue).tag(weather)
                    }
                }
                .onChange(of: localSettings.weather) { _, _ in saveAndRegenerate() }

                Button("Generate Framing") {
                    regenerate()
                }
                .fontWeight(.semibold)
            }

            if let suggestion {
                Section("Framing Preview") {
                    FramingDiagramView(suggestion: suggestion, aspectRatio: localSettings.aspectRatio)
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
            if let saved = liveShot.framingSettings {
                localSettings = saved
            } else {
                localSettings = store.globalFramingSettings
                if let suggested = ShotMetadataExtractor.suggestedCamera(categoryName: categoryName) {
                    localSettings.camera = suggested
                    let available = LensOption.availableLenses(for: suggested)
                    if !available.contains(localSettings.lens) {
                        localSettings.lens = available[0]
                    }
                }
            }
            notes = liveShot.notes
            regenerate()
        }
    }

    private func saveAndRegenerate() {
        store.updateShotFraming(liveShot, settings: localSettings)
        regenerate()
    }

    private func regenerate() {
        suggestion = FramingGenerator.suggest(
            for: liveShot,
            settings: localSettings,
            categoryName: categoryName
        )
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
