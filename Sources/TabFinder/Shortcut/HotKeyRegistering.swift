import Carbon

@MainActor
protocol HotKeyRegistering: AnyObject {
    func register(
        _ shortcut: KeyboardShortcut,
        action: @escaping @MainActor () -> Void
    ) throws
    func unregister()
}

enum GlobalShortcutError: Error, Equatable {
    case registrationFailed(OSStatus)
    case rollbackFailed
}
