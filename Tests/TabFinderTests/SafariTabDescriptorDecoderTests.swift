import AppKit
import XCTest

@testable import TabFinder

final class SafariTabDescriptorDecoderTests: XCTestCase {
    func testDecodesValidRowsAndSkipsRowsWithoutURL() throws {
        let descriptor = list([
            row(windowID: 42, tabIndex: 3, windowOrder: 1, title: "Apple", url: "https://apple.com", currentTabIndex: 3),
            row(windowID: 42, tabIndex: 4, windowOrder: 1, title: "Blank", url: "", currentTabIndex: 3),
        ])

        XCTAssertEqual(
            try SafariTabDescriptorDecoder.decode(descriptor),
            [
                SafariTab(
                    windowID: 42,
                    tabIndex: 3,
                    windowOrder: 1,
                    title: "Apple",
                    urlString: "https://apple.com",
                    isCurrentWindow: true,
                    isCurrentTab: true
                ),
            ]
        )
    }

    func testUsesURLWhenTitleIsEmpty() throws {
        let descriptor = list([
            row(windowID: 8, tabIndex: 1, windowOrder: 2, title: "", url: "https://example.com", currentTabIndex: 4),
        ])

        XCTAssertEqual(try SafariTabDescriptorDecoder.decode(descriptor).first?.title, "https://example.com")
    }

    func testEmptyListDecodesToEmptyArray() throws {
        XCTAssertEqual(try SafariTabDescriptorDecoder.decode(NSAppleEventDescriptor.list()), [])
    }

    func testNonListOuterDescriptorThrowsMalformedResponse() {
        let descriptor = NSAppleEventDescriptor(string: "not a list")
        XCTAssertThrowsError(try SafariTabDescriptorDecoder.decode(descriptor)) {
            XCTAssertEqual($0 as? SafariAutomationError, .malformedResponse)
        }
    }

    private func row(
        windowID: Int32,
        tabIndex: Int32,
        windowOrder: Int32,
        title: String,
        url: String,
        currentTabIndex: Int32
    ) -> NSAppleEventDescriptor {
        list([
            NSAppleEventDescriptor(int32: windowID),
            NSAppleEventDescriptor(int32: tabIndex),
            NSAppleEventDescriptor(int32: windowOrder),
            NSAppleEventDescriptor(string: title),
            NSAppleEventDescriptor(string: url),
            NSAppleEventDescriptor(int32: currentTabIndex),
        ])
    }

    private func list(_ values: [NSAppleEventDescriptor]) -> NSAppleEventDescriptor {
        let descriptor = NSAppleEventDescriptor.list()
        for (offset, value) in values.enumerated() {
            descriptor.insert(value, at: offset + 1)
        }
        return descriptor
    }
}
