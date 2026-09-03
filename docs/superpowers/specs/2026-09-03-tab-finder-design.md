# Tab Finder Design

## Summary

Tab Finder is a personal macOS menu bar app that searches the titles and URLs of tabs in every open Safari window. Selecting a result activates the exact Safari tab and brings its window to the foreground. The app runs locally, stores no tab history, and makes no network requests.

The initial design considered a Safari toolbar extension. That approach was rejected because unsigned Safari extensions must be re-enabled after every Safari restart without a paid Apple Developer Program membership. A native menu bar app avoids that maintenance and also avoids Safari's per-profile extension isolation.

## Goals

- Show a compact search popover from the macOS menu bar.
- Open the same popover from a configurable global keyboard shortcut.
- Search tab titles and URLs across all currently open Safari windows.
- Include windows from every Safari profile that Safari exposes through automation.
- Include private windows if Safari exposes them; do not add special private-window detection.
- Activate the selected tab and focus its containing Safari window.
- Operate without a paid Apple Developer Program membership.
- Keep all tab data in memory and make no external network requests.

## Non-goals

- Safari toolbar integration in the first version.
- Searching inactive Safari Tab Groups that are not represented by open windows.
- Searching Safari history, bookmarks, Reading List, or page contents.
- Closing or rearranging tabs.
- Persisting queries or tab metadata.
- Downloading or caching website favicons.
- Supporting browsers other than Safari.

## User Experience

### Menu bar and presentation

- The app is an agent-style macOS app with no Dock icon and no ordinary main window.
- An `NSStatusItem` displays the Tab Finder icon in the macOS menu bar.
- Clicking the status item toggles an `NSPopover` approximately 400 by 520 points.
- The popover is implemented with SwiftUI hosted by AppKit for precise menu bar behavior.
- The search field receives focus whenever the popover opens.
- Pressing Escape, clicking outside, or invoking the global shortcut again closes the popover.
- A settings button opens a small settings window for the shortcut and launch-at-login preference.
- A Quit command remains available from the popover or status-item menu.

### Search results

- With an empty query, all open tabs appear.
- Matching is case-insensitive and searches the title, hostname, and full URL.
- Whitespace-separated query tokens use AND semantics.
- Ranking order is title prefix, title substring, hostname substring, then full-URL substring.
- Ties prefer the current Safari window and then preserve Safari's window and tab order.
- Each row shows a locally generated domain icon, title, and a single-line hostname or URL.
- The domain icon uses the first displayable hostname character and a deterministic local color. Non-web URLs use a generic globe symbol.
- Up and Down Arrow change selection. Enter activates the selected result.
- The UI supports macOS light and dark appearances.

### Global shortcut

- The default shortcut is Command-Shift plus the physical apostrophe key: `Command + Shift + kVK_ANSI_Quote`.
- The shortcut is registered by physical key code so it remains in the same keyboard position across input languages.
- A shortcut recorder in Settings accepts a new key and modifier combination.
- Registration failures, including a conflict with an existing global shortcut, are shown immediately and the previous valid shortcut remains active.
- Settings can disable the shortcut or restore the default.
- Registration uses the system hot-key API rather than global keyboard event monitoring, so Accessibility permission is not required.

## Architecture

### Components

1. **App lifecycle and menu bar controller**
   - Owns `NSStatusItem`, `NSPopover`, Settings, and application activation policy.
   - Coordinates opening, closing, focus, and launch-at-login state.

2. **Safari automation client**
   - Defines a small protocol for listing tabs and activating a tab.
   - The production adapter uses Safari's Apple Events scripting interface through `NSAppleScript`.
   - All AppleScript execution runs on one dedicated serial queue.
   - AppleScript results are returned as nested descriptors, avoiding delimiter-based parsing of arbitrary titles and URLs.
   - Errors are converted into typed Swift errors suitable for user-facing recovery messages.

3. **Tab search model**
   - Holds the current in-memory snapshot.
   - Normalizes queries and computes deterministic ranking.
   - Exposes loading, loaded, empty, permission-denied, Safari-not-running, and failed states.

4. **Global shortcut manager**
   - Registers and unregisters the current physical key code and modifiers.
   - Stores only shortcut settings in `UserDefaults`.
   - Delivers shortcut events to the menu bar controller.

5. **Launch-at-login manager**
   - Uses `SMAppService.mainApp`.
   - The preference defaults to off and is explicitly controlled by the user in Settings.

### Data model

An in-memory `SafariTab` value contains:

- Safari window ID
- one-based tab index within that window
- window order
- tab order
- title
- URL string
- parsed hostname when available
- whether the tab or its window was current at snapshot time

The stable selection key for one snapshot is the Safari window ID plus tab index. No snapshot survives app termination.

### Loading flow

