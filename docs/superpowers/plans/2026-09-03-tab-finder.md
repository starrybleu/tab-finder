# Tab Finder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local macOS menu bar app that searches every tab exposed by open Safari windows and focuses the selected tab from a configurable global shortcut.

**Architecture:** A Swift Package produces one AppKit/SwiftUI accessory app. An actor-backed Safari adapter uses `NSAppleScript`; a pure search engine and `@MainActor` view model drive an `NSPopover`. Carbon handles the global hot key and `SMAppService` handles optional launch at login.

**Tech Stack:** Swift 6, SwiftPM, AppKit, SwiftUI, Carbon/HIToolbox, ServiceManagement, XCTest, macOS 14+

**Spec:** `docs/superpowers/specs/2026-09-03-tab-finder-design.md`

## Global Constraints

- Product `Tab Finder`, bundle ID `com.hanbyullee.TabFinder`, macOS 14.0+.
- Apple frameworks only; no third-party packages, network requests, analytics, or telemetry.
- Keep tab titles, URLs, and queries in memory. Persist only shortcut and login preferences.
- Request Safari Automation only; no Accessibility, Screen Recording, Full Disk Access, or website permissions.
- Search tabs in currently open Safari windows; exclude inactive Tab Groups.
- Do not special-case private windows.
- Default shortcut: Command-Shift plus physical `kVK_ANSI_Quote`.
- Support local use without a paid developer membership.

## File Map

- `Package.swift`, `Config/*`, `scripts/build-app.sh` — package and signed app bundle.
- `Sources/TabFinder/App/*` — lifecycle, menu bar, popover, settings window, login item.
- `Sources/TabFinder/Domain/*` — tab values, search, local domain icons.
- `Sources/TabFinder/Safari/*` — automation protocol, decoding, resolution, AppleScript.
- `Sources/TabFinder/Features/*` — search and settings UI.
- `Sources/TabFinder/Shortcut/*` — physical-key model and Carbon registration.
- `Tests/TabFinderTests/*` — focused XCTest suites.
- `README.md` — build, install, permissions, privacy, limitations.

---

### Task 1: Bootstrap the locally signed accessory app

**Files:**
- Create: `Package.swift`, `.gitignore`, `Config/Info.plist`, `Config/TabFinder.entitlements`, `scripts/build-app.sh`
- Create: `Sources/TabFinder/App/AppMain.swift`, `AppDelegate.swift`, `AppMetadata.swift`
- Test: `Tests/TabFinderTests/AppMetadataTests.swift`

**Interfaces:**
- Consumes: none.
- Produces: `AppMetadata.displayName`, `bundleIdentifier`, `popoverSize`, and `outputs/Tab Finder.app`.

- [ ] **Step 1: Write the SwiftPM manifest and failing test**

```swift
// swift-tools-version: 6.0
import PackageDescription
let package = Package(
  name: "TabFinder", platforms: [.macOS(.v14)],
  products: [.executable(name: "TabFinder", targets: ["TabFinder"])],
  targets: [.executableTarget(name: "TabFinder"),
            .testTarget(name: "TabFinderTests", dependencies: ["TabFinder"])]
)
```

```swift
import AppKit
import XCTest
@testable import TabFinder
final class AppMetadataTests: XCTestCase {
  func testConstants() {
    XCTAssertEqual(AppMetadata.displayName, "Tab Finder")
    XCTAssertEqual(AppMetadata.bundleIdentifier, "com.hanbyullee.TabFinder")
    XCTAssertEqual(AppMetadata.popoverSize, NSSize(width: 400, height: 520))
  }
}
```

- [ ] **Step 2: Run `swift test --filter AppMetadataTests`**

Expected: FAIL because `AppMetadata` is undefined.

- [ ] **Step 3: Implement metadata and the minimal app**

```swift
import AppKit
enum AppMetadata {
  static let displayName = "Tab Finder"
  static let bundleIdentifier = "com.hanbyullee.TabFinder"
  static let popoverSize = NSSize(width: 400, height: 520)
}
```

`AppMain` creates `NSApplication.shared`, retains `AppDelegate`, sets `.accessory` activation policy, and runs. The delegate creates a square `NSStatusItem` using `rectangle.stack.badge.magnifyingglass`.

- [ ] **Step 4: Add bundle and signing files**

