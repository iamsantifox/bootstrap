import Foundation
import CoreLocation

enum RoutePlanner {
    private static let walkingMetersPerMinute: Double = 83

    static func plan(
        for project: ShotListProject,
        startTime: Date = Date(),
        startLocationKey: String? = nil
    ) -> RoutePlan {
        let startKey = startLocationKey ?? project.routeStartLocationKey ?? "toolontori"

        var locationBuckets: [String: [(shot: Shot, categoryName: String)]] = [:]
        for shot in project.shots where !shot.isCompleted {
            let categoryName = project.category(for: shot)?.name ?? ""
            let key = shot.locationKey
                ?? LocationExtractor.resolveLocationKey(title: shot.title, categoryName: categoryName)
                ?? "toolo"
            locationBuckets[key, default: []].append((shot, categoryName))
        }

        var orderedKeys = optimizeLocationOrder(
            keys: Array(locationBuckets.keys),
            startKey: startKey
        )

        if !orderedKeys.contains(startKey), let start = ShootLocation.lookup(key: startKey) {
            orderedKeys.insert(startKey, at: 0)
        }

        var stops: [RouteStop] = []
        var cumulative = 0
        var previousLocation = ShootLocation.lookup(key: startKey) ?? ShootLocation.catalog[0]

        for (index, key) in orderedKeys.enumerated() {
            guard let location = ShootLocation.lookup(key: key),
                  let bucket = locationBuckets[key] else { continue }

            let walkMinutes: Int
            if index == 0 {
                walkMinutes = 0
            } else {
                let meters = previousLocation.clLocation.distance(from: location.clLocation)
                walkMinutes = max(1, Int(ceil(meters / walkingMetersPerMinute)))
            }

            let sortedShots = sortShotsAtLocation(bucket)
            let shootMinutes = sortedShots.reduce(0) { partial, item in
                partial + item.shot.estimatedMinutes(categoryName: item.categoryName)
            }

            cumulative += walkMinutes + shootMinutes

            stops.append(RouteStop(
                id: UUID(),
                location: location,
                shots: sortedShots.map(\.shot),
                order: index + 1,
                walkMinutesFromPrevious: walkMinutes,
                shootMinutes: shootMinutes,
                cumulativeMinutes: cumulative,
                estimatedArrival: startTime.addingTimeInterval(TimeInterval((cumulative - shootMinutes) * 60))
            ))

            previousLocation = location
        }

        let totalWalk = stops.reduce(0) { $0 + $1.walkMinutesFromPrevious }
        let totalShoot = stops.reduce(0) { $0 + $1.shootMinutes }

        return RoutePlan(
            stops: stops,
            totalWalkMinutes: totalWalk,
            totalShootMinutes: totalShoot,
            totalMinutes: totalWalk + totalShoot,
            startTime: startTime
        )
    }

    static func applyRouteOrder(to project: ShotListProject, plan: RoutePlan) -> ShotListProject {
        var updated = project
        var routeOrder = 0

        for stop in plan.stops {
            for shot in stop.shots {
                if let index = updated.shots.firstIndex(where: { $0.id == shot.id }) {
                    updated.shots[index].routeOrder = routeOrder
                    routeOrder += 1
                }
            }
        }

        return updated
    }

    private static func optimizeLocationOrder(keys: [String], startKey: String) -> [String] {
        guard !keys.isEmpty else { return [] }

        var remaining = Set(keys)
        var ordered: [String] = []

        var currentKey = remaining.contains(startKey) ? startKey : keys[0]
        ordered.append(currentKey)
        remaining.remove(currentKey)

        while !remaining.isEmpty {
            guard let current = ShootLocation.lookup(key: currentKey) else { break }
            let nearest = remaining.min { lhs, rhs in
                guard let locL = ShootLocation.lookup(key: lhs),
                      let locR = ShootLocation.lookup(key: rhs) else { return false }
                return current.clLocation.distance(from: locL.clLocation) < current.clLocation.distance(from: locR.clLocation)
            }
            guard let nearest else { break }
            ordered.append(nearest)
            remaining.remove(nearest)
            currentKey = nearest
        }

        return ordered
    }

    private static func sortShotsAtLocation(_ bucket: [(shot: Shot, categoryName: String)]) -> [(shot: Shot, categoryName: String)] {
        bucket.sorted { lhs, rhs in
            let sizeOrder: (ShotSize) -> Int = { size in
                switch size {
                case .extremeWide: return 0
                case .wide: return 1
                case .medium: return 2
                case .closeUp: return 3
                case .extremeCloseUp: return 4
                case .detail: return 5
                case .unknown: return 2
                }
            }

            let lParent = lhs.shot.parentShotID == nil
            let rParent = rhs.shot.parentShotID == nil
            if lParent != rParent { return lParent }

            let lSize = sizeOrder(lhs.shot.shotSize)
            let rSize = sizeOrder(rhs.shot.shotSize)
            if lSize != rSize { return lSize < rSize }

            return lhs.shot.sortOrder < rhs.shot.sortOrder
        }
    }
}
