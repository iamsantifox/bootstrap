import Foundation

enum CameraBody: String, CaseIterable, Identifiable, Codable {
    case sonyFX3 = "Sony FX3"
    case sonyA7SIII = "Sony A7S III"
    case canonR5C = "Canon R5 C"
    case blackmagicPocket6K = "Blackmagic Pocket 6K"
    case redKomodo = "RED Komodo"
    case iphone15Pro = "iPhone 15 Pro"
    case djiMini4Pro = "DJI Mini 4 Pro (Drone)"

    var id: String { rawValue }

    var sensorSize: SensorSize {
        switch self {
        case .sonyFX3, .sonyA7SIII:
            return .fullFrame
        case .canonR5C:
            return .fullFrame
        case .blackmagicPocket6K:
            return .super35
        case .redKomodo:
            return .super35
        case .iphone15Pro:
            return .phone
        case .djiMini4Pro:
            return .drone
        }
    }

    var cropFactor: Double {
        sensorSize.cropFactor
    }
}

enum SensorSize: String, Codable {
    case fullFrame
    case super35
    case phone
    case drone

    var cropFactor: Double {
        switch self {
        case .fullFrame: return 1.0
        case .super35: return 1.5
        case .phone: return 5.6
        case .drone: return 5.0
        }
    }
}

enum LensOption: String, CaseIterable, Identifiable, Codable {
    case ultraWide14 = "14mm Ultra Wide"
    case wide24 = "24mm Wide"
    case standard35 = "35mm Standard"
    case normal50 = "50mm Normal"
    case portrait85 = "85mm Portrait"
    case tele135 = "135mm Telephoto"
    case tele200 = "200mm Telephoto"
    case macro100 = "100mm Macro"
    case droneWide = "Drone Wide (24mm eq.)"
    case phoneWide = "Phone Wide (24mm eq.)"
    case phoneTele = "Phone Tele (77mm eq.)"

    var id: String { rawValue }

    var focalLengthMM: Double {
        switch self {
        case .ultraWide14: return 14
        case .wide24: return 24
        case .standard35: return 35
        case .normal50: return 50
        case .portrait85: return 85
        case .tele135: return 135
        case .tele200: return 200
        case .macro100: return 100
        case .droneWide: return 24
        case .phoneWide: return 24
        case .phoneTele: return 77
        }
    }

    var framingStyle: FramingStyle {
        switch self {
        case .ultraWide14, .wide24, .droneWide, .phoneWide:
            return .wide
        case .standard35, .normal50:
            return .medium
        case .portrait85, .tele135, .tele200, .phoneTele:
            return .tight
        case .macro100:
            return .detail
        }
    }

    static func availableLenses(for camera: CameraBody) -> [LensOption] {
        switch camera {
        case .djiMini4Pro:
            return [.droneWide]
        case .iphone15Pro:
            return [.phoneWide, .phoneTele]
        default:
            return [.ultraWide14, .wide24, .standard35, .normal50, .portrait85, .tele135, .tele200, .macro100]
        }
    }
}

enum FramingStyle: String, Codable {
    case wide
    case medium
    case tight
    case detail

    var displayName: String {
        switch self {
        case .wide: return "Wide / Establishing"
        case .medium: return "Medium"
        case .tight: return "Tight / Close"
        case .detail: return "Detail / Macro"
        }
    }
}

enum FrameRate: Int, CaseIterable, Identifiable, Codable {
    case fps24 = 24
    case fps25 = 25
    case fps30 = 30
    case fps50 = 50
    case fps60 = 60

    var id: Int { rawValue }

    var displayName: String { "\(rawValue) fps" }

    var shutterSpeed: String {
        let denominator = rawValue * 2
        return "1/\(denominator)s (180°)"
    }
}

enum AspectRatio: String, CaseIterable, Identifiable, Codable {
    case sixteenByNine = "16:9"
    case seventeenByNine = "17:9"
    case fourByThree = "4:3"
    case twoPointThreeNine = "2.39:1"

    var id: String { rawValue }

    var widthRatio: Double {
        switch self {
        case .sixteenByNine: return 16
        case .seventeenByNine: return 17
        case .fourByThree: return 4
        case .twoPointThreeNine: return 2.39
        }
    }

    var heightRatio: Double {
        switch self {
        case .sixteenByNine, .seventeenByNine: return 9
        case .fourByThree: return 3
        case .twoPointThreeNine: return 1
        }
    }
}

