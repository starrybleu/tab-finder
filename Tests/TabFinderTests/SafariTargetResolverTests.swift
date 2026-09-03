import XCTest

@testable import TabFinder

final class SafariTargetResolverTests: XCTestCase {
    private let target = SafariTab(
        windowID: 4,
        tabIndex: 2,
        windowOrder: 1,
        title: "Example Docs",
        urlString: "https://example.com/docs",
        isCurrentWindow: true,
        isCurrentTab: false
    )

    func testSamePositionAndURLResolvesAfterTitleChanges() throws {
        let renamed = tab(index: 2, title: "Renamed")

        XCTAssertEqual(try SafariTargetResolver.resolve(target, among: [renamed]), renamed)
    }

    func testUniqueSameWindowURLResolvesAfterTabMoves() throws {
        let moved = tab(index: 5)

        XCTAssertEqual(try SafariTargetResolver.resolve(target, among: [moved]), moved)
    }

    func testDuplicateURLsResolveOnlyByUniqueExactTitle() throws {
        let matchingTitle = tab(index: 5)
        let otherTitle = tab(index: 6, title: "Another page")

        XCTAssertEqual(
            try SafariTargetResolver.resolve(target, among: [matchingTitle, otherTitle]),
            matchingTitle
        )
    }

    func testAmbiguousDuplicateURLsThrowTargetChanged() {
        let duplicates = [tab(index: 5), tab(index: 6)]

        XCTAssertThrowsError(try SafariTargetResolver.resolve(target, among: duplicates)) {
            XCTAssertEqual($0 as? SafariAutomationError, .targetChanged)
        }
    }

    func testMissingWindowThrowsTargetChanged() {
        let otherWindow = SafariTab(
            windowID: 9,
            tabIndex: 2,
            windowOrder: 1,
            title: target.title,
            urlString: target.urlString,
            isCurrentWindow: true,
            isCurrentTab: false
        )

        XCTAssertThrowsError(try SafariTargetResolver.resolve(target, among: [otherWindow])) {
            XCTAssertEqual($0 as? SafariAutomationError, .targetChanged)
        }
    }

    private func tab(index: Int, title: String = "Example Docs") -> SafariTab {
        SafariTab(
            windowID: 4,
            tabIndex: index,
            windowOrder: 1,
            title: title,
            urlString: target.urlString,
            isCurrentWindow: true,
            isCurrentTab: false
        )
    }
}
