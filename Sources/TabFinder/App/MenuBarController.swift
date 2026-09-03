import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let viewModel: TabFinderViewModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var openSettingsAction: (() -> Void)?

    init(viewModel: TabFinderViewModel) {
        self.viewModel = viewModel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        popover = NSPopover()
        super.init()

        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "rectangle.stack.badge.magnifyingglass",
                accessibilityDescription: AppMetadata.displayName
            )
            button.image?.isTemplate = true
            button.target = self
            button.action = #selector(toggleFromStatusItem)
            button.sendAction(on: [.leftMouseUp])
        }

        popover.behavior = .transient
        popover.contentSize = AppMetadata.popoverSize
        popover.animates = true
        popover.delegate = self
        popover.contentViewController = NSHostingController(
            rootView: PopoverContentView(
                viewModel: viewModel,
                close: { [weak self] in self?.hide() },
                openSafari: { [weak self] in self?.openSafari() },
                openSettings: { [weak self] in self?.showSettings() }
            )
        )
    }

    func toggle() {
        popover.isShown ? hide() : show()
    }

    func show() {
        guard !popover.isShown, let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        Task { await viewModel.load() }
    }

    func hide() {
        popover.performClose(nil)
    }

    func setOpenSettingsAction(_ action: @escaping () -> Void) {
        openSettingsAction = action
    }

    func popoverDidClose(_ notification: Notification) {}

    @objc private func toggleFromStatusItem() {
        toggle()
    }

    private func openSafari() {
        guard let safariURL = NSWorkspace.shared.urlForApplication(
            withBundleIdentifier: "com.apple.Safari"
        ) else { return }
        NSWorkspace.shared.openApplication(at: safariURL, configuration: .init())
        hide()
    }

    private func showSettings() {
        hide()
        openSettingsAction?()
    }
}
