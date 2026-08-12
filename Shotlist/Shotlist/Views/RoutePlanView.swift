import SwiftUI
import MapKit

struct RoutePlanView: View {
    @EnvironmentObject private var store: ShotListStore
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedStopKey: String?
    @State private var showShareSheet = false
    @State private var pdfData: Data?

    private var plan: RoutePlan? { store.cachedRoutePlan }

    var body: some View {
        Group {
            if store.selectedProject == nil {
                ContentUnavailableView {
                    Label("No Route", systemImage: "map")
                } description: {
                    Text("Import a shot list to generate a walking route.")
                }
            } else if let plan, plan.stops.isEmpty {
                ContentUnavailableView {
                    Label("All Shots Done", systemImage: "checkmark.circle")
                } description: {
                    Text("Every shot is checked off. Uncheck shots to rebuild the route.")
                }
            } else if let project = store.selectedProject, let plan {
                routeContent(project: project, plan: plan)
            }
        }
        .navigationTitle("Walk Route")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if store.selectedProject != nil {
                    Menu {
                        Button("Export PDF", systemImage: "doc.richtext") {
                            pdfData = store.exportPDF()
                            showShareSheet = true
                        }
                        Button("Recalculate Route", systemImage: "arrow.clockwise") {
                            store.refreshRoutePlan()
                            fitMapToRoute()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdfData, let url = writeTempPDF(pdfData) {
                ShareSheet(items: [url])
            }
        }
        .onAppear {
            fitMapToRoute()
        }
        .onChange(of: store.cachedRoutePlan?.totalMinutes) { _, _ in
            fitMapToRoute()
        }
    }

    @ViewBuilder
    private func routeContent(project: ShotListProject, plan: RoutePlan) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                mapSection(plan: plan)
                timeSummarySection(plan: plan)
                startPointSection(project: project)
                stopsSection(plan: plan)
            }
            .padding(.bottom, 24)
        }
    }

    private func mapSection(plan: RoutePlan) -> some View {
        Map(position: $cameraPosition, selection: $selectedStopKey) {
            ForEach(plan.stops) { stop in
                Annotation(stop.location.name, coordinate: stop.location.coordinate) {
                    ZStack {
                        Circle()
                            .fill(selectedStopKey == stop.id ? Color.orange : Color.orange.opacity(0.85))
                            .frame(width: 28, height: 28)
                        Text("\(stop.order)")
                            .font(.caption2.bold())
                            .foregroundStyle(.white)
                    }
                }
                .tag(stop.id)
            }

            if plan.stops.count >= 2 {
                MapPolyline(coordinates: plan.stops.map(\.location.coordinate))
                    .stroke(.orange, lineWidth: 3)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func timeSummarySection(plan: RoutePlan) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(plan.totalHoursFormatted)
                        .font(.title2.bold())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ETA finish")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(plan.estimatedEndTime, style: .time)
                        .font(.headline)
                }
            }

            HStack(spacing: 16) {
                Label("\(plan.totalWalkMinutes)m walk", systemImage: "figure.walk")
                Label("\(plan.totalShootMinutes)m shoot", systemImage: "camera")
                Label("\(plan.stops.count) stops", systemImage: "mappin.and.ellipse")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            DatePicker("Start time", selection: Binding(
                get: { store.routeStartTime },
                set: { store.updateRouteStartTime($0) }
            ), displayedComponents: [.date, .hourAndMinute])
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func startPointSection(project: ShotListProject) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start location")
                .font(.headline)
            Picker("Start", selection: Binding(
                get: { project.routeStartLocationKey ?? "toolontori" },
                set: { store.updateRouteStartLocation($0) }
            )) {
                ForEach(ShootLocation.catalog) { location in
                    Text(location.name).tag(location.key)
                }
            }
            .pickerStyle(.menu)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }

    private func stopsSection(plan: RoutePlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Shoot order")
                .font(.headline)
                .padding(.horizontal)

            ForEach(plan.stops) { stop in
                RouteStopCard(stop: stop, isSelected: selectedStopKey == stop.id)
                    .onTapGesture { selectedStopKey = stop.id }
            }
        }
    }

    private func fitMapToRoute() {
        guard let plan = store.cachedRoutePlan, !plan.stops.isEmpty else { return }
        let coords = plan.stops.map(\.location.coordinate)
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.4),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.4)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }

    private func writeTempPDF(_ data: Data) -> URL? {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Shotlist-Route.pdf")
        do {
            try data.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

struct RouteStopCard: View {
    let stop: RouteStop
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text("\(stop.order)")
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .frame(width: 24, height: 24)
                    .background(Circle().fill(.orange))

                VStack(alignment: .leading, spacing: 4) {
                    Text(stop.location.name)
                        .font(.subheadline.bold())
                    HStack(spacing: 12) {
                        if stop.walkMinutesFromPrevious > 0 {
                            Label("\(stop.walkMinutesFromPrevious)m walk", systemImage: "figure.walk")
                        }
                        Label("\(stop.shootMinutes)m shoot", systemImage: "camera")
                        if let arrival = stop.estimatedArrival {
                            Label(arrival, format: .dateTime.hour().minute())
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                if let url = navigationURL {
                    Link(destination: url) {
                        Label("Navigate", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.caption.bold())
                    }
                }
            }

            ForEach(stop.shots) { shot in
                HStack(spacing: 8) {
                    Image(systemName: shot.isCompleted ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(shot.isCompleted ? .green : .secondary)
                        .font(.caption)
                    Text(shot.title)
                        .font(.caption)
                        .lineLimit(2)
                    Spacer()
                    if shot.shotSize != .unknown {
                        Text(shot.shotSize.rawValue)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.orange.opacity(0.15), in: Capsule())
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemGroupedBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.orange : Color.clear, lineWidth: 2)
                )
        )
        .padding(.horizontal)
    }

    private var navigationURL: URL? {
        let coordinate = stop.location.coordinate
        return URL(string: "maps://?daddr=\(coordinate.latitude),\(coordinate.longitude)&dirflg=w")
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        RoutePlanView()
            .environmentObject(ShotListStore())
    }
}
