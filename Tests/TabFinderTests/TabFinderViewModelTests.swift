import XCTest

@testable import TabFinder

@MainActor
final class TabFinderViewModelTests: XCTestCase {
    func testLoadingAndQuerySelectsFirstMatchingTab() async {
        let apple = tab(id: 1, title: "Apple", url: "https://apple.com")
        let github = tab(id: 2, title: "GitHub", url: "https://github.com")
        let automation = SafariAutomationStub(tabs: [github, apple])
        let viewModel = TabFinderViewModel(automation: automation)

        await viewModel.load()
        viewModel.query = "apple"

        XCTAssertEqual(viewModel.results, [apple])
        XCTAssertEqual(viewModel.selectedTabID, apple.id)
        XCTAssertEqual(viewModel.state, .loaded)
    }

    func testMovingUpFromFirstResultWrapsToLast() async {
        let first = tab(id: 1, title: "First", url: "https://first.example")
        let last = tab(id: 2, title: "Last", url: "https://last.example")
        let viewModel = TabFinderViewModel(automation: SafariAutomationStub(tabs: [first, last]))

        await viewModel.load()
        viewModel.moveSelection(by: -1)

        XCTAssertEqual(viewModel.selectedTabID, last.id)
    }

    func testSuccessfulActivationReturnsTrueAndSendsSelectedTab() async {
        let selected = tab(id: 7, title: "Selected", url: "https://selected.example")
        let automation = SafariAutomationStub(tabs: [selected])
        let viewModel = TabFinderViewModel(automation: automation)

        await viewModel.load()
        let succeeded = await viewModel.activateSelected()
        let activated = await automation.activatedTabs()

        XCTAssertTrue(succeeded)
        XCTAssertEqual(activated, [selected])
    }

    func testPermissionDeniedMapsToPermissionState() async {
        let automation = SafariAutomationStub(tabs: [], listError: .permissionDenied)
        let viewModel = TabFinderViewModel(automation: automation)

        await viewModel.load()

        XCTAssertEqual(viewModel.state, .permissionDenied)
        XCTAssertTrue(viewModel.results.isEmpty)
        XCTAssertNil(viewModel.selectedTabID)
    }

    private func tab(id: Int, title: String, url: String) -> SafariTab {
        SafariTab(
            windowID: 1,
            tabIndex: id,
            windowOrder: 1,
            title: title,
            urlString: url,
            isCurrentWindow: true,
            isCurrentTab: id == 1
        )
    }
}

private actor SafariAutomationStub: SafariAutomating {
    private let tabs: [SafariTab]
    private let listError: SafariAutomationError?
    private var activated: [SafariTab] = []

    init(tabs: [SafariTab], listError: SafariAutomationError? = nil) {
        self.tabs = tabs
        self.listError = listError
    }

    func listTabs() async throws -> [SafariTab] {
        if let listError { throw listError }
        return tabs
    }

    func activate(_ target: SafariTab) async throws {
        activated.append(target)
    }

    func activatedTabs() -> [SafariTab] {
        activated
    }
}
