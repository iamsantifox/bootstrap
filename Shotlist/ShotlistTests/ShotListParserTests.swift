import XCTest
@testable import Shotlist

final class ShotListParserTests: XCTestCase {
    func testParsesHIFKSampleIntoCategoriesAndShots() {
        let project = ShotListParser.parse(SampleData.hifkTooloShotList, projectTitle: "HIFK Test")

        XCTAssertEqual(project.title, "HIFK Test")
        XCTAssertGreaterThanOrEqual(project.categories.count, 7)
        XCTAssertGreaterThanOrEqual(project.shots.count, 60)
        XCTAssertFalse(project.brief.isEmpty)

        let nordis = project.categories.first { $0.name == "NORDIS – MAAN TASALTA" }
        XCTAssertNotNil(nordis)

        let droneCategory = project.categories.first { $0.name == "DRONE" }
        XCTAssertNotNil(droneCategory)

        let droneShots = project.shots.filter { $0.categoryID == droneCategory?.id }
        XCTAssertGreaterThanOrEqual(droneShots.count, 10)
        XCTAssertTrue(droneShots.contains { $0.title.contains("Töölöntori") })
        XCTAssertEqual(droneShots.first?.cameraAngle, .birdsEye)
    }

    func testParsesCheckboxAndBulletPrefixes() {
        let text = """
        B-ROLL
        ☐ First shot
        - Second shot
        • Third shot
        1. Numbered shot
        """

        let project = ShotListParser.parse(text)
        XCTAssertEqual(project.categories.count, 1)
        XCTAssertEqual(project.shots.count, 4)
    }

    func testParsesMarkdownCheckboxes() {
        let text = """
        B-ROLL
        [ ] Open shot
        [x] Done shot
        [X] Also done
        """

        let project = ShotListParser.parse(text)
        XCTAssertEqual(project.shots.count, 3)
        XCTAssertFalse(project.shots[0].isCompleted)
        XCTAssertTrue(project.shots[1].isCompleted)
        XCTAssertTrue(project.shots[2].isCompleted)
    }

    func testOrphanShotsGoToUncategorized() {
        let text = """
        ☐ Orphan wide
        DRONE
        ☐ Aerial
        """

        let project = ShotListParser.parse(text)
        XCTAssertTrue(project.categories.contains { $0.name == "UNCATEGORIZED" })
        XCTAssertEqual(project.shots.count, 2)
    }

    func testCategoryNamePreservedWithDash() {
        let text = """
        NORDIS – MAAN TASALTA
        ☐ Halli edestä
        """

        let project = ShotListParser.parse(text)
        XCTAssertEqual(project.categories.first?.name, "NORDIS – MAAN TASALTA")
        XCTAssertEqual(project.shots.count, 1)
    }

    func testDoesNotSwallowCategoriesWhenProjectTitleProvided() {
        let text = """
        HIFK-FILMI – B-ROLL / LISÄKUVAT TÖÖLÖ
        Tarvitaan vielä loppuleikkausta varten.
        DRONE
        ☐ Drone shot one
        NORDIS – MAAN TASALTA
        ☐ Halli edestä
        """

        let project = ShotListParser.parse(text, projectTitle: "HIFK Production")
        XCTAssertEqual(project.categories.count, 2)
        XCTAssertEqual(project.categories.map(\.name), ["DRONE", "NORDIS – MAAN TASALTA"])
        XCTAssertEqual(project.shots.count, 2)
        XCTAssertTrue(project.brief.contains("Tarvitaan"))
    }

    func testParsesCompletedCheckbox() {
        let text = """
        B-ROLL
        ☑ Done shot
        ☐ Todo shot
        """

        let project = ShotListParser.parse(text)
        XCTAssertTrue(project.shots.first { $0.title == "Done shot" }?.isCompleted == true)
        XCTAssertFalse(project.shots.first { $0.title == "Todo shot" }?.isCompleted == true)
    }

    func testGroupsVariantShotsAndInheritsLocation() {
        let text = """
        REIJOLANKATU
        ☐ Reijolankadun kulma – wide
        ☐ Medium
        ☐ Close / detail
        """

        let project = ShotListParser.parse(text)
        let root = project.shots.first { $0.title.contains("kulma") }
        XCTAssertNotNil(root)
        XCTAssertEqual(root?.locationKey, "reijolankatu")

        let variants = project.shots.filter { $0.parentShotID == root?.id }
        XCTAssertEqual(variants.count, 2)
        XCTAssertTrue(variants.allSatisfy { $0.locationKey == "reijolankatu" })
        XCTAssertEqual(variants.map(\.shotSize), [.medium, .closeUp])
    }

    func testCategoryProgressCountsAllShots() {
        let project = ShotListParser.parse(
            """
            REIJOLANKATU
            ☐ Corner wide
            ☐ Medium
            ☐ Close / detail
            """,
            projectTitle: "Progress"
        )
        let category = project.categories[0]
        XCTAssertEqual(project.categoryShotCount(category), 3)
        XCTAssertEqual(project.categoryCompletedCount(category), 0)
    }
}

final class LocationExtractorTests: XCTestCase {
    func testTitleMatchBeatsCategoryAmbiguity() {
        let key = LocationExtractor.resolveLocationKey(
            title: "Yliopiston Apteekin kulma – laaja",
            categoryName: "MANNERHEIMINTIE / NORDENSKIÖLDINKATU"
        )
        XCTAssertEqual(key, "mannerheimintie")
    }

    func testNordenskioldTitleMapsCorrectly() {
        let key = LocationExtractor.resolveLocationKey(
            title: "Nordenskiöldinkadun suunta",
            categoryName: "MANNERHEIMINTIE / NORDENSKIÖLDINKATU"
        )
        XCTAssertEqual(key, "nordenskildinkatu")
    }

    func testHalliShotMapsToNordis() {
        let key = LocationExtractor.resolveLocationKey(
            title: "Halli edestä",
            categoryName: "NORDIS – MAAN TASALTA"
        )
        XCTAssertEqual(key, "nordis")
    }

    func testSlashCategoryDefaultsToPrimarySegment() {
        let key = LocationExtractor.resolveLocationKey(
            title: "Liikenne kulkee foregroundissa",
            categoryName: "MANNERHEIMINTIE / NORDENSKIÖLDINKATU"
        )
        XCTAssertEqual(key, "mannerheimintie")
    }

    func testUnknownReturnsUnmapped() {
        let key = LocationExtractor.resolveLocationKey(
            title: "Mystery alley with no landmark",
            categoryName: "RANDOM"
        )
        XCTAssertEqual(key, ShootLocation.unmappedKey)
    }
}