1. The user opens the popover from the menu bar or global shortcut.
2. The popover immediately shows a loading state and focuses the search field.
3. The Safari automation client requests every window and each window's tabs in one Apple Events operation.
4. The returned descriptors are converted to `SafariTab` values on a background task.
5. The search model publishes results on the main actor and applies the current query.
6. Reopening the popover always creates a fresh snapshot. The app does not poll Safari while hidden.

The first version takes one snapshot per popover opening. If a target disappears before activation, the app refreshes once and reports that the tab is no longer available. Continuous background observation is intentionally excluded.

### Activation flow

1. The user clicks a result or presses Enter.
2. The app sends the stored Safari window ID, one-based tab index, expected URL, and expected title to the automation client.
3. The automation client verifies that the indexed tab still has the expected URL and title. If it moved, the client searches the same window and continues only when exactly one tab matches.
4. Safari makes the verified tab current, moves the containing window to the front, and activates the Safari application.
5. The popover closes after successful activation.
6. If the window disappeared or the target is missing or ambiguous, the app refreshes the snapshot and displays a recoverable message instead of activating an arbitrary tab.

## Permissions and Privacy

- The app declares an Apple Events usage description explaining that Safari control is required to list and focus tabs.
- The hardened runtime Apple Events entitlement is enabled as required by macOS.
- App Sandbox is disabled for the first personal build so the app can use Safari's supported scripting interface without private entitlements.
- The first Safari query triggers the standard macOS Automation permission prompt.
- The app does not request Accessibility, Screen Recording, Full Disk Access, or website permissions.
- The app does not read page contents, browser history, cookies, or form data.
- Tab titles and URLs remain in process memory only.
- Only preferences such as shortcut configuration and launch-at-login choice are persisted.
- There are no analytics, telemetry, crash-upload services, or network clients.

## Error Handling

- **Safari is not running:** show an empty state with an Open Safari action.
- **Automation permission denied:** explain how to enable Tab Finder under System Settings > Privacy & Security > Automation.
- **Safari returns malformed or missing tab data:** omit only the invalid tab and keep valid results.
- **Tab closes or moves after the snapshot:** refresh once and show a non-destructive error if the original target can no longer be identified.
- **Global shortcut conflict:** retain the prior shortcut and ask the user to record another combination.
- **Launch-at-login registration failure:** keep the app usable and show the macOS error in Settings.
- **Unexpected Apple Events failure:** preserve the query, show a retry action, and write a local unified log entry without tab titles or URLs.

## Signing and Installation

- The project targets macOS only and is built with the installed Xcode toolchain.
- The app is signed for local execution and is not submitted to the App Store.
- No Safari extension signing or paid Apple Developer Program membership is required.
- The final app is copied to `/Applications/Tab Finder.app` or another user-chosen Applications folder and launched once.
- The user grants Safari Automation access on first use.
- Later local rebuilds may cause macOS to request Automation permission again if the code identity changes.

## Testing Strategy

### Automated tests

- Search normalization and tokenization.
- Ranking across title, hostname, and URL matches.
- Stable tie ordering and empty-query behavior.
- Domain icon letter and deterministic color generation.
- Apple Event descriptor decoding with missing and malformed values.
- Activation command construction and typed error mapping using a mocked automation adapter.
- Shortcut serialization, default restoration, conflict rollback, and disable behavior.
- View-model states for loading, empty, denied, failed, and successful results.

### Manual Safari verification

- Multiple Safari windows with background tabs.
- Windows belonging to multiple Safari profiles.
- Duplicate titles and duplicate URLs.
- A tab closing or moving while the popover is open.
- Minimized, full-screen, and different-Space Safari windows.
- Private windows, if Safari exposes them through automation.
- Safari not running and Safari launching after an empty state.
- Automation permission allow and deny paths.
- Menu bar click and the default `Command-Shift-Apostrophe` shortcut.
- Custom shortcut recording, conflict detection, and persistence.
- Light and dark mode layouts at long-title and long-URL extremes.
- Launch-at-login enable and disable behavior.

## Known Limitations and Future Work

- Only tabs belonging to currently open Safari windows are searchable.
- Inactive Tab Groups are excluded because Safari exposes no supported Tab Group object through its scripting interface.
- Profile names are not displayed.
- Private windows are neither specially included nor excluded; they appear only if Safari returns them through its automation interface.
- Website favicons are replaced by local domain-letter icons to avoid network requests and private Safari database access.
- A future version may add a paid-signed Safari toolbar extension while retaining the native app as the shared search engine.

## Acceptance Criteria

- Opening Tab Finder lists the tabs from every currently open Safari window.
- A title or URL substring reduces the list immediately and deterministically.
- Clicking a result or pressing Enter activates the correct tab and foregrounds its Safari window.
- `Command-Shift` plus the physical apostrophe key opens the popover from another application.
- The user can change, disable, and restore the shortcut without granting Accessibility permission.
- No tab metadata is written to disk and no network request is made.
- The app builds and runs locally without a paid Apple Developer Program account.