`Info.plist` sets the bundle fields, `LSUIElement=true`, macOS 14.0, and `NSAppleEventsUsageDescription` to “Tab Finder reads Safari tab titles and URLs and focuses the tab you select.” The entitlements plist contains only `com.apple.security.automation.apple-events=true`.

`build-app.sh` runs `swift build -c release`, recreates only `outputs/Tab Finder.app`, copies binary and plist, then runs:

```bash
codesign --force --sign - --options runtime \
  --entitlements "$project_root/Config/TabFinder.entitlements" "$bundle_path"
codesign --verify --deep --strict "$bundle_path"
```

Ignore `.build/` and `outputs/Tab Finder.app/` and mark the script executable.

- [ ] **Step 5: Verify and commit**

Run: `swift test && ./scripts/build-app.sh && plutil -lint "outputs/Tab Finder.app/Contents/Info.plist"`  
Expected: tests PASS, signature verifies, plist prints `OK`.

```bash
git add Package.swift .gitignore Config scripts Sources Tests
git commit -m "build: bootstrap Tab Finder menu bar app"
```

---

### Task 2: Implement deterministic search and local domain icons

**Files:**
- Create: `Sources/TabFinder/Domain/SafariTab.swift`, `TabSearchEngine.swift`, `DomainIconDescriptor.swift`
- Test: `Tests/TabFinderTests/TabSearchEngineTests.swift`, `DomainIconDescriptorTests.swift`

**Interfaces:**
- Consumes: Foundation only.
- Produces: `SafariTab`, `TabSearchEngine.results(for:in:)`, `DomainIconDescriptor.make(for:)`.

- [ ] **Step 1: Write failing search and icon tests**

Create GitHub in the current window, Google whose URL contains “github,” and Apple in another window. Assert:

```swift
XCTAssertEqual(engine.results(for: "github", in: tabs).map(\.title),
               ["GitHub Pull Requests", "Search"])
XCTAssertEqual(engine.results(for: "github pull", in: tabs).map(\.title),
               ["GitHub Pull Requests"])
XCTAssertEqual(engine.results(for: "", in: tabs).map(\.title),
               ["GitHub Pull Requests", "Search", "Apple"])
```

Assert the two `github.com` URLs produce equal icon descriptors with text `G` and `about:blank` produces `systemImageName == "globe"`.

- [ ] **Step 2: Run `swift test --filter 'TabSearchEngineTests|DomainIconDescriptorTests'`**

Expected: FAIL because the domain types are undefined.

- [ ] **Step 3: Implement the tab value and search ranking**

```swift
struct SafariTab: Identifiable, Equatable, Sendable {
  let windowID: Int
  let tabIndex: Int
  let windowOrder: Int
  let title: String
  let urlString: String
  let isCurrentWindow: Bool
  let isCurrentTab: Bool
  var id: String { "\(windowID):\(tabIndex)" }
  var hostname: String { URL(string: urlString)?.host() ?? "" }
}
```

Normalize with case-, diacritic-, and width-insensitive folding. Split whitespace into AND tokens. Per token score title prefix 400, title contains 300, hostname contains 200, URL contains 100; reject when any token misses. Add 10 for current window and 1 for current tab. Ties use `windowOrder` then `tabIndex`. Empty query preserves Safari order.

- [ ] **Step 4: Implement stable local icons**

Implement `DomainIconDescriptor` with `text: String?`, `systemImageName: String?`, and `hue: Double`. Use the uppercase first hostname character and FNV-1a over hostname UTF-8 bytes, with `hue = Double(hash % 360) / 360`. For non-host URLs use `text=nil`, `systemImageName="globe"`, and hue 0. Never access the network.

- [ ] **Step 5: Verify and commit**

Run: `swift test --filter 'TabSearchEngineTests|DomainIconDescriptorTests' && swift test`  
Expected: all tests PASS.

```bash
git add Sources/TabFinder/Domain Tests/TabFinderTests
git commit -m "feat: add deterministic Safari tab search"
```

---

### Task 3: List and activate Safari tabs safely

**Files:**
- Create: `Sources/TabFinder/Safari/SafariAutomating.swift`, `SafariTargetResolver.swift`, `SafariTabDescriptorDecoder.swift`, `SafariAppleScriptClient.swift`
- Test: `Tests/TabFinderTests/SafariTargetResolverTests.swift`, `SafariTabDescriptorDecoderTests.swift`

**Interfaces:**
- Consumes: `SafariTab`.
- Produces: `SafariAutomating.listTabs() async throws -> [SafariTab]`, `activate(_:) async throws`, `SafariAutomationError`.

