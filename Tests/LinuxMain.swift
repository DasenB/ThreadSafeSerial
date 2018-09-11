import XCTest

import ThreadSafeSerialTests

var tests = [XCTestCaseEntry]()
tests += ThreadSafeSerialTests.allTests()
XCTMain(tests)