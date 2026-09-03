import Carbon
import Foundation

@MainActor
final class CarbonHotKeyRegistrar: HotKeyRegistering {
    private static let signature: OSType = 0x5446_4452 // TFDR
    private static let identifier: UInt32 = 1

    nonisolated(unsafe) private var eventHandler: EventHandlerRef?
    nonisolated(unsafe) private var hotKey: EventHotKeyRef?
    private var action: (@MainActor () -> Void)?

    func register(
        _ shortcut: KeyboardShortcut,
        action: @escaping @MainActor () -> Void
    ) throws {
        unregister()
        try installHandlerIfNeeded()

        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(
            signature: Self.signature,
            id: Self.identifier
        )
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            throw GlobalShortcutError.registrationFailed(status)
        }

        hotKey = reference
        self.action = action
    }

    func unregister() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        hotKey = nil
        action = nil
    }

    fileprivate func performAction() {
        action?()
    }

    private func installHandlerIfNeeded() throws {
        guard eventHandler == nil else { return }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        var handler: EventHandlerRef?
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        guard status == noErr, let handler else {
            throw GlobalShortcutError.registrationFailed(status)
        }
        eventHandler = handler
    }

    deinit {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }
}

private func carbonHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let registrar = Unmanaged<CarbonHotKeyRegistrar>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async {
        registrar.performAction()
    }
    return noErr
}
