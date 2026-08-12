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
                ?? ShootLocation.unmappedKey
            locationBuckets[key, default: []].append((shot, categoryName))
        }

        let orderedKeys = optimizeLocationOrder(
            keys: Array(locationBuckets.keys),
            startKey: startKey,
            customOrder: project.customRouteOrder
        )

        var stops: [RouteStop] = []
        var cumulative = 0
        var previousLocation = ShootLocation.lookup(key: startKey) ?? ShootLocation.catalog[0]
        var isFirstStop = true

        for key in orderedKeys {
            guard let location = ShootLocation.lookup(key: key),
                  let bucket = locationBuckets[key] else { continue }

            let walkMinutes: Int
            if location.isUnmapped {
                walkMinutes = isFirstStop ? 0 : 5
            } else if isFirstStop {
                if location.key == previousLocation.key {
                    walkMinutes = 0
                } else {
                    let meters = previousLocation.clLocation.distance(from: location.clLocation)
                    walkMinutes = max(1, Int(ceil(meters / walkingMetersPerMinute)))
                }
            } else if previousLocation.isUnmapped {
                walkMinutes = 5
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
                location: location,
                shots: sortedShots.map(\.shot),
                order: stops.count + 1,
                walkMinutesFromPrevious: walkMinutes,
                shootMinutes: shootMinutes,
                cumulativeMinutes: cumulative,
                estimatedArrival: startTime.addingTimeInterval(TimeInterval((cumulative - shootMinutes) * 60))
            ))

            previousLocation = location
            isFirstStop = false
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

    private static func optimizeLocationOrder(
        keys: [String],
        startKey: String,
        customOrder: [String]?
    ) -> [String] {
        guard !keys.isEmpty else { return [] }

        let keySet = Set(keys)
        if let customOrder {
            var ordered = customOrder.filter { keySet.contains($0) }
            let missing = keys.filter { !ordered.contains($0) }
            // Append any new locations with nearest-neighbor from the last custom stop.
            if !missing.isEmpty {
                let seed = ordered.last ?? startKey
                ordered.append(contentsOf: nearestNeighborOrder(keys: missing, startKey: seed))
            }
            // Keep unmapped last unless user explicitly ordered it.
            if ordered.contains(ShootLocation.unmappedKey),
               !(customOrder.contains(ShootLocation.unmappedKey)) {
                ordered.removeAll { $0 == ShootLocation.unmappedKey }
                ordered.append(ShootLocation.unmappedKey)
            }
            return ordered
        }

        var auto = nearestNeighborOrder(keys: keys.filter { $0 != ShootLocation.unmappedKey }, startKey: startKey)
        if keys.contains(ShootLocation.unmappedKey) {
            auto.append(ShootLocation.unmappedKey)
        }
        return auto
    }

    private static func nearestNeighborOrder(keys: [String], startKey: String) -> [String] {
        guard !keys.isEmpty else { return [] }

        var remaining = Set(keys)
        var ordered: [String] = []
        let startLocation = ShootLocation.lookup(key: startKey) ?? ShootLocation.assignableCatalog[0]

        let currentKey: String
        if remaining.contains(startKey) {
            currentKey = startKey
        } else {
            currentKey = remaining.min { lhs, rhs in
                distance(from: startLocation, toKey: lhs) < distance(from: startLocation, toKey: rhs)
            } ?? keys[0]
        }

        ordered.append(currentKey)
        remaining.remove(currentKey)
        var cursor = currentKey

        while !remaining.isEmpty {
            guard let current = ShootLocation.lookup(key: cursor) else { break }
            let nearest = remaining.min { lhs, rhs in
                distance(from: current, toKey: lhs) < distance(from: current, toKey: rhs)
            }
            guard let nearest else { break }
            ordered.append(nearest)
            remaining.remove(nearest)
            cursor = nearest
        }

        return ordered
    }

    private static func distance(from location: ShootLocation, toKey: String) -> Double {
        guard let other = ShootLocation.lookup(key: toKey), !other.isUnmapped, !location.isUnmapped else {
            return Double.greatestFiniteMagnitude / 4
        }
        return location.clLocation.distance(from: other.clLocation)
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
