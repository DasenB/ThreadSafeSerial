import XCTest
@testable import ThreadSafeSerial

final class ThreadSafeSerialTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(ThreadSafeSerial().text, "Hello, World!")
    }


    static var allTests = [
        ("testExample", testExample),
    ]
}
