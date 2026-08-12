import XCTest
@testable import Shotlist

final class ShotListParserTests: XCTestCase {
    func testParsesHIFKSampleIntoCategoriesAndShots() {
        let project = ShotListParser.parse(SampleData.hifkTooloShotList, projectTitle: "HIFK Test")

        XCTAssertEqual(project.title, "HIFK Test")
        XCTAssertGreaterThanOrEqual(project.categories.count, 7)
        XCTAssertGreaterThanOrEqual(project.shots.count, 60)

        let droneCategory = project.categories.first { $0.name == "DRONE" }
        XCTAssertNotNil(droneCategory)

        let droneShots = project.shots.filter { $0.categoryID == droneCategory?.id }
        XCTAssertGreaterThanOrEqual(droneShots.count, 10)
        XCTAssertTrue(droneShots.contains { $0.title.contains("Töölöntori") })
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

    func testCategoryHeaderWithDescription() {
        let text = """
        NORDIS – MAAN TASALTA
        ☐ Halli edestä
        """

        let project = ShotListParser.parse(text)
        XCTAssertEqual(project.categories.first?.name, "NORDIS – MAAN TASALTA")
        XCTAssertEqual(project.shots.count, 1)
    }
}
