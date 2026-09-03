import Combine
import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var runtimeShortcutError: String?

    @Published var shortcut: KeyboardShortcut {
        didSet { saveShortcut() }
    }

    @Published var shortcutEnabled: Bool {
        didSet { defaults.set(shortcutEnabled, forKey: Keys.shortcutEnabled) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        runtimeShortcutError = nil

        if let data = defaults.data(forKey: Keys.shortcut),
           let stored = try? JSONDecoder().decode(KeyboardShortcut.self, from: data)
        {
            shortcut = stored
        } else {
            shortcut = .default
        }

        shortcutEnabled = defaults.object(forKey: Keys.shortcutEnabled) as? Bool ?? true
        launchAtLogin = defaults.object(forKey: Keys.launchAtLogin) as? Bool ?? false
    }

    private func saveShortcut() {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        defaults.set(data, forKey: Keys.shortcut)
    }

    private enum Keys {
        static let shortcut = "shortcut"
        static let shortcutEnabled = "shortcutEnabled"
        static let launchAtLogin = "launchAtLogin"
    }
}
