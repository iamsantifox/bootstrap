import Foundation

enum ShotSize: String, Codable, CaseIterable, Identifiable {
    case extremeWide = "EWS"
    case wide = "WS"
    case medium = "MS"
    case closeUp = "CU"
    case extremeCloseUp = "ECU"
    case detail = "Detail"
    case unknown = "—"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .extremeWide: return "Extreme Wide"
        case .wide: return "Wide"
        case .medium: return "Medium"
        case .closeUp: return "Close-Up"
        case .extremeCloseUp: return "Extreme Close-Up"
        case .detail: return "Detail"
        case .unknown: return "Unspecified"
        }
    }

    var estimatedMinutes: Int {
        switch self {
        case .extremeWide, .wide: return 5
        case .medium: return 4
        case .closeUp: return 3
        case .extremeCloseUp, .detail: return 2
        case .unknown: return 4
        }
    }
}

enum CameraAngle: String, Codable, CaseIterable, Identifiable {
    case eyeLevel = "Eye Level"
    case low = "Low Angle"
    case high = "High Angle"
    case birdsEye = "Bird's Eye"
    case dutch = "Dutch Angle"
    case pov = "POV"
    case unknown = "—"

    var id: String { rawValue }
}

struct Shot: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var notes: String
    var categoryID: UUID
    var parentShotID: UUID?
    var locationKey: String?
    var shotSize: ShotSize
    var cameraAngle: CameraAngle
    var sortOrder: Int
    var routeOrder: Int?
    var framingSettings: FramingSettings?

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        notes: String = "",
        categoryID: UUID,
        parentShotID: UUID? = nil,
        locationKey: String? = nil,
        shotSize: ShotSize = .unknown,
        cameraAngle: CameraAngle = .unknown,
        sortOrder: Int = 0,
        routeOrder: Int? = nil,
        framingSettings: FramingSettings? = nil
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.notes = notes
        self.categoryID = categoryID
        self.parentShotID = parentShotID
        self.locationKey = locationKey
        self.shotSize = shotSize
        self.cameraAngle = cameraAngle
        self.sortOrder = sortOrder
        self.routeOrder = routeOrder
        self.framingSettings = framingSettings
    }

    enum CodingKeys: String, CodingKey {
        case id, title, isCompleted, notes, categoryID, parentShotID, locationKey
        case shotSize, cameraAngle, sortOrder, routeOrder, framingSettings
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        notes = try container.decode(String.self, forKey: .notes)
        categoryID = try container.decode(UUID.self, forKey: .categoryID)
        parentShotID = try container.decodeIfPresent(UUID.self, forKey: .parentShotID)
        locationKey = try container.decodeIfPresent(String.self, forKey: .locationKey)
        shotSize = try container.decodeIfPresent(ShotSize.self, forKey: .shotSize) ?? .unknown
        cameraAngle = try container.decodeIfPresent(CameraAngle.self, forKey: .cameraAngle) ?? .unknown
        sortOrder = try container.decodeIfPresent(Int.self, forKey: .sortOrder) ?? 0
        routeOrder = try container.decodeIfPresent(Int.self, forKey: .routeOrder)
        framingSettings = try container.decodeIfPresent(FramingSettings.self, forKey: .framingSettings)
    }

    var isVariant: Bool { parentShotID != nil }

    func estimatedMinutes(categoryName: String) -> Int {
        if categoryName.uppercased().contains("DRONE") { return 12 }
        let lower = title.lowercased()
        if lower.contains("valo vaihtuu") || lower.contains("liikennevalo") { return 10 }
        if shotSize != .unknown { return shotSize.estimatedMinutes }
        return 4
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
    var brief: String
    var createdAt: Date
    var categories: [ShotCategory]
    var shots: [Shot]
    var routeStartLocationKey: String?

    enum CodingKeys: String, CodingKey {
        case id, title, brief, createdAt, categories, shots, routeStartLocationKey
    }

    init(
        id: UUID = UUID(),
        title: String,
        brief: String = "",
        createdAt: Date = Date(),
        categories: [ShotCategory] = [],
        shots: [Shot] = [],
        routeStartLocationKey: String? = "toolontori"
    ) {
        self.id = id
        self.title = title
        self.brief = brief
        self.createdAt = createdAt
        self.categories = categories
        self.shots = shots
        self.routeStartLocationKey = routeStartLocationKey
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        brief = try container.decodeIfPresent(String.self, forKey: .brief) ?? ""
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        categories = try container.decode([ShotCategory].self, forKey: .categories)
        shots = try container.decode([Shot].self, forKey: .shots)
        routeStartLocationKey = try container.decodeIfPresent(String.self, forKey: .routeStartLocationKey) ?? "toolontori"
    }

    func shots(in category: ShotCategory) -> [Shot] {
        shots
            .filter { $0.categoryID == category.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func category(for shot: Shot) -> ShotCategory? {
        categories.first { $0.id == shot.categoryID }
    }

    var completedCount: Int {
        shots.filter(\.isCompleted).count
    }

    var totalCount: Int {
        shots.count
    }

    var rootShots: [Shot] {
        shots.filter { $0.parentShotID == nil }.sorted { ($0.routeOrder ?? $0.sortOrder) < ($1.routeOrder ?? $1.sortOrder) }
    }

    func variants(of shot: Shot) -> [Shot] {
        shots.filter { $0.parentShotID == shot.id }.sorted { $0.sortOrder < $1.sortOrder }
    }
}
