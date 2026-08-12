import Foundation

struct Shot: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var notes: String
    var categoryID: UUID

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        notes: String = "",
        categoryID: UUID
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.notes = notes
        self.categoryID = categoryID
    }
}

struct ShotCategory: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        description: String = "",
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.sortOrder = sortOrder
    }
}

struct ShotListProject: Identifiable, Codable {
    let id: UUID
    var title: String
    var createdAt: Date
    var categories: [ShotCategory]
    var shots: [Shot]

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date = Date(),
        categories: [ShotCategory] = [],
        shots: [Shot] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.categories = categories
        self.shots = shots
    }

    func shots(in category: ShotCategory) -> [Shot] {
        shots.filter { $0.categoryID == category.id }
    }

    var completedCount: Int {
        shots.filter(\.isCompleted).count
    }

    var totalCount: Int {
        shots.count
    }
}
