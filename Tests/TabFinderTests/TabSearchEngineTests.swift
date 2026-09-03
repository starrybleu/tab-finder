import XCTest

@testable import TabFinder

final class TabSearchEngineTests: XCTestCase {
    private let tabs = [
        SafariTab(
            windowID: 8,
            tabIndex: 1,
            windowOrder: 1,
            title: "GitHub Pull Requests",
            urlString: "https://github.com/pulls",
            isCurrentWindow: true,
            isCurrentTab: true
        ),
        SafariTab(
            windowID: 8,
            tabIndex: 2,
            windowOrder: 1,
            title: "Search",
            urlString: "https://google.com/search?q=github",
            isCurrentWindow: true,
            isCurrentTab: false
        ),
        SafariTab(
            windowID: 12,
            tabIndex: 1,
            windowOrder: 2,
            title: "Apple",
            urlString: "https://apple.com",
            isCurrentWindow: false,
            isCurrentTab: true
        ),
    ]

    func testTitleMatchRanksAboveURLMatch() {
        XCTAssertEqual(
            TabSearchEngine().results(for: "github", in: tabs).map(\.title),
            ["GitHub Pull Requests", "Search"]
        )
    }

    func testMultipleTokensUseANDSemantics() {
        XCTAssertEqual(
            TabSearchEngine().results(for: "github pull", in: tabs).map(\.title),
            ["GitHub Pull Requests"]
        )
    }

    func testEmptyQueryPreservesWindowAndTabOrder() {
        XCTAssertEqual(
            TabSearchEngine().results(for: "", in: tabs).map(\.title),
            ["GitHub Pull Requests", "Search", "Apple"]
        )
    }

    func testMatchingIgnoresCaseDiacriticsAndWidth() {
        let tab = SafariTab(
            windowID: 2,
            tabIndex: 1,
            windowOrder: 1,
            title: "Café Ｗork",
            urlString: "https://example.com",
            isCurrentWindow: true,
            isCurrentTab: true
        )

        XCTAssertEqual(TabSearchEngine().results(for: "CAFE work", in: [tab]), [tab])
    }
}
