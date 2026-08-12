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

    func testCategoryNamePreservedWithDash() {
        let text = """
        NORDIS – MAAN TASALTA
        ☐ Halli edestä
        """

        let project = ShotListParser.parse(text)
        XCTAssertEqual(project.categories.first?.name, "NORDIS – MAAN TASALTA")
        XCTAssertEqual(project.shots.count, 1)
    }

    func testSkipsDuplicateTitleWhenProjectTitleProvided() {
        let text = """
        HIFK-FILMI – B-ROLL / LISÄKUVAT TÖÖLÖ
        DRONE
        ☐ Drone shot one
        """

        let project = ShotListParser.parse(text, projectTitle: "HIFK Production")
        XCTAssertEqual(project.categories.count, 1)
        XCTAssertEqual(project.categories.first?.name, "DRONE")
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

    func testGroupsVariantShots() {
        let text = """
        REIJOLANKATU
        ☐ Reijolankadun kulma – wide
        ☐ Medium
        ☐ Close / detail
        """

        let project = ShotListParser.parse(text)
        let root = project.shots.first { $0.title.contains("kulma") }
        XCTAssertNotNil(root)
        let variants = project.shots.filter { $0.parentShotID == root?.id }
        XCTAssertEqual(variants.count, 2)
    }
}
