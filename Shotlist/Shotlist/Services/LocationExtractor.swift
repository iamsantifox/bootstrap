import Foundation

enum LocationExtractor {
    static func resolveLocationKey(title: String, categoryName: String) -> String? {
        let titleLower = title.lowercased()
        let categoryLower = categoryName.lowercased()

        var bestTitleMatch: (key: String, score: Int)?
        var bestCategoryMatch: (key: String, score: Int)?

        for location in ShootLocation.catalog {
            for keyword in location.keywords {
                if titleLower.contains(keyword) {
                    let score = keyword.count + 1_000
                    if bestTitleMatch == nil || score > bestTitleMatch!.score {
                        bestTitleMatch = (location.key, score)
                    }
                }

                // Only use unambiguous category segments. Slash-separated headers like
                // "MANNERHEIMINTIE / NORDENSKIÖLDINKATU" would otherwise pin every shot
                // to the longest category keyword.
                if categoryKeywordMatches(keyword, categoryLower: categoryLower) {
                    let score = keyword.count
                    if bestCategoryMatch == nil || score > bestCategoryMatch!.score {
                        bestCategoryMatch = (location.key, score)
                    }
                }
            }
        }

        if let bestTitleMatch {
            return bestTitleMatch.key
        }

        if let key = fallbackFromCategoryName(categoryName) {
            return key
        }

        if let bestCategoryMatch {
            return bestCategoryMatch.key
        }

        if categoryName.uppercased().contains("DRONE") {
            return "toolontori"
        }
        if categoryName.uppercased().contains("TÖÖLÖ") || categoryName.uppercased().contains("IFK") {
            return "toolo"
        }
        if categoryName.uppercased().contains("LIIKENNE") {
            return "mannerheimintie"
        }
        if titleLower.contains("halli") || categoryLower.contains("nordis") {
            return "nordis"
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

    private static func categoryKeywordMatches(_ keyword: String, categoryLower: String) -> Bool {
        guard categoryLower.contains(keyword) else { return false }

        // For multi-location headers, require the keyword to appear in a single segment.
        if categoryLower.contains(" / ") || categoryLower.contains(" – ") {
            let segments = categoryLower
                .components(separatedBy: " / ")
                .flatMap { $0.components(separatedBy: " – ") }
            return segments.contains { $0.contains(keyword) && !$0.contains(" / ") }
        }
        return true
    }

    private static func fallbackFromCategoryName(_ categoryName: String) -> String? {
        let upper = categoryName.uppercased()
        let primary = categoryName
            .components(separatedBy: " / ")
            .first?
            .components(separatedBy: " – ")
            .first?
            .trimmingCharacters(in: .whitespaces)
            ?? categoryName

        if let key = resolveAgainstCatalog(primary) {
            return key
        }

        if upper.contains("REIJOLANKATU") { return "reijolankatu" }
        if upper.contains("MANNERHEIM") { return "mannerheimintie" }
        if upper.contains("NORDENSKI") { return "nordenskildinkatu" }
        if upper.contains("NORDIS") { return "nordis" }
        if upper.contains("DRONE") { return "toolontori" }
        return nil
    }

    private static func resolveAgainstCatalog(_ text: String) -> String? {
        let lower = text.lowercased()
        var best: (key: String, score: Int)?
        for location in ShootLocation.catalog {
            for keyword in location.keywords where lower.contains(keyword) {
                if best == nil || keyword.count > best!.score {
                    best = (location.key, keyword.count)
                }
            }
            if lower.contains(location.name.lowercased()) {
                return location.key
            }
        }
        return best?.key
    }
}
