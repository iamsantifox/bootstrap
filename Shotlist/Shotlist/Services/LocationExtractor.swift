import Foundation

enum LocationExtractor {
    static func resolveLocationKey(title: String, categoryName: String) -> String? {
        let haystack = "\(categoryName) \(title)".lowercased()

        var bestMatch: (key: String, score: Int)?
        for location in ShootLocation.catalog {
            for keyword in location.keywords {
                if haystack.contains(keyword) {
                    let score = keyword.count
                    if bestMatch == nil || score > bestMatch!.score {
                        bestMatch = (location.key, score)
                    }
                }
            }
        }

        if let bestMatch {
            return bestMatch.key
        }

        if categoryName.uppercased().contains("DRONE") {
            return "toolontori"
        }
        if categoryName.uppercased().contains("TÖÖLÖ") {
            return "toolo"
        }

        return nil
    }

    static func location(for shot: Shot, categoryName: String) -> ShootLocation? {
        if let key = shot.locationKey {
            return ShootLocation.lookup(key: key)
        }
        if let key = resolveLocationKey(title: shot.title, categoryName: categoryName) {
            return ShootLocation.lookup(key: key)
        }
        return ShootLocation.lookup(key: "toolo")
    }
}
