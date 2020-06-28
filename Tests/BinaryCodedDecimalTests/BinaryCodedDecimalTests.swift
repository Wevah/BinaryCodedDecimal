import XCTest
@testable import BinaryCodedDecimal

final class BinaryCodedDecimalTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(BinaryCodedDecimal().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
