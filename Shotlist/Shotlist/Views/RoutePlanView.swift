import SwiftUI
import MapKit

struct RoutePlanView: View {
    @EnvironmentObject private var store: ShotListStore
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var selectedStopKey: String?
    @State private var showShareSheet = false
    @State private var pdfURL: URL?
    @State private var isEditingOrder = false

    private var plan: RoutePlan? { store.cachedRoutePlan }

    var body: some View {
        Group {
            if store.selectedProject == nil {
                ContentUnavailableView {
                    Label("No Route", systemImage: "map")
                } description: {
                    Text("Import a shot list to generate a walking route.")
                } actions: {
                    Button("Go to Import") { store.selectedTab = .importList }
                        .buttonStyle(.borderedProminent)
                }
            } else if let plan, plan.stops.isEmpty {
                ContentUnavailableView {
                    Label("All Shots Done", systemImage: "checkmark.circle")
                } description: {
                    Text("Every shot is checked off. Uncheck shots to rebuild the route.")
                }
            } else if let project = store.selectedProject, let plan {
                routeContent(project: project, plan: plan)
            } else {
                ProgressView("Building route…")
            }
        }
        .navigationTitle("Walk Route")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if store.selectedProject != nil {
                    Menu {
                        Button("Export PDF", systemImage: "doc.richtext") {
                            exportPDF()
                        }
                        Button(isEditingOrder ? "Done Reordering" : "Reorder Stops", systemImage: "arrow.up.arrow.down") {
                            isEditingOrder.toggle()
                        }
                        if store.selectedProject?.customRouteOrder != nil {
                            Button("Reset to Optimized Order", systemImage: "arrow.clockwise") {
                                store.resetCustomRouteOrder()
                                isEditingOrder = false
                                fitMapToRoute()
                            }
                        }
                        Button("Recalculate Route", systemImage: "map") {
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
            if let pdfURL {
                ShareSheet(items: [pdfURL])
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
        List {
            Section {
                mapSection(plan: plan)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            Section("Schedule") {
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

                Picker("Start location", selection: Binding(
                    get: { project.routeStartLocationKey ?? "toolontori" },
                    set: { store.updateRouteStartLocation($0) }
                )) {
                    ForEach(ShootLocation.assignableCatalog) { location in
                        Text(location.name).tag(location.key)
                    }
                }

                if project.customRouteOrder != nil {
                    Label("Using custom stop order", systemImage: "hand.draw")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Text("Walk times are straight-line estimates at ~5 km/h — not turn-by-turn.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if plan.stops.contains(where: \.location.isUnmapped) {
                Section {
                    Label("Some shots still need a location. Assign them in Shot Detail.", systemImage: "mappin.slash")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                }
            }

            Section {
                ForEach(plan.stops) { stop in
                    RouteStopCard(stop: stop, isSelected: selectedStopKey == stop.id)
                        .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                        .onTapGesture { selectedStopKey = stop.id }
                }
                .onMove(perform: isEditingOrder ? store.reorderRouteStops : nil)
            } header: {
                HStack {
                    Text("Shoot order")
                    Spacer()
                    if isEditingOrder {
                        Text("Drag to reorder")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .environment(\.editMode, .constant(isEditingOrder ? .active : .inactive))
        .listStyle(.insetGrouped)
    }

    private func mapSection(plan: RoutePlan) -> some View {
        Map(position: $cameraPosition, selection: $selectedStopKey) {
            ForEach(plan.stops.filter { !$0.location.isUnmapped }) { stop in
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

            let mapped = plan.stops.filter { !$0.location.isUnmapped }
            if mapped.count >= 2 {
                MapPolyline(coordinates: mapped.map(\.location.coordinate))
                    .stroke(.orange, style: StrokeStyle(lineWidth: 3, dash: [8, 6]))
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    private func fitMapToRoute() {
        guard let plan = store.cachedRoutePlan else { return }
        let coords = plan.stops.filter { !$0.location.isUnmapped }.map(\.location.coordinate)
        guard !coords.isEmpty,
              let minLat = coords.map(\.latitude).min(),
              let maxLat = coords.map(\.latitude).max(),
              let minLon = coords.map(\.longitude).min(),
              let maxLon = coords.map(\.longitude).max() else { return }
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

    private func exportPDF() {
        guard let data = store.exportPDF(),
              let project = store.selectedProject,
              let url = PDFExporter.writeTemporaryPDF(data, projectTitle: project.title) else { return }
        pdfURL = url
        showShareSheet = true
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
                    .background(Circle().fill(stop.location.isUnmapped ? Color.secondary : Color.orange))

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
                if !stop.location.isUnmapped, let url = navigationURL {
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
