import XCTest
@testable import PwZ

final class PwZTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(PwZ().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
