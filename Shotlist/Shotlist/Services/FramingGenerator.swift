import Foundation

enum FramingGenerator {
    static func suggest(for shot: Shot, settings: FramingSettings, categoryName: String = "") -> FramingSuggestion {
        var effectiveSettings = settings
        if let suggestedCamera = ShotMetadataExtractor.suggestedCamera(categoryName: categoryName) {
            effectiveSettings.camera = suggestedCamera
            let available = LensOption.availableLenses(for: suggestedCamera)
            if !available.contains(effectiveSettings.lens) {
                effectiveSettings.lens = available[0]
            }
        }

        let inferredStyle = inferFramingStyle(from: shot.title, shotSize: shot.shotSize)
        let lens = effectiveSettings.useAutoLens
            ? selectLens(for: inferredStyle, settings: effectiveSettings)
            : effectiveSettings.lens
        let effectiveFL = effectiveFocalLength(lens: lens, camera: effectiveSettings.camera)
        let exposure = exposureSettings(
            timeOfDay: effectiveSettings.timeOfDay,
            weather: effectiveSettings.weather,
            frameRate: effectiveSettings.frameRate
        )
        let composition = compositionNotes(for: shot.title, style: inferredStyle, settings: effectiveSettings)
        let horizon = horizonPlacement(for: shot.title, style: inferredStyle, angle: shot.cameraAngle)
        let subject = subjectPlacement(for: shot.title, style: inferredStyle)
        let movement = movementSuggestion(for: shot.title, lens: lens)
        let lighting = lightingNotes(timeOfDay: effectiveSettings.timeOfDay, weather: effectiveSettings.weather, shot: shot.title)

        return FramingSuggestion(
            recommendedLens: lens,
            effectiveFocalLength: effectiveFL,
            aperture: exposure.aperture,
            shutterSpeed: effectiveSettings.frameRate.shutterSpeed,
            iso: exposure.iso,
            ndFilter: exposure.nd,
            compositionNotes: composition,
            framingStyle: inferredStyle,
            horizonPlacement: horizon,
            subjectPlacement: subject,
            movementSuggestion: movement,
            lightingNotes: lighting
        )
    }

    private static func inferFramingStyle(from title: String, shotSize: ShotSize) -> FramingStyle {
        switch shotSize {
        case .extremeWide, .wide: return .wide
        case .medium: return .medium
        case .closeUp, .extremeCloseUp: return .tight
        case .detail: return .detail
        case .unknown: break
        }

        let lower = title.lowercased()

        let detailKeywords = ["close-up", "close up", "close /", "tiukka", "lähikuva", "yksityiskohta", "teksti", "kengät", "jalat"]
        let wideKeywords = ["laaja", "wide", "establishing", "ympäristö", "lintuperspektiivi", "ylhäältä", "bird", "overview", "samassa kuvassa"]
        let tightKeywords = ["tiukemp", "tighter", "tele", "foreground", "sivusta", "edestä"]

        if detailKeywords.contains(where: { lower.contains($0) }) { return .detail }
        if wideKeywords.contains(where: { lower.contains($0) }) { return .wide }
        if tightKeywords.contains(where: { lower.contains($0) }) { return .tight }
        if lower.contains("medium") || lower.contains("keski") { return .medium }

        return .medium
    }

    private static func selectLens(for style: FramingStyle, settings: FramingSettings) -> LensOption {
        let available = LensOption.availableLenses(for: settings.camera)

        return switch style {
        case .wide:
            available.first { $0.framingStyle == .wide } ?? .wide24
        case .medium:
            available.first { $0.framingStyle == .medium } ?? .standard35
        case .tight:
            available.first { $0.framingStyle == .tight } ?? .portrait85
        case .detail:
            available.contains(.macro100) ? .macro100 : (available.last ?? settings.lens)
        }
    }

    private static func effectiveFocalLength(lens: LensOption, camera: CameraBody) -> String {
        if camera == .djiMini4Pro || camera == .iphone15Pro {
            return lens.rawValue
        }
        let effective = Int(lens.focalLengthMM * camera.cropFactor)
        if camera.cropFactor == 1.0 {
            return "\(Int(lens.focalLengthMM))mm"
        }
        return "\(Int(lens.focalLengthMM))mm (\(effective)mm equiv.)"
    }

