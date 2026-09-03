import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    private var settingsWindowController: SettingsWindowController?
    private var shortcutManager: GlobalShortcutManager?
    private var settingsStore: SettingsStore?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let automation = SafariAppleScriptClient()
        let viewModel = TabFinderViewModel(automation: automation)
        let menuBarController = MenuBarController(viewModel: viewModel)

        let store = SettingsStore()
        let registrar = CarbonHotKeyRegistrar()
        let shortcutManager = GlobalShortcutManager(registrar: registrar) { [weak menuBarController] in
            menuBarController?.toggle()
        }
        let launchAtLoginController = LaunchAtLoginController()
        let settingsWindowController = SettingsWindowController(
            store: store,
            shortcutManager: shortcutManager,
            launchAtLoginController: launchAtLoginController
        )
        menuBarController.setOpenSettingsAction { [weak settingsWindowController] in
            settingsWindowController?.show()
        }

        if store.shortcutEnabled {
            do {
                try shortcutManager.apply(store.shortcut)
            } catch {
                store.runtimeShortcutError = "저장된 전역 단축키를 등록하지 못했습니다. 설정에서 다른 조합을 선택해 주세요."
            }
        }

        self.menuBarController = menuBarController
        self.settingsWindowController = settingsWindowController
        self.shortcutManager = shortcutManager
        settingsStore = store
    }

    func applicationWillTerminate(_ notification: Notification) {
        shortcutManager?.disable()
    }
}
