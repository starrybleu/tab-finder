import XCTest

@testable import TabFinder

final class PopoverPresentationStateTests: XCTestCase {
    func testToggleAndEscapeTransitions() {
        var state = PopoverPresentationState()

        XCTAssertFalse(state.isShown)
        state.toggle()
        XCTAssertTrue(state.isShown)
        state.escape()
        XCTAssertFalse(state.isShown)
    }

    func testExplicitShowAndHideAreIdempotent() {
        var state = PopoverPresentationState()

        state.show()
        state.show()
        XCTAssertTrue(state.isShown)
        state.hide()
        state.hide()
        XCTAssertFalse(state.isShown)
    }
}
