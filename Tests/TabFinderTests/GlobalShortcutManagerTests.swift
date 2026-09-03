import Carbon
import XCTest

@testable import TabFinder

@MainActor
final class GlobalShortcutManagerTests: XCTestCase {
    func testDefaultUsesCommandShiftAndPhysicalQuoteKey() {
        XCTAssertEqual(KeyboardShortcut.default.keyCode, UInt32(kVK_ANSI_Quote))
        XCTAssertEqual(KeyboardShortcut.default.modifiers, UInt32(cmdKey | shiftKey))
    }

    func testFailedReplacementRestoresPreviousRegistration() throws {
        let registrar = HotKeyRegistrarStub(failingKeyCode: 7)
        let manager = GlobalShortcutManager(registrar: registrar, action: {})

        try manager.apply(.default)
        XCTAssertThrowsError(
            try manager.apply(KeyboardShortcut(keyCode: 7, modifiers: UInt32(cmdKey)))
        )

        XCTAssertEqual(manager.activeShortcut, .default)
        XCTAssertEqual(registrar.lastRegisteredShortcut, .default)
    }

    func testDisablingRemovesRegistration() throws {
        let registrar = HotKeyRegistrarStub()
        let manager = GlobalShortcutManager(registrar: registrar, action: {})

        try manager.apply(.default)
        manager.disable()

        XCTAssertNil(manager.activeShortcut)
        XCTAssertNil(registrar.lastRegisteredShortcut)
    }
}

@MainActor
private final class HotKeyRegistrarStub: HotKeyRegistering {
    let failingKeyCode: UInt32?
    private(set) var lastRegisteredShortcut: KeyboardShortcut?

    init(failingKeyCode: UInt32? = nil) {
        self.failingKeyCode = failingKeyCode
    }

    func register(
        _ shortcut: KeyboardShortcut,
        action: @escaping @MainActor () -> Void
    ) throws {
        if shortcut.keyCode == failingKeyCode {
            throw GlobalShortcutError.registrationFailed(OSStatus(eventHotKeyExistsErr))
        }
        lastRegisteredShortcut = shortcut
    }

    func unregister() {
        lastRegisteredShortcut = nil
    }
}
