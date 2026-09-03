import AppKit
import XCTest

@testable import TabFinder

final class AppMetadataTests: XCTestCase {
    func testConstantsDescribeTheBuiltApplication() {
        XCTAssertEqual(AppMetadata.displayName, "Tab Finder")
        XCTAssertEqual(AppMetadata.bundleIdentifier, "com.hanbyullee.TabFinder")
        XCTAssertEqual(AppMetadata.popoverSize, NSSize(width: 400, height: 520))
    }
}
