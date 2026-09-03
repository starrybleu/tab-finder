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

    func testChangedTargetReloadsWithoutClearingQuery() async {
        let selected = tab(id: 4, title: "Fixture tab", url: "https://fixture.example")
        let automation = SafariAutomationStub(
            tabs: [selected],
            activationError: .targetChanged
        )
        let viewModel = TabFinderViewModel(automation: automation)

        await viewModel.load()
        viewModel.query = "fixture"
        let succeeded = await viewModel.activateSelected()
        let listCallCount = await automation.listCallCount()

        XCTAssertFalse(succeeded)
        XCTAssertEqual(viewModel.query, "fixture")
        XCTAssertEqual(listCallCount, 2)
        XCTAssertEqual(viewModel.notice, "That tab changed or closed. The list has been refreshed.")
    }

    func testActivationIsDisabledWhileRefreshing() async {
        let selected = tab(id: 9, title: "Previous", url: "https://previous.example")
        let automation = SafariAutomationStub(tabs: [selected])
        let viewModel = TabFinderViewModel(automation: automation)

        await viewModel.load()
        await automation.setListDelay(nanoseconds: 100_000_000)
        let refresh = Task { await viewModel.load() }
        await Task.yield()

        let succeeded = await viewModel.activateSelected()
        XCTAssertEqual(viewModel.state, .loading)
        XCTAssertFalse(succeeded)
        XCTAssertTrue(viewModel.results.isEmpty)

        await refresh.value
    }

    func testChangedTargetDoesNotClaimRefreshWhenReloadFails() async {
        let selected = tab(id: 5, title: "Fixture", url: "https://fixture.example")
        let automation = SafariAutomationStub(
            tabs: [selected],
            activationError: .targetChanged,
            listErrorsByCall: [2: .permissionDenied]
        )
        let viewModel = TabFinderViewModel(automation: automation)

        await viewModel.load()
        _ = await viewModel.activateSelected()

        XCTAssertEqual(viewModel.state, .permissionDenied)
        XCTAssertNil(viewModel.notice)
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
    private let activationError: SafariAutomationError?
    private var activated: [SafariTab] = []
    private var listCalls = 0
    private var listDelayNanoseconds: UInt64 = 0
    private let listErrorsByCall: [Int: SafariAutomationError]

    init(
        tabs: [SafariTab],
        listError: SafariAutomationError? = nil,
        activationError: SafariAutomationError? = nil,
        listErrorsByCall: [Int: SafariAutomationError] = [:]
    ) {
        self.tabs = tabs
        self.listError = listError
        self.activationError = activationError
        self.listErrorsByCall = listErrorsByCall
    }

    func listTabs() async throws -> [SafariTab] {
        listCalls += 1
        if listDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: listDelayNanoseconds)
        }
        if let error = listErrorsByCall[listCalls] { throw error }
        if let listError { throw listError }
        return tabs
    }

    func activate(_ target: SafariTab) async throws {
        if let activationError { throw activationError }
        activated.append(target)
    }

    func activatedTabs() -> [SafariTab] {
        activated
    }

    func listCallCount() -> Int {
        listCalls
    }

    func setListDelay(nanoseconds: UInt64) {
        listDelayNanoseconds = nanoseconds
    }
}