- [ ] **Step 1: Write failing resolver tests**

For target URL `https://example.com/docs` in window 4, tab 2, assert: same position and URL with a renamed title resolves; a unique same-window URL moved to tab 5 resolves; duplicate matching URLs or a missing window throw `.targetChanged`.

- [ ] **Step 2: Write failing descriptor tests**

Construct nested `NSAppleEventDescriptor` lists containing window ID, tab index, window order, title, URL, and current-tab index. Assert one valid row decodes, an empty URL row is skipped, and a non-list outer descriptor throws `.malformedResponse`.

- [ ] **Step 3: Run `swift test --filter 'SafariTargetResolverTests|SafariTabDescriptorDecoderTests'`**

Expected: FAIL because the Safari boundary is undefined.

- [ ] **Step 4: Define the protocol, errors, and resolver**

```swift
protocol SafariAutomating: Sendable {
  func listTabs() async throws -> [SafariTab]
  func activate(_ target: SafariTab) async throws
}
enum SafariAutomationError: Error, Equatable {
  case safariNotRunning, permissionDenied, targetChanged, malformedResponse
  case scriptFailure(number: Int, message: String)
}
```

Resolver order: accept the same window/index only when URL still matches and is not an ambiguous duplicate; otherwise accept one unique same-window URL; otherwise narrow duplicates by exact title and require exactly one result.

- [ ] **Step 5: Implement strict descriptor decoding**

Iterate descriptor lists with one-based indexes. Require six fields, skip rows without URL, replace an empty title with URL, derive `isCurrentWindow` from `windowOrder == 1` and `isCurrentTab` from equality with current-tab index. Return an empty array for an empty list.

- [ ] **Step 6: Implement the serialized AppleScript actor**

Check `NSRunningApplication.runningApplications(withBundleIdentifier:)` first and throw `.safariNotRunning` without launching Safari. Use this list script:

```applescript
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
```

`SafariAppleScriptClient` is an actor. Map AppleScript error `-1743` to `.permissionDenied`. To activate, refresh, resolve, then interpolate only validated integer window ID and tab index:

```applescript
tell application id "com.apple.Safari"
  set targetWindow to first window whose id is WINDOW_ID
  set current tab of targetWindow to tab TAB_INDEX of targetWindow
  set index of targetWindow to 1
  activate
end tell
```

- [ ] **Step 7: Verify and commit**

Run: `swift test && ./scripts/build-app.sh`  
Expected: all tests PASS and signing verifies.

```bash
git add Sources/TabFinder/Safari Tests/TabFinderTests
git commit -m "feat: add safe Safari tab automation"
```

---

### Task 4: Build the search view model

**Files:**
- Create: `Sources/TabFinder/Features/Search/TabFinderViewModel.swift`
- Test: `Tests/TabFinderTests/TabFinderViewModelTests.swift`

**Interfaces:**
- Consumes: `SafariAutomating`, `SafariTab`, `TabSearchEngine`.
- Produces: `load() async`, `moveSelection(by:)`, `activateSelected() async -> Bool`, `query`, `results`, `selectedTabID`, `state`.

- [ ] **Step 1: Write failing async tests**

With an actor stub conforming to `SafariAutomating`, assert: loading two tabs then querying “apple” yields only Apple and selects it; moving up from the first result wraps to the last; successful activation returns true and sends the selected value; `.permissionDenied` maps to the permission state.

- [ ] **Step 2: Run `swift test --filter TabFinderViewModelTests`**

Expected: FAIL because `TabFinderViewModel` is undefined.

- [ ] **Step 3: Implement explicit state and deterministic selection**

```swift
@MainActor
final class TabFinderViewModel: ObservableObject {
  enum State: Equatable {
    case idle, loading, loaded, safariNotRunning, permissionDenied
    case failed(String)
  }
  @Published var query = "" { didSet { applySearch() } }
  @Published private(set) var results: [SafariTab] = []
  @Published private(set) var selectedTabID: SafariTab.ID?
  @Published private(set) var state: State = .idle
  private let automation: any SafariAutomating
  private let searchEngine: TabSearchEngine
  private var snapshot: [SafariTab] = []
}
```

`load()` maps typed errors to exact states. `applySearch()` keeps selection when present or selects the first result. `moveSelection(by:)` wraps using modulo arithmetic. `activateSelected()` returns true only on success; `.targetChanged` triggers one reload without clearing `query`.

