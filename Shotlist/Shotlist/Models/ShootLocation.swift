import Foundation
import CoreLocation

struct ShootLocation: Identifiable, Hashable, Codable {
    let key: String
    let name: String
    let latitude: Double
    let longitude: Double
    let keywords: [String]

    var id: String { key }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var clLocation: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }

    static let catalog: [ShootLocation] = [
        ShootLocation(
            key: "toolontori",
            name: "Töölöntori",
            latitude: 60.1795,
            longitude: 24.9245,
            keywords: ["töölöntori", "runeberginkatu", "topeliuksenkatu", "töölöntor"]
        ),
        ShootLocation(
            key: "nordis",
            name: "Nordis / Helsingin jäähalli",
            latitude: 60.1808,
            longitude: 24.9265,
            keywords: ["nordis", "jäähalli", "jaahalli", "helsingin jäähalli", "halli"]
        ),
        ShootLocation(
            key: "mannerheimintie",
            name: "Mannerheimintie / Yliopiston Apteekki",
            latitude: 60.1810,
            longitude: 24.9195,
            keywords: ["mannerheimintie", "apteekki", "yliopiston apteekki"]
        ),
        ShootLocation(
            key: "nordenskildinkatu",
            name: "Nordenskiöldinkatu",
            latitude: 60.1815,
            longitude: 24.9270,
            keywords: ["nordenskiöldinkatu", "nordenskildinkatu", "urheilukatu"]
        ),
        ShootLocation(
            key: "reijolankatu",
            name: "Reijolankatu",
            latitude: 60.1788,
            longitude: 24.9210,
            keywords: ["reijolankatu"]
        ),
        ShootLocation(
            key: "olympiastadion",
            name: "Olympiastadion",
            latitude: 60.1850,
            longitude: 24.9265,
            keywords: ["olympiastadion", "stadionin torni", "stadion"]
        ),
        ShootLocation(
            key: "kisahalli",
            name: "Kisahalli",
            latitude: 60.1835,
            longitude: 24.9310,
            keywords: ["kisahalli"]
        ),
        ShootLocation(
            key: "toolo",
            name: "Töölö (general)",
            latitude: 60.1800,
            longitude: 24.9250,
            keywords: ["töölö", "toolo", "kivitalo", "kaupunkitunnelma"]
        ),
    ]

    static func lookup(key: String) -> ShootLocation? {
        catalog.first { $0.key == key }
    }
}

struct RouteStop: Identifiable, Equatable, Hashable {
    let id: UUID
    let location: ShootLocation
    let shots: [Shot]
    let order: Int
    let walkMinutesFromPrevious: Int
    let shootMinutes: Int
    let cumulativeMinutes: Int
    let estimatedArrival: Date?

    var totalMinutesAtStop: Int {
        walkMinutesFromPrevious + shootMinutes
    }
}

struct RoutePlan: Equatable {
    let stops: [RouteStop]
    let totalWalkMinutes: Int
    let totalShootMinutes: Int
    let totalMinutes: Int
    let startTime: Date

    var estimatedEndTime: Date {
        startTime.addingTimeInterval(TimeInterval(totalMinutes * 60))
    }

    var totalHoursFormatted: String {
        let hours = totalMinutes / 60
        let mins = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m"
        }
        return "\(mins)m"
    }
}
