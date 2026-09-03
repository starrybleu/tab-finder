import XCTest

@testable import TabFinder

@MainActor
final class SettingsStoreTests: XCTestCase {
    func testDefaultsMatchProductDesign() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.shortcut, .default)
        XCTAssertTrue(store.shortcutEnabled)
        XCTAssertFalse(store.launchAtLogin)
    }

    func testValuesSurviveNewStoreInstance() {
        let (defaults, suiteName) = makeDefaults()
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let first = SettingsStore(defaults: defaults)
        let custom = KeyboardShortcut(keyCode: 17, modifiers: 768)

        first.shortcut = custom
        first.shortcutEnabled = false
        first.launchAtLogin = true
        first.runtimeShortcutError = "temporary conflict"

        let second = SettingsStore(defaults: defaults)
        XCTAssertEqual(second.shortcut, custom)
        XCTAssertFalse(second.shortcutEnabled)
        XCTAssertTrue(second.launchAtLogin)
        XCTAssertNil(second.runtimeShortcutError)
    }

    private func makeDefaults() -> (UserDefaults, String) {
        let suiteName = "TabFinderTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return (defaults, suiteName)
    }
}
