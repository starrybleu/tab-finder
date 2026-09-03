import Combine
import Foundation

@MainActor
final class TabFinderViewModel: ObservableObject {
    enum State: Equatable {
        case idle
        case loading
        case loaded
        case safariNotRunning
        case permissionDenied
        case failed(String)
    }

    @Published var query = "" {
        didSet { applySearch() }
    }

    @Published private(set) var results: [SafariTab] = []
    @Published private(set) var selectedTabID: SafariTab.ID?
    @Published private(set) var state: State = .idle

    private let automation: any SafariAutomating
    private let searchEngine: TabSearchEngine
    private var snapshot: [SafariTab] = []

    init(
        automation: any SafariAutomating,
        searchEngine: TabSearchEngine = TabSearchEngine()
    ) {
        self.automation = automation
        self.searchEngine = searchEngine
    }

    func load() async {
        state = .loading
        do {
            snapshot = try await automation.listTabs()
            state = .loaded
            applySearch()
        } catch {
            snapshot = []
            results = []
            selectedTabID = nil
            state = Self.state(for: error)
        }
    }

    func moveSelection(by offset: Int) {
        guard !results.isEmpty else {
            selectedTabID = nil
            return
        }

        guard let selectedTabID,
              let currentIndex = results.firstIndex(where: { $0.id == selectedTabID })
        else {
            self.selectedTabID = results[0].id
            return
        }

        let count = results.count
        let nextIndex = ((currentIndex + offset) % count + count) % count
        self.selectedTabID = results[nextIndex].id
    }

    func select(_ id: SafariTab.ID) {
        guard results.contains(where: { $0.id == id }) else { return }
        selectedTabID = id
    }

    func activateSelected() async -> Bool {
        guard let selectedTabID,
              let selected = results.first(where: { $0.id == selectedTabID })
        else {
            return false
        }

        do {
            try await automation.activate(selected)
            return true
        } catch SafariAutomationError.targetChanged {
            await load()
            return false
        } catch {
            state = Self.state(for: error)
            return false
        }
    }

    private func applySearch() {
        let previousSelection = selectedTabID
        results = searchEngine.results(for: query, in: snapshot)

        if let previousSelection, results.contains(where: { $0.id == previousSelection }) {
            selectedTabID = previousSelection
        } else {
            selectedTabID = results.first?.id
        }
    }

    private static func state(for error: Error) -> State {
        switch error as? SafariAutomationError {
        case .safariNotRunning:
            return .safariNotRunning
        case .permissionDenied:
            return .permissionDenied
        case let .scriptFailure(_, message):
            return .failed(message)
        case .targetChanged:
            return .failed("선택한 탭이 변경되었습니다.")
        case .malformedResponse:
            return .failed("Safari의 탭 정보를 읽을 수 없습니다.")
        case nil:
            return .failed(error.localizedDescription)
        }
    }
}
