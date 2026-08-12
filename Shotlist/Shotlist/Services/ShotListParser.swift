import Foundation

enum ShotListParser {
    private static let checkboxPrefixes = ["☐", "☑", "✓", "✔", "-", "•", "*", "–", "—"]

    static func parse(_ text: String, projectTitle: String? = nil) -> ShotListProject {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var categories: [ShotCategory] = []
        var shots: [Shot] = []
        var currentCategory: ShotCategory?
        var categoryOrder = 0
        var inferredTitle = projectTitle
        var hasSeenCategory = false

        for line in lines where !line.isEmpty {
            if let shotTitle = extractShotTitle(from: line) {
                guard let category = currentCategory else { continue }
                shots.append(Shot(title: shotTitle, categoryID: category.id))
                continue
            }

            if inferredTitle == nil, !hasSeenCategory {
                inferredTitle = line
                continue
            }

            if isCategoryHeader(line) {
                let (name, description) = splitCategoryHeader(line)
                let category = ShotCategory(name: name, description: description, sortOrder: categoryOrder)
                categoryOrder += 1
                categories.append(category)
                currentCategory = category
                hasSeenCategory = true
                continue
            }

            if !hasSeenCategory {
                continue
            }
        }

        return ShotListProject(
            title: inferredTitle ?? "Shot List",
            categories: categories,
            shots: shots
        )
    }

    private static func extractShotTitle(from line: String) -> String? {
        for prefix in checkboxPrefixes {
            if line.hasPrefix(prefix) {
                let title = String(line.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespaces)
                return title.isEmpty ? nil : title
            }
        }

        if let match = line.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
            let title = String(line[match.upperBound...]).trimmingCharacters(in: .whitespaces)
            return title.isEmpty ? nil : title
        }

        return nil
    }

    private static func isCategoryHeader(_ line: String) -> Bool {
        if extractShotTitle(from: line) != nil {
            return false
        }

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

    private static func splitCategoryHeader(_ line: String) -> (String, String) {
        let cleaned = line.trimmingCharacters(in: CharacterSet(charactersIn: ":"))
        if let dashRange = cleaned.range(of: " – ") ?? cleaned.range(of: " - ") {
            let name = String(cleaned[..<dashRange.lowerBound]).trimmingCharacters(in: .whitespaces)
            let description = String(cleaned[dashRange.upperBound...]).trimmingCharacters(in: .whitespaces)
            return (name, description)
        }
        return (cleaned, "")
    }

}
