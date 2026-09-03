import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let automation = SafariAppleScriptClient()
        let viewModel = TabFinderViewModel(automation: automation)
        menuBarController = MenuBarController(viewModel: viewModel)
    }
}
