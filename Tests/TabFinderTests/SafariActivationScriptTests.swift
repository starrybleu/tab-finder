import XCTest

@testable import TabFinder

final class SafariActivationScriptTests: XCTestCase {
    func testStringExpressionEscapesQuotesBackslashesAndControlCharacters() {
        XCTAssertEqual(
            AppleScriptLiteral.stringExpression(for: "A\"B\\C"),
            "\"A\\\"B\\\\C\""
        )
        XCTAssertEqual(
            AppleScriptLiteral.stringExpression(for: "A\nB"),
            "\"A\" & (character id 10) & \"B\""
        )
    }

    func testActivationVerifiesIdentityAndRestoresMinimizedWindow() {
        let tab = SafariTab(
            windowID: 42,
            tabIndex: 3,
            windowOrder: 2,
            title: "Quoted \"title\"",
            urlString: "https://example.com/path?q=one\\two",
            isCurrentWindow: false,
            isCurrentTab: false
        )

        let source = SafariActivationScript.source(for: tab)

        XCTAssertTrue(source.contains("first window whose id is 42"))
        XCTAssertTrue(source.contains("set targetTab to tab 3 of targetWindow"))
        XCTAssertTrue(source.contains("URL of targetTab as text"))
        XCTAssertTrue(source.contains("name of targetTab as text"))
        XCTAssertTrue(source.contains("considering case"))
        XCTAssertTrue(source.contains("set miniaturized of targetWindow to false"))
        XCTAssertTrue(source.contains("number \(SafariActivationScript.targetChangedErrorNumber)"))
        XCTAssertTrue(source.contains("\\\"title\\\""))
        XCTAssertTrue(source.contains("one\\\\two"))
    }

    func testOnlyDedicatedTargetErrorMapsToTargetChanged() {
        XCTAssertEqual(
            SafariAppleScriptErrorMapper.map(
                number: SafariActivationScript.targetChangedErrorNumber,
                message: SafariActivationScript.targetChangedErrorMessage,
                targetSensitive: true
            ),
            .targetChanged
        )

        XCTAssertEqual(
            SafariAppleScriptErrorMapper.map(
                number: -10_000,
                message: "Apple event handler failed",
                targetSensitive: true
            ),
            .scriptFailure(number: -10_000, message: "Apple event handler failed")
        )
    }
}
