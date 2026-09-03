import AppKit

@main
enum TabFinderApp {
    @MainActor
    private static var retainedDelegate: AppDelegate?

    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        retainedDelegate = delegate
        application.delegate = delegate
        application.mainMenu = ApplicationMenuFactory.make()
        application.setActivationPolicy(.accessory)
        application.run()
    }
}
