import XCTest
@testable import mDESKCore

final class BrandTests: XCTestCase {
    func testNameFollowsSocleRule() {
        // tout en majuscules sauf une seule lettre minuscule : le « m »
        XCTAssertEqual(Brand.name, "mDESK")
        XCTAssertEqual(Brand.name.filter(\.isLowercase), "m")
    }

    func testColoursTheLowercaseLetterOfEveryOccurrence() {
        let text = "Quitter mDESK — à l'ouverture de mDESK"
        let ranges = Brand.lowercaseRanges(in: text)
        XCTAssertEqual(ranges.count, 2)
        for range in ranges { XCTAssertEqual((text as NSString).substring(with: range), "m") }
    }

    func testIgnoresNameInsideWordPathOrIdentifier() {
        XCTAssertTrue(Brand.lowercaseRanges(in: "/Applications/mDESK.app").isEmpty)
        XCTAssertTrue(Brand.lowercaseRanges(in: "mDESKCore").isEmpty)
        XCTAssertTrue(Brand.lowercaseRanges(in: "com.mDESK").isEmpty)
        XCTAssertTrue(Brand.lowercaseRanges(in: "Desk Stay, DESKSTAY, DeskStay, MDESK").isEmpty)
        XCTAssertEqual(Brand.lowercaseRanges(in: "(mDESK)").count, 1)
    }
}
