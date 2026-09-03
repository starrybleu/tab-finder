import AppKit
import Foundation

actor SafariAppleScriptClient: SafariAutomating {
    private static let safariBundleIdentifier = "com.apple.Safari"

    private static let listTabsSource = #"""
        tell application id "com.apple.Safari"
          set outputRows to {}
          set windowPosition to 0
          repeat with browserWindow in windows
            set windowPosition to windowPosition + 1
            set activeTabIndex to index of current tab of browserWindow
            repeat with browserTab in tabs of browserWindow
              set end of outputRows to {id of browserWindow, index of browserTab, windowPosition, name of browserTab, URL of browserTab, activeTabIndex}
            end repeat
          end repeat
          return outputRows
        end tell
        """#

    func listTabs() async throws -> [SafariTab] {
        try ensureSafariIsRunning()
        return try SafariTabDescriptorDecoder.decode(execute(Self.listTabsSource))
    }

    func activate(_ target: SafariTab) async throws {
        try ensureSafariIsRunning()
        let currentTabs = try SafariTabDescriptorDecoder.decode(execute(Self.listTabsSource))
        let resolved = try SafariTargetResolver.resolve(target, among: currentTabs)
        guard resolved.windowID > 0, resolved.tabIndex > 0 else {
            throw SafariAutomationError.targetChanged
        }

        _ = try execute(SafariActivationScript.source(for: resolved), targetSensitive: true)
    }

    private func ensureSafariIsRunning() throws {
        guard !NSRunningApplication.runningApplications(
            withBundleIdentifier: Self.safariBundleIdentifier
        ).isEmpty else {
            throw SafariAutomationError.safariNotRunning
        }
    }

    private func execute(
        _ source: String,
        targetSensitive: Bool = false
    ) throws -> NSAppleEventDescriptor {
        guard let script = NSAppleScript(source: source) else {
            throw SafariAutomationError.scriptFailure(number: 0, message: "AppleScript를 만들 수 없습니다.")
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)
        if errorInfo != nil {
            let number = (errorInfo?[NSAppleScript.errorNumber] as? NSNumber)?.intValue ?? 0
            let message = (errorInfo?[NSAppleScript.errorMessage] as? String) ?? "알 수 없는 AppleScript 오류"
            throw SafariAppleScriptErrorMapper.map(
                number: number,
                message: message,
                targetSensitive: targetSensitive
            )
        }
        return result
    }
}