    private static func exposureSettings(
        timeOfDay: TimeOfDay,
        weather: WeatherCondition,
        frameRate: FrameRate
    ) -> (aperture: String, iso: String, nd: String?) {
        let base: (String, String, String?) = switch (timeOfDay, weather) {
        case (.goldenHour, .sunny):
            ("f/4 – f/5.6", "100–200", "ND 0.6 optional")
        case (.goldenHour, _):
            ("f/2.8 – f/4", "200–400", nil)
        case (.blueHour, _):
            ("f/2 – f/2.8", "800–1600", nil)
        case (.midday, .sunny):
            ("f/5.6 – f/8", "100", "ND 1.2 – ND 1.8")
        case (.midday, _):
            ("f/4 – f/5.6", "200–400", "ND 0.6")
        case (.overcastDay, _), (_, .overcast):
            ("f/2.8 – f/4", "400–800", nil)
        case (.night, _):
            ("f/1.4 – f/2", "1600–6400", nil)
        case (.dawn, .fog), (_, .fog):
            ("f/2.8 – f/4", "400–800", nil)
        case (_, .rain):
            ("f/2.8 – f/4", "400–800", nil)
        case (_, .snow):
            ("f/5.6 – f/8", "100–200", "ND 0.3 – ND 0.6")
        default:
            ("f/4", "400", nil)
        }
        _ = frameRate
        return base
    }

    private static func compositionNotes(for title: String, style: FramingStyle, settings: FramingSettings) -> [String] {
        var notes: [String] = []
        let lower = title.lowercased()

        notes.append("Framing style: \(style.displayName)")
        notes.append("Aspect ratio: \(settings.aspectRatio.rawValue)")

        if lower.contains("drone") || lower.contains("ylhäältä") || lower.contains("lintu") {
            notes.append("Top-down: keep subject near intersection of thirds")
            notes.append("Watch for shadow direction at \(settings.timeOfDay.rawValue.lowercased())")
        }

        if lower.contains("liikenne") || lower.contains("traffic") || lower.contains("ratikka") {
            notes.append("Leave space in direction of movement")
            notes.append("Use shutter drag for motion streaks if desired")
        }

        if lower.contains("foreground") || lower.contains("läpi") {
            notes.append("Place foreground element in lower third, subject in background")
        }

        if lower.contains("valo vaihtuu") || lower.contains("liikennevalo") {
            notes.append("Expose for the light transition moment; allow 2–3 cycles")
        } else if lower.contains("valo") || lower.contains("light") {
            notes.append("Expose for the light source transition moment")
        }

        if lower.contains("heijast") || lower.contains("peili") {
            notes.append("Angle camera to catch reflections without flare")
        }

        if style == .wide {
            notes.append("Include environmental context and depth layers")
        } else if style == .detail {
            notes.append("Fill frame with subject; minimal dead space")
        }

        if notes.count <= 2 {
            notes.append("Use rule of thirds; balance foreground and background")
        }

        return notes
    }

    private static func horizonPlacement(for title: String, style: FramingStyle, angle: CameraAngle) -> HorizonPlacement {
        if angle == .birdsEye { return .none }

        let lower = title.lowercased()
        if lower.contains("ylhäältä") || lower.contains("drone") || lower.contains("lintu") {
            return .none
        }
        if lower.contains("taivasta") || lower.contains("johdot") || lower.contains("julkisivuja ylöspäin") {
            return .low
        }
        if lower.contains("matalasta") || angle == .low {
            return .low
        }
        if style == .detail {
            return .none
        }
        return style == .wide ? .center : .low
    }

    private static func subjectPlacement(for title: String, style: FramingStyle) -> SubjectPlacement {
        let lower = title.lowercased()
        if lower.contains("kulma") || lower.contains("corner") {
            return .ruleOfThirdsLeft
        }
        if lower.contains("foreground") {
            return .foregroundLeft
        }
        if lower.contains("liikenne") || lower.contains("ratikka") {
            return .leadingLines
        }
        if style == .detail {
            return .center
        }
        return .ruleOfThirdsLeft
    }

    private static func movementSuggestion(for title: String, lens: LensOption) -> String {
        let lower = title.lowercased()
        if lower.contains("hidas lähestyminen") || lower.contains("slow approach") {
            return "Slow dolly or drone push-in toward subject"
        }
        if lower.contains("liike") || lower.contains("liikkeessä") || lower.contains("traffic") {
            return "Static camera; let subject move through frame"
        }
        if lens.framingStyle == .wide {
            return "Subtle pan or slow reveal to add energy"
        }
        return "Static tripod shot for consistency"
    }

    private static func lightingNotes(timeOfDay: TimeOfDay, weather: WeatherCondition, shot: String) -> String {
        var parts = [timeOfDay.lightQuality, weather.atmosphereNote]
        let lower = shot.lowercased()
        if lower.contains("yö") || lower.contains("night") || lower.contains("valo vaihtuu") {
            parts.append("Time the shot for the light change moment")
        }
        return parts.joined(separator: ". ") + "."
    }
}
