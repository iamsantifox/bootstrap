import Foundation

enum ShotListParser {
    private static let completedPrefixes = ["☑", "✓", "✔"]
    private static let uncheckedPrefixes = ["☐"]
    private static let bulletPrefixes = ["-", "•", "*", "–", "—"]

    static func parse(_ text: String, projectTitle: String? = nil) -> ShotListProject {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var categories: [ShotCategory] = []
        var shots: [Shot] = []
        var currentCategory: ShotCategory?
        var categoryOrder = 0
        var inferredTitle = projectTitle
        var brief = ""
        var hasSeenCategory = false
        var shotOrder = 0
        var lastRootShotID: UUID?
        var skippedTitleLine = projectTitle == nil
        var orphanCategory: ShotCategory?

        for line in lines where !line.isEmpty {
            if let parsed = extractShot(from: line) {
                let category: ShotCategory
                if let current = currentCategory {
                    category = current
                } else {
                    if orphanCategory == nil {
                        orphanCategory = ShotCategory(name: "UNCATEGORIZED", sortOrder: -1)
                        categories.insert(orphanCategory!, at: 0)
                        categoryOrder = max(categoryOrder, 0)
                    }
                    category = orphanCategory!
                    hasSeenCategory = true
                }

                let title = parsed.title
                var parentID: UUID?
                var locationKey = ShotMetadataExtractor.locationKey(from: title, categoryName: category.name)
                var shotSize = ShotMetadataExtractor.shotSize(from: title, categoryName: category.name)
                var cameraAngle = ShotMetadataExtractor.cameraAngle(from: title, categoryName: category.name)

                if ShotMetadataExtractor.isVariantTitle(title), let parent = lastRootShotID {
                    parentID = parent
                    if let parentShot = shots.first(where: { $0.id == parent }) {
                        locationKey = parentShot.locationKey ?? locationKey
                        cameraAngle = parentShot.cameraAngle == .unknown ? cameraAngle : parentShot.cameraAngle
                        switch title.lowercased() {
                        case "medium", "keski":
                            shotSize = .medium
                        case "wide", "laaja":
                            shotSize = .wide
                        case "close / detail", "close", "detail", "tiukempana":
                            shotSize = .closeUp
                        default:
                            break
                        }
                    }
                }

                if locationKey == nil {
                    locationKey = ShootLocation.unmappedKey
                }

                let shot = Shot(
                    title: title,
                    isCompleted: parsed.isCompleted,
                    categoryID: category.id,
                    parentShotID: parentID,
                    locationKey: locationKey,
                    shotSize: shotSize,
                    cameraAngle: cameraAngle,
                    sortOrder: shotOrder
                )
                shotOrder += 1
                shots.append(shot)

                if parentID == nil {
                    lastRootShotID = shot.id
                }
                continue
            }

            if inferredTitle == nil, !hasSeenCategory {
                inferredTitle = line
                skippedTitleLine = true
                continue
            }

            if !skippedTitleLine, !hasSeenCategory, isLikelyPastedTitle(line, projectTitle: projectTitle) {
                skippedTitleLine = true
                continue
            }

            if !hasSeenCategory, isBriefLine(line) {
                brief = brief.isEmpty ? line : "\(brief)\n\(line)"
                continue
            }

            if isCategoryHeader(line) {
                let category = ShotCategory(
                    name: cleanCategoryName(line),
                    sortOrder: categoryOrder
                )
                categoryOrder += 1
                categories.append(category)
                currentCategory = category
                hasSeenCategory = true
                lastRootShotID = nil
                continue
            }
        }

        // Re-number orphan category to end if real categories exist
        if let orphan = orphanCategory,
           let index = categories.firstIndex(where: { $0.id == orphan.id }),
           categories.count > 1 {
            var moved = categories.remove(at: index)
            moved.sortOrder = categoryOrder
            categories.append(moved)
        }

        return ShotListProject(
            title: inferredTitle ?? "Shot List",
            brief: brief,
            categories: categories,
            shots: shots
        )
    }

    private struct ParsedShot {
        let title: String
        let isCompleted: Bool
    }

    private static func extractShot(from line: String) -> ParsedShot? {
        if let markdown = extractMarkdownCheckbox(from: line) {
            return markdown
        }

        for prefix in completedPrefixes {
            if line.hasPrefix(prefix) {
                let title = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                return title.isEmpty ? nil : ParsedShot(title: title, isCompleted: true)
            }
        }

        for prefix in uncheckedPrefixes + bulletPrefixes {
            if line.hasPrefix(prefix) {
                let title = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
                return title.isEmpty ? nil : ParsedShot(title: title, isCompleted: false)
            }
        }

        if let match = line.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
            let title = String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)
            return title.isEmpty ? nil : ParsedShot(title: title, isCompleted: false)
        }

        return nil
    }

    private static func extractMarkdownCheckbox(from line: String) -> ParsedShot? {
        let patterns: [(String, Bool)] = [
            (#"^\[x\]\s+"#, true),
            (#"^\[X\]\s+"#, true),
            (#"^\[\s\]\s+"#, false),
            (#"^\[\]\s+"#, false),
        ]
        for (pattern, completed) in patterns {
            if let match = line.range(of: pattern, options: .regularExpression) {
                let title = String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)
                return title.isEmpty ? nil : ParsedShot(title: title, isCompleted: completed)
            }
        }
        return nil
    }

    private static func isCategoryHeader(_ line: String) -> Bool {
        if extractShot(from: line) != nil { return false }

        let letters = line.filter(\.isLetter)
        guard !letters.isEmpty else { return false }

        let uppercaseRatio = Double(letters.filter(\.isUppercase).count) / Double(letters.count)
        if uppercaseRatio > 0.7, line.count < 80 {
            return true
        }

        if line.hasSuffix(":") {
            return true
        }

        return false
    }

    private static func cleanCategoryName(_ line: String) -> String {
        line.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
    }

    private static func isBriefLine(_ line: String) -> Bool {
        if isCategoryHeader(line) { return false }
        let letters = line.filter(\.isLetter)
        guard !letters.isEmpty else { return false }
        let lowercaseRatio = Double(letters.filter(\.isLowercase).count) / Double(letters.count)
        return lowercaseRatio > 0.4
    }

    private static func isLikelyPastedTitle(_ line: String, projectTitle: String?) -> Bool {
        guard let projectTitle, !projectTitle.isEmpty else { return false }

        let normalizedLine = normalize(line)
        let normalizedTitle = normalize(projectTitle)
        if normalizedLine == normalizedTitle { return true }

        let prefixLength = min(16, normalizedTitle.count)
        guard prefixLength >= 8 else { return false }
        return normalizedLine.hasPrefix(String(normalizedTitle.prefix(prefixLength)))
            || normalizedTitle.hasPrefix(String(normalizedLine.prefix(prefixLength)))
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "–", with: "-")
            .replacingOccurrences(of: "—", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}
