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

    func testFailedRollbackReportsInactiveShortcut() throws {
        let defaultCode = KeyboardShortcut.default.keyCode
        let registrar = HotKeyRegistrarStub(
            failureAttempts: [7: [1], defaultCode: [2]]
        )
        let manager = GlobalShortcutManager(registrar: registrar, action: {})

        try manager.apply(.default)

        XCTAssertThrowsError(
            try manager.apply(KeyboardShortcut(keyCode: 7, modifiers: UInt32(cmdKey)))
        ) {
            XCTAssertEqual($0 as? GlobalShortcutError, .rollbackFailed)
        }
        XCTAssertNil(manager.activeShortcut)
        XCTAssertNil(registrar.lastRegisteredShortcut)
    }
}

@MainActor
private final class HotKeyRegistrarStub: HotKeyRegistering {
    let failingKeyCode: UInt32?
    private(set) var lastRegisteredShortcut: KeyboardShortcut?
    private var failureAttempts: [UInt32: Set<Int>]
    private var attempts: [UInt32: Int] = [:]

    init(
        failingKeyCode: UInt32? = nil,
        failureAttempts: [UInt32: Set<Int>] = [:]
    ) {
        self.failingKeyCode = failingKeyCode
        self.failureAttempts = failureAttempts
    }

    func register(
        _ shortcut: KeyboardShortcut,
        action: @escaping @MainActor () -> Void
    ) throws {
        attempts[shortcut.keyCode, default: 0] += 1
        let attempt = attempts[shortcut.keyCode, default: 0]
        if shortcut.keyCode == failingKeyCode
            || failureAttempts[shortcut.keyCode, default: []].contains(attempt)
        {
            throw GlobalShortcutError.registrationFailed(OSStatus(eventHotKeyExistsErr))
        }
        lastRegisteredShortcut = shortcut
    }

    func unregister() {
        lastRegisteredShortcut = nil
    }
}
