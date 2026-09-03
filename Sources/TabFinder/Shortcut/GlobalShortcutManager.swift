@MainActor
final class GlobalShortcutManager {
    private let registrar: any HotKeyRegistering
    private let action: @MainActor () -> Void

    private(set) var activeShortcut: KeyboardShortcut?

    init(
        registrar: any HotKeyRegistering,
        action: @escaping @MainActor () -> Void
    ) {
        self.registrar = registrar
        self.action = action
    }

    func apply(_ shortcut: KeyboardShortcut) throws {
        let previous = activeShortcut
        registrar.unregister()

        do {
            try registrar.register(shortcut, action: action)
            activeShortcut = shortcut
        } catch {
            if let previous {
                do {
                    try registrar.register(previous, action: action)
                    activeShortcut = previous
                } catch {
                    activeShortcut = nil
                    throw GlobalShortcutError.rollbackFailed
                }
            } else {
                activeShortcut = nil
            }
            throw error
        }
    }

    func disable() {
        registrar.unregister()
        activeShortcut = nil
    }
}
