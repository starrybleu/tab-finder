import AppKit
import XCTest

@testable import TabFinder

@MainActor
final class ApplicationMenuFactoryTests: XCTestCase {
    func testEditMenuRoutesCommandAToFirstResponderSelectAll() throws {
        let mainMenu = ApplicationMenuFactory.make()
        let editMenu = try XCTUnwrap(
            mainMenu.items.compactMap(\.submenu).first(where: { $0.title == "편집" })
        )
        let selectAll = try XCTUnwrap(
            editMenu.items.first(where: { $0.action == #selector(NSText.selectAll(_:)) })
        )

        XCTAssertNil(selectAll.target)
        XCTAssertEqual(selectAll.keyEquivalent, "a")
        XCTAssertEqual(selectAll.keyEquivalentModifierMask, [.command])
    }
}
