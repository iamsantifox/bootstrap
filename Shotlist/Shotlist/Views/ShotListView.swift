import SwiftUI

struct ShotListView: View {
    @EnvironmentObject private var store: ShotListStore
    let project: ShotListProject
    var isPreview: Bool = false

    @State private var expandedCategories: Set<UUID> = []
    @State private var searchText = ""

    private var liveProject: ShotListProject {
        if isPreview { return project }
        return store.projects.first { $0.id == project.id } ?? project
    }

    var body: some View {
        List {
            Section {
                ProgressHeaderView(
                    completed: liveProject.completedCount,
                    total: liveProject.totalCount
                )
            }

            ForEach(sortedCategories) { category in
                Section {
                    if expandedCategories.contains(category.id) || !searchText.isEmpty {
                        ForEach(filteredShots(for: category)) { shot in
                            NavigationLink {
                                ShotDetailView(shot: shot, categoryName: category.name)
                            } label: {
                                ShotRowView(shot: shot, isPreview: isPreview)
                            }
                        }
                    }
                } header: {
                    CategoryHeaderView(
                        category: category,
                        shotCount: liveProject.shots(in: category).count,
                        completedCount: liveProject.shots(in: category).filter(\.isCompleted).count,
                        isExpanded: expandedCategories.contains(category.id),
                        onToggle: { toggleCategory(category.id) }
                    )
                } footer: {
                    if !category.description.isEmpty {
                        Text(category.description)
                    }
                }
            }
        }
        .navigationTitle(liveProject.title)
        .searchable(text: $searchText, prompt: "Search shots")
        .onAppear {
            expandedCategories = Set(liveProject.categories.map(\.id))
        }
    }

    private var sortedCategories: [ShotCategory] {
        liveProject.categories.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func filteredShots(for category: ShotCategory) -> [Shot] {
        let shots = liveProject.shots(in: category)
        guard !searchText.isEmpty else { return shots }
        return shots.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
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
    let isPreview: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
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

            VStack(alignment: .leading, spacing: 4) {
                Text(shot.title)
                    .font(.body)
                    .strikethrough(shot.isCompleted)
                    .foregroundStyle(shot.isCompleted ? .secondary : .primary)
                if !shot.notes.isEmpty {
                    Text(shot.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
