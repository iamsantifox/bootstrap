import SwiftUI

struct ShotListView: View {
    @EnvironmentObject private var store: ShotListStore
    let project: ShotListProject
    var isPreview: Bool = false

    @State private var expandedCategories: Set<UUID> = []
    @State private var searchText = ""
    @State private var showIncompleteOnly = false

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

            Section {
                ProgressHeaderView(
                    completed: liveProject.completedCount,
                    total: liveProject.totalCount
                )
            }

            ForEach(sortedCategories) { category in
                let shots = filteredShots(for: category)
                if !shots.isEmpty || searchText.isEmpty {
                    Section {
                        if expandedCategories.contains(category.id) || !searchText.isEmpty {
                            ForEach(shots) { shot in
                                ShotRowView(
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
                            shotCount: liveProject.shots(in: category).filter { !$0.isVariant }.count,
                            completedCount: liveProject.shots(in: category).filter(\.isCompleted).count,
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
            ToolbarItem(placement: .topBarTrailing) {
                Toggle(isOn: $showIncompleteOnly) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
                .toggleStyle(.button)
            }
        }
        .onAppear {
            expandedCategories = Set(liveProject.categories.map(\.id))
        }
    }

    private var sortedCategories: [ShotCategory] {
        liveProject.categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func filteredShots(for category: ShotCategory) -> [Shot] {
        var shots = liveProject.shots(in: category).filter { !$0.isVariant }
        if showIncompleteOnly {
            shots = shots.filter { !$0.isCompleted }
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
    let shot: Shot
    let categoryName: String
    let variants: [Shot]
    let isPreview: Bool

    private var liveShot: Shot {
        store.selectedProject?.shots.first { $0.id == shot.id } ?? shot
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                guard !isPreview else { return }
                store.toggleShot(liveShot)
            } label: {
                Image(systemName: liveShot.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(liveShot.isCompleted ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .disabled(isPreview)

            NavigationLink {
                ShotDetailView(shot: liveShot, categoryName: categoryName)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(liveShot.title)
                            .font(.body)
                            .strikethrough(liveShot.isCompleted)
                            .foregroundStyle(liveShot.isCompleted ? .secondary : .primary)
                        if liveShot.shotSize != .unknown {
                            Text(liveShot.shotSize.rawValue)
                                .font(.caption2.bold())
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.orange.opacity(0.15), in: Capsule())
                        }
                    }

                    if liveShot.cameraAngle != .unknown {
                        Text(liveShot.cameraAngle.rawValue)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    if let location = liveShot.locationKey.flatMap({ ShootLocation.lookup(key: $0) }) {
                        Label(location.name, systemImage: "mappin")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(variants) { variant in
                        let liveVariant = store.selectedProject?.shots.first { $0.id == variant.id } ?? variant
                        HStack(spacing: 4) {
                            Text("↳")
                            Text(liveVariant.title)
                            if liveVariant.shotSize != .unknown {
                                Text(liveVariant.shotSize.rawValue)
                                    .font(.caption2.bold())
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    if !liveShot.notes.isEmpty {
                        Text(liveShot.notes)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    NavigationStack {
        ShotListView(project: ShotListParser.parse(SampleData.hifkTooloShotList, projectTitle: "Preview"))
            .environmentObject(ShotListStore())
    }
}
