import XCTest
@testable import Shotlist

final class FramingGeneratorTests: XCTestCase {
    func testInfersWideFramingForDroneShot() {
        let shot = Shot(
            title: "Töölöntori – suoraan ylhäältä / lintuperspektiivi",
            categoryID: UUID(),
            cameraAngle: .birdsEye,
            shotSize: .wide
        )
        let suggestion = FramingGenerator.suggest(for: shot, settings: .default, categoryName: "DRONE")

        XCTAssertEqual(suggestion.framingStyle, .wide)
        XCTAssertEqual(suggestion.horizonPlacement, .none)
    }

    func testRespectsManualLensWhenAutoLensDisabled() {
        var settings = FramingSettings.default
        settings.useAutoLens = false
        settings.lens = .tele200

        let shot = Shot(title: "Laaja establishing", categoryID: UUID(), shotSize: .wide)
        let suggestion = FramingGenerator.suggest(for: shot, settings: settings)
        XCTAssertEqual(suggestion.recommendedLens, .tele200)
    }

    func testAutoSelectsDroneCamera() {
        let shot = Shot(title: "Nordis ylhäältä", categoryID: UUID())
        var settings = FramingSettings.default
        settings.camera = .sonyFX3

        let suggestion = FramingGenerator.suggest(for: shot, settings: settings, categoryName: "DRONE")
        _ = suggestion
        XCTAssertEqual(ShotMetadataExtractor.suggestedCamera(categoryName: "DRONE"), .djiMini4Pro)
    }

    func testFrameRateShutterSpeed() {
        var settings = FramingSettings.default
        settings.frameRate = .fps24
        let shot = Shot(title: "Test", categoryID: UUID())
        let suggestion = FramingGenerator.suggest(for: shot, settings: settings)
        XCTAssertEqual(suggestion.shutterSpeed, "1/48s (180°)")
    }
}

final class RoutePlannerTests: XCTestCase {
    func testCreatesOptimizedRouteForHIFKSample() {
        let project = ShotListParser.parse(SampleData.hifkTooloShotList, projectTitle: "Route Test")
        let plan = RoutePlanner.plan(for: project)

        XCTAssertFalse(plan.stops.isEmpty)
        XCTAssertGreaterThan(plan.totalShootMinutes, 0)
        XCTAssertGreaterThan(plan.totalMinutes, plan.totalShootMinutes)
    }

    func testRouteOrdersWideBeforeClose() {
        let project = ShotListParser.parse(
            """
            REIJOLANKATU
            ☐ Corner wide
            ☐ Medium
            ☐ Close / detail
            """,
            projectTitle: "Variants"
        )
        let plan = RoutePlanner.plan(for: project)
        guard let stop = plan.stops.first else {
            XCTFail("Expected a route stop")
            return
        }
        XCTAssertEqual(stop.shots.first?.shotSize, .wide)
    }
}
