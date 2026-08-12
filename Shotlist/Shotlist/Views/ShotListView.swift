import SwiftUI

struct ShotListView: View {
    @EnvironmentObject private var store: ShotListStore
    let project: ShotListProject
    var isPreview: Bool = false

    @State private var expandedCategories: Set<UUID> = []
    @State private var searchText = ""
    @State private var showIncompleteOnly = false
    @State private var showShareSheet = false
    @State private var pdfURL: URL?

    private var liveProject: ShotListProject {
        if isPreview { return project }
        return store.projects.first { $0.id == project.id } ?? project
    }

    var body: some View {
        List {
            if !liveProject.brief.isEmpty {
                Section("Brief") {
                    Text(liveProject.brief)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if liveProject.unmappedIncompleteCount > 0, !isPreview {
                Section {
                    Label(
                        "\(liveProject.unmappedIncompleteCount) shots need a location — open a shot to assign one.",
                        systemImage: "mappin.slash"
                    )
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                }
            }

            Section {
                ProgressHeaderView(
                    completed: liveProject.completedCount,
                    total: liveProject.totalCount
                )
            }

            ForEach(sortedCategories) { category in
                let shots = filteredShots(for: category)
                if !shots.isEmpty {
                    Section {
                        if expandedCategories.contains(category.id) || !searchText.isEmpty {
                            ForEach(shots) { shot in
                                ShotRowView(
                                    projectID: liveProject.id,
                                    shot: shot,
                                    categoryName: category.name,
                                    variants: liveProject.variants(of: shot),
                                    isPreview: isPreview
                                )
                            }
                        }
                    } header: {
                        CategoryHeaderView(
                            category: category,
                            shotCount: liveProject.categoryShotCount(category),
                            completedCount: liveProject.categoryCompletedCount(category),
                            isExpanded: expandedCategories.contains(category.id),
                            onToggle: { toggleCategory(category.id) }
                        )
                    }
                }
            }
        }
        .navigationTitle(liveProject.title)
        .searchable(text: $searchText, prompt: "Search shots")
        .toolbar {
            if !isPreview {
                ToolbarItem(placement: .topBarLeading) {
                    projectMenu
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if !isPreview {
                        Button {
                            exportPDF()
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                    Toggle(isOn: $showIncompleteOnly) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .toggleStyle(.button)
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdfURL {
                ShareSheet(items: [pdfURL])
            }
        }
        .onAppear {
            expandedCategories = Set(liveProject.categories.map(\.id))
        }
    }

    @ViewBuilder
    private var projectMenu: some View {
        if store.projects.count > 1 {
            Menu {
                ForEach(store.projects) { item in
                    Button {
                        store.selectProject(id: item.id)
                    } label: {
                        if item.id == liveProject.id {
                            Label(item.title, systemImage: "checkmark")
                        } else {
                            Text(item.title)
                        }
                    }
                }
            } label: {
                Label("Projects", systemImage: "folder")
            }
        }
    }

    private var sortedCategories: [ShotCategory] {
        liveProject.categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func filteredShots(for category: ShotCategory) -> [Shot] {
        var shots = liveProject.shots(in: category).filter { !$0.isVariant }
        if showIncompleteOnly {
            shots = shots.filter { shot in
                if !shot.isCompleted { return true }
                return liveProject.variants(of: shot).contains { !$0.isCompleted }
            }
        }
        guard !searchText.isEmpty else { return shots }
        return shots.filter { shot in
            if shot.title.localizedCaseInsensitiveContains(searchText) { return true }
            return liveProject.variants(of: shot).contains { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func toggleCategory(_ id: UUID) {
        if expandedCategories.contains(id) {
            expandedCategories.remove(id)
        } else {
            expandedCategories.insert(id)
        }
    }

    private func exportPDF() {
        guard let data = store.exportPDF(),
              let url = PDFExporter.writeTemporaryPDF(data, projectTitle: liveProject.title) else { return }
        pdfURL = url
        showShareSheet = true
    }
}

struct ProgressHeaderView: View {
    let completed: Int
    let total: Int

    private var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(completed) of \(total) shots")
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(.orange)
        }
        .padding(.vertical, 4)
    }
}

struct CategoryHeaderView: View {
    let category: ShotCategory
    let shotCount: Int
    let completedCount: Int
    let isExpanded: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
                Text(category.name)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(completedCount)/\(shotCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }
}

struct ShotRowView: View {
    @EnvironmentObject private var store: ShotListStore
    let projectID: UUID
    let shot: Shot
    let categoryName: String
    let variants: [Shot]
    let isPreview: Bool

    private var liveShot: Shot {
        store.liveShot(id: shot.id, fallback: shot, in: projectID)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                checkbox(for: liveShot)

                if isPreview {
                    shotLabel(for: liveShot, isVariant: false)
                } else {
                    NavigationLink {
                        ShotDetailView(shot: liveShot, categoryName: categoryName)
                    } label: {
                        shotLabel(for: liveShot, isVariant: false)
                    }
                }
            }

            ForEach(variants) { variant in
                let liveVariant = store.liveShot(id: variant.id, fallback: variant, in: projectID)
                HStack(alignment: .top, spacing: 12) {
                    checkbox(for: liveVariant)
                        .padding(.leading, 8)

                    if isPreview {
                        shotLabel(for: liveVariant, isVariant: true)
                    } else {
                        NavigationLink {
                            ShotDetailView(shot: liveVariant, categoryName: categoryName)
                        } label: {
                            shotLabel(for: liveVariant, isVariant: true)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func checkbox(for shot: Shot) -> some View {
        Button {
            guard !isPreview else { return }
            store.toggleShot(shot)
        } label: {
            Image(systemName: shot.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(shot.isCompleted ? .green : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(isPreview)
    }

    private func shotLabel(for shot: Shot, isVariant: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if isVariant {
                    Text("↳")
                        .foregroundStyle(.secondary)
                }
                Text(shot.title)
                    .font(isVariant ? .subheadline : .body)
                    .strikethrough(shot.isCompleted)
                    .foregroundStyle(shot.isCompleted ? .secondary : .primary)
                if shot.shotSize != .unknown {
                    Text(shot.shotSize.rawValue)
                        .font(.caption2.bold())
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(.orange.opacity(0.15), in: Capsule())
                }
            }

            if !isVariant, shot.cameraAngle != .unknown {
                Text(shot.cameraAngle.rawValue)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let key = shot.locationKey {
                if key == ShootLocation.unmappedKey {
                    Label("Needs location", systemImage: "mappin.slash")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else if let location = ShootLocation.lookup(key: key) {
                    Label(location.name, systemImage: "mappin")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            if !shot.notes.isEmpty {
                Text(shot.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ShotListView(project: ShotListParser.parse(SampleData.hifkTooloShotList, projectTitle: "Preview"))
            .environmentObject(ShotListStore())
    }
}