enum TimeOfDay: String, CaseIterable, Identifiable, Codable {
    case goldenHour = "Golden Hour"
    case blueHour = "Blue Hour"
    case midday = "Midday"
    case overcastDay = "Overcast Day"
    case night = "Night"
    case dawn = "Dawn"

    var id: String { rawValue }

    var lightQuality: String {
        switch self {
        case .goldenHour: return "Warm, directional, long shadows"
        case .blueHour: return "Cool, soft, even ambient"
        case .midday: return "Harsh, overhead, high contrast"
        case .overcastDay: return "Soft, diffused, low contrast"
        case .night: return "Low light, artificial sources"
        case .dawn: return "Cool-to-warm transition, mist possible"
        }
    }
}

enum WeatherCondition: String, CaseIterable, Identifiable, Codable {
    case sunny = "Sunny"
    case partlyCloudy = "Partly Cloudy"
    case overcast = "Overcast"
    case rain = "Rain"
    case snow = "Snow"
    case fog = "Fog"

    var id: String { rawValue }

    var atmosphereNote: String {
        switch self {
        case .sunny: return "Clear skies, strong highlights"
        case .partlyCloudy: return "Dynamic clouds, shifting light"
        case .overcast: return "Even light, muted colors"
        case .rain: return "Wet surfaces, reflections, mood"
        case .snow: return "Bright, high key, clean textures"
        case .fog: return "Depth layers, mystery, soft edges"
        }
    }
}

struct FramingSettings: Codable, Equatable {
    var camera: CameraBody
    var lens: LensOption
    var timeOfDay: TimeOfDay
    var weather: WeatherCondition
    var frameRate: FrameRate
    var aspectRatio: AspectRatio
    var useAutoLens: Bool

    static let `default` = FramingSettings(
        camera: .sonyFX3,
        lens: .wide24,
        timeOfDay: .goldenHour,
        weather: .partlyCloudy,
        frameRate: .fps25,
        aspectRatio: .sixteenByNine,
        useAutoLens: true
    )

    enum CodingKeys: String, CodingKey {
        case camera, lens, timeOfDay, weather, frameRate, aspectRatio, useAutoLens
    }

    init(
        camera: CameraBody,
        lens: LensOption,
        timeOfDay: TimeOfDay,
        weather: WeatherCondition,
        frameRate: FrameRate = .fps25,
        aspectRatio: AspectRatio = .sixteenByNine,
        useAutoLens: Bool = true
    ) {
        self.camera = camera
        self.lens = lens
        self.timeOfDay = timeOfDay
        self.weather = weather
        self.frameRate = frameRate
        self.aspectRatio = aspectRatio
        self.useAutoLens = useAutoLens
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        camera = try container.decode(CameraBody.self, forKey: .camera)
        lens = try container.decode(LensOption.self, forKey: .lens)
        timeOfDay = try container.decode(TimeOfDay.self, forKey: .timeOfDay)
        weather = try container.decode(WeatherCondition.self, forKey: .weather)
        frameRate = try container.decodeIfPresent(FrameRate.self, forKey: .frameRate) ?? .fps25
        aspectRatio = try container.decodeIfPresent(AspectRatio.self, forKey: .aspectRatio) ?? .sixteenByNine
        useAutoLens = try container.decodeIfPresent(Bool.self, forKey: .useAutoLens) ?? true
    }
}

struct FramingSuggestion: Equatable {
    let recommendedLens: LensOption
    let effectiveFocalLength: String
    let aperture: String
    let shutterSpeed: String
    let iso: String
    let ndFilter: String?
    let compositionNotes: [String]
    let framingStyle: FramingStyle
    let horizonPlacement: HorizonPlacement
    let subjectPlacement: SubjectPlacement
    let movementSuggestion: String
    let lightingNotes: String
}

enum HorizonPlacement: String, Codable {
    case low = "Low horizon (⅓ from bottom)"
    case center = "Center horizon"
    case high = "High horizon (⅓ from top)"
    case none = "No visible horizon"
}

enum SubjectPlacement: String, Codable {
    case center = "Center"
    case ruleOfThirdsLeft = "Left third"
    case ruleOfThirdsRight = "Right third"
    case foregroundLeft = "Foreground left"
    case foregroundRight = "Foreground right"
    case leadingLines = "Along leading lines"
}
