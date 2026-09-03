import XCTest

@testable import TabFinder

final class DomainIconDescriptorTests: XCTestCase {
    func testSameHostUsesSameUppercaseLetterAndHue() {
        let first = DomainIconDescriptor.make(for: "https://github.com/pulls")
        let second = DomainIconDescriptor.make(for: "https://github.com/issues")

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.text, "G")
        XCTAssertNil(first.systemImageName)
        XCTAssertTrue((0..<1).contains(first.hue))
    }

    func testNonWebURLUsesGlobeFallback() {
        let descriptor = DomainIconDescriptor.make(for: "about:blank")

        XCTAssertNil(descriptor.text)
        XCTAssertEqual(descriptor.systemImageName, "globe")
        XCTAssertEqual(descriptor.hue, 0)
    }
}