- [ ] **Step 4: Verify and commit**

Run: `swift test --filter TabFinderViewModelTests && swift test`  
Expected: all tests PASS.

```bash
git add Sources/TabFinder/Features/Search/TabFinderViewModel.swift Tests/TabFinderTests/TabFinderViewModelTests.swift
git commit -m "feat: add tab search view model"
```

---

### Task 5: Present the SwiftUI search popover

**Files:**
- Create: `Sources/TabFinder/App/MenuBarController.swift`, `PopoverPresentationState.swift`
- Create: `Sources/TabFinder/Features/Search/PopoverContentView.swift`, `TabRowView.swift`, `DomainIconView.swift`, `SearchStatusView.swift`
- Modify: `Sources/TabFinder/App/AppDelegate.swift`
- Test: `Tests/TabFinderTests/PopoverPresentationStateTests.swift`

**Interfaces:**
- Consumes: `TabFinderViewModel` and `AppMetadata.popoverSize`.
- Produces: `MenuBarController.toggle()`, `show()`, `hide()`, and the functional popover.

- [ ] **Step 1: Write the failing presentation-state test**

```swift
func testToggleAndEscapeTransitions() {
  var state = PopoverPresentationState()
  XCTAssertFalse(state.isShown)
  state.toggle()
  XCTAssertTrue(state.isShown)
  state.escape()
  XCTAssertFalse(state.isShown)
}
```

- [ ] **Step 2: Run `swift test --filter PopoverPresentationStateTests`**

Expected: FAIL because `PopoverPresentationState` is undefined.

- [ ] **Step 3: Implement state and AppKit ownership**

```swift
struct PopoverPresentationState: Equatable {
  private(set) var isShown = false
  mutating func toggle() { isShown.toggle() }
  mutating func show() { isShown = true }
  mutating func hide() { isShown = false }
  mutating func escape() { hide() }
}
```

`MenuBarController` owns one `NSStatusItem` and one transient `NSPopover`. `show()` launches `viewModel.load()`, presents from the status button, and focuses search. `hide()` closes without persisting or logging the snapshot. `toggle()` consults `popover.isShown`.

- [ ] **Step 4: Implement the reference-inspired view hierarchy**

```swift
VStack(spacing: 12) {
  header
  TextField("Search tabs by title or URL", text: $viewModel.query)
    .textFieldStyle(.roundedBorder)
    .focused($searchFocused)
  resultContent
}
.padding(14)
.frame(width: 400, height: 520)
.onKeyPress(.upArrow) { viewModel.moveSelection(by: -1); return .handled }
.onKeyPress(.downArrow) { viewModel.moveSelection(by: 1); return .handled }
.onKeyPress(.return) { activateSelection(); return .handled }
.onKeyPress(.escape) { close(); return .handled }
```

Use `ScrollViewReader` and `LazyVStack`. Each row has the local domain letter, one-line title, and one-line hostname/URL. Selected rows use low-opacity accent color. Status views cover loading, Safari not running with Open Safari, permission denied, no open tabs, no matches, and retryable failure.

- [ ] **Step 5: Compose production dependencies**

```swift
func applicationDidFinishLaunching(_ notification: Notification) {
  let automation = SafariAppleScriptClient()
  let viewModel = TabFinderViewModel(automation: automation)
  menuBarController = MenuBarController(viewModel: viewModel)
}
```

Open Safari through `NSWorkspace` only when the user presses the Open Safari action.

- [ ] **Step 6: Verify, smoke-test, and commit**

Run: `swift test && ./scripts/build-app.sh && open "outputs/Tab Finder.app"`  
Expected: no Dock icon; the status icon opens a 400×520 popover. Quit it from the UI.

```bash
git add Sources/TabFinder/App Sources/TabFinder/Features/Search Tests/TabFinderTests
git commit -m "feat: add searchable menu bar popover"
```

---

### Task 6: Add configurable global shortcut and settings

**Files:**
- Create: `Sources/TabFinder/Shortcut/KeyboardShortcut.swift`, `HotKeyRegistering.swift`, `CarbonHotKeyRegistrar.swift`, `GlobalShortcutManager.swift`
- Create: `Sources/TabFinder/Features/Settings/SettingsStore.swift`, `SettingsView.swift`, `ShortcutRecorderView.swift`
- Create: `Sources/TabFinder/App/SettingsWindowController.swift`, `LaunchAtLoginController.swift`
- Modify: `Sources/TabFinder/App/AppDelegate.swift`, `MenuBarController.swift`
- Test: `Tests/TabFinderTests/GlobalShortcutManagerTests.swift`, `SettingsStoreTests.swift`

