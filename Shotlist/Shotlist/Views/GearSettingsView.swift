import SwiftUI

struct GearSettingsView: View {
    @EnvironmentObject private var store: ShotListStore
    @State private var settings: FramingSettings = .default

    var body: some View {
        Form {
            Section {
                Text("Set your default camera gear and shooting conditions. These apply to new shots unless overridden per shot.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Camera Body") {
                Picker("Camera", selection: $settings.camera) {
                    ForEach(CameraBody.allCases) { camera in
                        Text(camera.rawValue).tag(camera)
                    }
                }
                .onChange(of: settings.camera) { _, newCamera in
                    let available = LensOption.availableLenses(for: newCamera)
                    if !available.contains(settings.lens) {
                        settings.lens = available[0]
                    }
                }
            }

            Section("Lens") {
                Toggle("Auto-select lens for shot type", isOn: $settings.useAutoLens)

                if !settings.useAutoLens {
                    Picker("Default Lens", selection: $settings.lens) {
                        ForEach(LensOption.availableLenses(for: settings.camera)) { lens in
                            Text(lens.rawValue).tag(lens)
                        }
                    }
                }
            }

            Section("Format") {
                Picker("Frame rate", selection: $settings.frameRate) {
                    ForEach(FrameRate.allCases) { rate in
                        Text(rate.displayName).tag(rate)
                    }
                }
                Picker("Aspect ratio", selection: $settings.aspectRatio) {
                    ForEach(AspectRatio.allCases) { ratio in
                        Text(ratio.rawValue).tag(ratio)
                    }
                }
            }

            Section("Conditions") {
                Picker("Time of Day", selection: $settings.timeOfDay) {
                    ForEach(TimeOfDay.allCases) { time in
                        Text(time.rawValue).tag(time)
                    }
                }

                Picker("Weather", selection: $settings.weather) {
                    ForEach(WeatherCondition.allCases) { weather in
                        Text(weather.rawValue).tag(weather)
                    }
                }
            }

            Section {
                Button("Save as Default") {
                    store.updateFramingSettings(settings)
                }
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
            }

            if !store.projects.isEmpty {
                Section("Projects") {
                    ForEach(store.projects) { project in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(project.title)
                                    .font(.body.weight(.medium))
                                Text("\(project.completedCount)/\(project.totalCount) shots · \(project.categories.count) categories")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.selectedProjectID == project.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.orange)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            store.selectProject(id: project.id)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            store.deleteProject(store.projects[index])
                        }
                    }
                }
            }
        }
        .navigationTitle("Gear & Settings")
        .onAppear {
            settings = store.globalFramingSettings
        }
    }
}

#Preview {
    NavigationStack {
        GearSettingsView()
            .environmentObject(ShotListStore())
    }
}
