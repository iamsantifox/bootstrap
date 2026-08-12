import XCTest
@testable import Shotlist

final class FramingGeneratorTests: XCTestCase {
    func testInfersWideFramingForDroneShot() {
        let shot = Shot(title: "Töölöntori – suoraan ylhäältä / lintuperspektiivi", categoryID: UUID())
        let suggestion = FramingGenerator.suggest(for: shot, settings: .default)

        XCTAssertEqual(suggestion.framingStyle, .wide)
        XCTAssertEqual(suggestion.horizonPlacement, .none)
    }

    func testInfersDetailFramingForCloseUp() {
        let shot = Shot(title: "Tarrasta todella tiukka close-up", categoryID: UUID())
        let suggestion = FramingGenerator.suggest(for: shot, settings: .default)

        XCTAssertEqual(suggestion.framingStyle, .detail)
    }

    func testNightExposureSettings() {
        let shot = Shot(title: "Liikennevalot", categoryID: UUID())
        var settings = FramingSettings.default
        settings.timeOfDay = .night
        settings.weather = .sunny

        let suggestion = FramingGenerator.suggest(for: shot, settings: settings)
        XCTAssertTrue(suggestion.iso.contains("1600") || suggestion.iso.contains("6400"))
    }

    func testDroneCameraLimitsLensOptions() {
        var settings = FramingSettings.default
        settings.camera = .djiMini4Pro

        let lenses = LensOption.availableLenses(for: settings.camera)
        XCTAssertTrue(lenses.contains(.droneWide))
        XCTAssertFalse(lenses.contains(.macro100))
    }
}