**Interfaces:**
- Consumes: `MenuBarController.toggle()`.
- Produces: `KeyboardShortcut.default`, `GlobalShortcutManager.apply(_:)`, `SettingsStore`, `LaunchAtLoginController.setEnabled(_:)`.

- [ ] **Step 1: Write failing shortcut tests**

```swift
func testDefaultUsesCommandShiftAndPhysicalQuoteKey() {
  XCTAssertEqual(KeyboardShortcut.default.keyCode, UInt32(kVK_ANSI_Quote))
  XCTAssertEqual(KeyboardShortcut.default.modifiers, UInt32(cmdKey | shiftKey))
}
func testFailedReplacementRestoresPreviousRegistration() throws {
  let registrar = HotKeyRegistrarStub(failingKeyCode: 7)
  let manager = GlobalShortcutManager(registrar: registrar, action: {})
  try manager.apply(.default)
  XCTAssertThrowsError(try manager.apply(.init(keyCode: 7, modifiers: UInt32(cmdKey))))
  XCTAssertEqual(manager.activeShortcut, .default)
  XCTAssertEqual(registrar.lastRegisteredShortcut, .default)
}
```

With isolated `UserDefaults(suiteName:)`, assert `SettingsStore` defaults to the default shortcut, shortcut enabled, and Launch at Login disabled. Assert enabled/disabled state survives a new store instance.

- [ ] **Step 2: Run `swift test --filter 'GlobalShortcutManagerTests|SettingsStoreTests'`**

Expected: FAIL because shortcut and settings types are undefined.

- [ ] **Step 3: Implement the physical shortcut model and seam**

```swift
import Carbon
struct KeyboardShortcut: Codable, Equatable, Sendable {
  let keyCode: UInt32
  let modifiers: UInt32
  static let `default` = KeyboardShortcut(
    keyCode: UInt32(kVK_ANSI_Quote),
    modifiers: UInt32(cmdKey | shiftKey)
  )
}
protocol HotKeyRegistering: AnyObject {
  func register(_ shortcut: KeyboardShortcut,
                action: @escaping @MainActor () -> Void) throws
  func unregister()
}
enum GlobalShortcutError: Error, Equatable {
  case registrationFailed(OSStatus)
}
```

- [ ] **Step 4: Implement Carbon registration and rollback**

`CarbonHotKeyRegistrar` installs one `kEventClassKeyboard/kEventHotKeyPressed` handler, registers signature `TFDR` and ID 1, and dispatches its retained action to `MainActor`. It unregisters and releases all Carbon references on replacement and deinit.

`GlobalShortcutManager.apply` saves the old shortcut, unregisters it, attempts the new registration, and re-registers the old shortcut before rethrowing on failure. Update `activeShortcut` only after success.

- [ ] **Step 5: Implement settings and the key recorder**

`SettingsStore` persists only JSON-encoded shortcut, `shortcutEnabled`, and `launchAtLogin`. `ShortcutRecorderView` uses an `NSViewRepresentable` whose view accepts first responder. On `keyDown`, translate Command, Shift, Option, and Control flags to Carbon modifiers and save `event.keyCode`. Modifier-only events do nothing; Escape cancels recording.

- [ ] **Step 6: Implement Settings and launch at login**

```swift
func setEnabled(_ enabled: Bool) throws {
  if enabled { try SMAppService.mainApp.register() }
  else { try SMAppService.mainApp.unregister() }
}
```

`SettingsView` displays recorder, Enable Shortcut, Restore Default, and Launch at Login controls plus inline errors. `SettingsWindowController` reuses one titled `NSWindow`. Open it from the popover gear button.

- [ ] **Step 7: Wire app composition**

`AppDelegate` creates the store, Carbon registrar, shortcut manager, settings controller, and menu bar controller. The hot-key action calls `MenuBarController.toggle()`. Register the stored shortcut at startup only when enabled. Persist a changed shortcut only after successful registration.

- [ ] **Step 8: Verify, smoke-test, and commit**

Run: `swift test && ./scripts/build-app.sh && open "outputs/Tab Finder.app"`  
Expected: Command-Shift plus physical apostrophe toggles from another app; a conflict leaves the prior shortcut active; Settings can disable and restore it. Quit the app.

