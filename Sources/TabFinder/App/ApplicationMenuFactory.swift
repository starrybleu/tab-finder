import AppKit

@MainActor
enum ApplicationMenuFactory {
    static func make() -> NSMenu {
        let mainMenu = NSMenu(title: "Main Menu")

        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: AppMetadata.displayName)
        applicationMenu.addItem(
            NSMenuItem(
                title: "Tab Finder 종료",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            )
        )
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "편집")
        editMenu.addItem(textCommand("잘라내기", action: #selector(NSText.cut(_:)), key: "x"))
        editMenu.addItem(textCommand("복사", action: #selector(NSText.copy(_:)), key: "c"))
        editMenu.addItem(textCommand("붙여넣기", action: #selector(NSText.paste(_:)), key: "v"))
        editMenu.addItem(.separator())
        editMenu.addItem(textCommand("전체 선택", action: #selector(NSText.selectAll(_:)), key: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        return mainMenu
    }

    private static func textCommand(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = [.command]
        item.target = nil
        return item
    }
}
