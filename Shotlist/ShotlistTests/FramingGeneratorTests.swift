import XCTest
@testable import Shotlist

final class FramingGeneratorTests: XCTestCase {
    func testInfersWideFramingForDroneShot() {
        let shot = Shot(
            title: "Töölöntori – suoraan ylhäältä / lintuperspektiivi",
            categoryID: UUID(),
            shotSize: .wide,
            cameraAngle: .birdsEye
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

    func testDoesNotForceDroneCameraInGenerator() {
        var settings = FramingSettings.default
        settings.camera = .sonyFX3
        settings.useAutoLens = false
        settings.lens = .wide24

        let shot = Shot(title: "Nordis ylhäältä", categoryID: UUID())
        let suggestion = FramingGenerator.suggest(for: shot, settings: settings, categoryName: "DRONE")
        XCTAssertEqual(suggestion.recommendedLens, .wide24)
        XCTAssertEqual(ShotMetadataExtractor.suggestedCamera(categoryName: "DRONE"), .djiMini4Pro)
    }

    func testFrameRateShutterSpeed() {
        var settings = FramingSettings.default
        settings.frameRate = .fps24
        let shot = Shot(title: "Test", categoryID: UUID())
        let suggestion = FramingGenerator.suggest(for: shot, settings: settings)
        XCTAssertEqual(suggestion.shutterSpeed, "1/48s (180°)")
    }

    func testAspectRatioTwoPointThreeNineIsLandscape() {
        XCTAssertGreaterThan(AspectRatio.twoPointThreeNine.widthRatio, AspectRatio.twoPointThreeNine.heightRatio)
        XCTAssertEqual(
            AspectRatio.twoPointThreeNine.widthRatio / AspectRatio.twoPointThreeNine.heightRatio,
            2.39,
            accuracy: 0.001
        )
    }
}

final class RoutePlannerTests: XCTestCase {
    func testCreatesOptimizedRouteForHIFKSample() {
        let project = ShotListParser.parse(SampleData.hifkTooloShotList, projectTitle: "Route Test")
        let plan = RoutePlanner.plan(for: project)

        XCTAssertFalse(plan.stops.isEmpty)
        XCTAssertGreaterThan(plan.totalShootMinutes, 0)
        XCTAssertGreaterThan(plan.totalMinutes, 0)
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

    func testStableStopIdentifiers() {
        let project = ShotListParser.parse(SampleData.hifkTooloShotList, projectTitle: "IDs")
        let plan1 = RoutePlanner.plan(for: project)
        let plan2 = RoutePlanner.plan(for: project)
        XCTAssertEqual(Set(plan1.stops.map(\.id)), Set(plan2.stops.map(\.id)))
    }

    func testIncludesWalkFromStartWhenFirstStopDiffers() {
        let project = ShotListParser.parse(
            """
            NORDIS – MAAN TASALTA
            ☐ Halli edestä
            """,
            projectTitle: "Walk"
        )
        let plan = RoutePlanner.plan(for: project, startLocationKey: "toolontori")
        XCTAssertEqual(plan.stops.count, 1)
        XCTAssertGreaterThan(plan.stops[0].walkMinutesFromPrevious, 0)
    }
}
