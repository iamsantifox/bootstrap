import Foundation

enum ShotMetadataExtractor {
    private static let variantTitles: Set<String> = [
        "medium", "close / detail", "close", "wide", "detail",
        "tiukempana", "laaja", "keski",
    ]

    static func isVariantTitle(_ title: String) -> Bool {
        variantTitles.contains(title.lowercased().trimmingCharacters(in: .whitespaces))
    }

    static func shotSize(from title: String, categoryName: String) -> ShotSize {
        let lower = title.lowercased()

        if lower.contains("establishing") || lower.contains("todella laaja") { return .extremeWide }
        if lower.contains("extreme wide") || lower == "ews" { return .extremeWide }
        if lower.contains("close-up") || lower.contains("close up") || lower.contains("close /") || lower == "close" { return .closeUp }
        if lower.contains("tiukka") || lower.contains("tiukemp") || lower.contains("ecu") { return .extremeCloseUp }
        if lower.contains("lähikuva") || lower.contains("detail") || lower == "detail" { return .detail }
        if lower.contains("laaja") || lower.contains("wide") || lower == "wide" { return .wide }
        if lower.contains("medium") || lower == "medium" || lower.contains("keski") { return .medium }

        if categoryName.uppercased().contains("DRONE") { return .wide }
        return .unknown
    }

    static func cameraAngle(from title: String, categoryName: String) -> CameraAngle {
        let lower = title.lowercased()

        if lower.contains("ylhäältä") || lower.contains("lintuperspektiivi") || lower.contains("bird") {
            return .birdsEye
        }
        if lower.contains("matalasta") || lower.contains("low angle") { return .low }
        if categoryName.uppercased().contains("DRONE") { return .birdsEye }
        if lower.contains("ylöspäin") || lower.contains("julkisivuja") { return .low }
        if lower.contains("sivusta") || lower.contains("edestä") { return .eyeLevel }

        return .unknown
    }

    static func locationKey(from title: String, categoryName: String) -> String? {
        LocationExtractor.resolveLocationKey(title: title, categoryName: categoryName)
    }

    static func suggestedCamera(categoryName: String) -> CameraBody? {
        if categoryName.uppercased().contains("DRONE") {
            return .djiMini4Pro
        }
        return nil
    }
}