```bash
git add Sources/TabFinder/Shortcut Sources/TabFinder/Features/Settings Sources/TabFinder/App Tests/TabFinderTests
git commit -m "feat: add configurable global shortcut"
```

---

### Task 7: Finish errors, documentation, and installation

**Files:**
- Modify: `Sources/TabFinder/Features/Search/SearchStatusView.swift`, `TabFinderViewModel.swift`, `scripts/build-app.sh`
- Modify test: `Tests/TabFinderTests/TabFinderViewModelTests.swift`
- Create: `README.md`

**Interfaces:**
- Consumes: all Tasks 1–6 interfaces.
- Produces: verified `outputs/Tab Finder.app` and complete usage documentation.

- [ ] **Step 1: Write failing recovery tests**

```swift
func testPermissionDeniedMapsToActionableState() async {
  let model = TabFinderViewModel(automation: SafariAutomationStub(error: .permissionDenied))
  await model.load()
  XCTAssertEqual(model.state, .permissionDenied)
}
func testChangedTargetReloadsWithoutClearingQuery() async {
  let stub = SafariAutomationStub(tabs: SafariTab.fixtures(count: 1),
                                  activationError: .targetChanged)
  let model = TabFinderViewModel(automation: stub)
  await model.load()
  model.query = "fixture"
  XCTAssertFalse(await model.activateSelected())
  XCTAssertEqual(model.query, "fixture")
  XCTAssertEqual(await stub.listCallCount(), 2)
}
```

- [ ] **Step 2: Run `swift test --filter TabFinderViewModelTests`**

Expected: stale-target reload assertion FAILS until recovery is implemented.

- [ ] **Step 3: Implement exact recovery copy and redacted logging**

Use these messages: `Safari is not open.`, `Allow Tab Finder to control Safari in System Settings > Privacy & Security > Automation.`, `No matching tabs.`, `No open Safari tabs.`, and `That tab changed or closed. The list has been refreshed.`

Use `Logger(subsystem: AppMetadata.bundleIdentifier, category: "automation")`. Log only cases and numeric AppleScript codes; never log titles, URLs, or queries.

- [ ] **Step 4: Write README**

Document requirements, `./scripts/build-app.sh`, copying the app to `/Applications`, first-run Automation approval and recovery, default/custom shortcut, Launch at Login, in-memory/no-network privacy, open-window-only scope, inactive Tab Group limitation, private-window behavior, and local domain icons.

- [ ] **Step 5: Make bundle cleanup explicit**

Before creating the bundle:

```bash
if [[ -d "$bundle_path" ]]; then
  rm -R "$bundle_path"
fi
mkdir -p "$bundle_path/Contents/MacOS"
```

Keep the deletion target fixed to `outputs/Tab Finder.app` derived from the checked-in project root.

- [ ] **Step 6: Run automated and bundle verification**

Run: `swift test && ./scripts/build-app.sh`  
Expected: all tests PASS and signature verifies.

Run: `codesign -d --entitlements :- "outputs/Tab Finder.app" 2>&1`  
Expected: Apple Events true; no App Sandbox, Accessibility, or network entitlements.

Run: `find "outputs/Tab Finder.app" -maxdepth 4 -type f -print`  
Expected: output includes `Contents/Info.plist` and `Contents/MacOS/TabFinder`; any additional file is confined to the code-signing metadata directory `Contents/_CodeSignature`.

- [ ] **Step 7: Perform manual acceptance**

Use at least two Safari windows and background tabs. Verify title and URL search, arrows/Enter, minimized and different-Space focus, target close/move recovery, default and custom shortcuts, light/dark mode, Safari-not-running flow, Automation deny/allow flow, and Launch at Login enable/disable status.

- [ ] **Step 8: Install with user authorization**

```bash
ditto "outputs/Tab Finder.app" "/Applications/Tab Finder.app"
open "/Applications/Tab Finder.app"
```

Expected: only a menu bar item appears and the default shortcut opens the popover.

- [ ] **Step 9: Commit and confirm cleanliness**

```bash
git add README.md scripts/build-app.sh Sources/TabFinder/Features/Search Tests/TabFinderTests
git commit -m "docs: finish Tab Finder installation and privacy guidance"
git status --short
```

Expected: final tests passed, app installed, and no tracked changes remain.
