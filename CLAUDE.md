# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Canonical Task List

`status.md` is the canonical task list for this project. Consult it to understand outstanding work, and keep it updated as tasks are started, completed, or abandoned.

## Project Overview

**Unplug** (marketed as "Unplug ∎") is an iOS app that enforces unskippable screen time limits using Apple's Screen Time APIs. Users select apps/websites to restrict, set a schedule, and the restrictions are locked during the active interval — they cannot be bypassed or removed while active.

## Build & Run

This is an Xcode project (no SPM Package.swift or CocoaPods). Open `ScreenTimeShield.xcodeproj` in Xcode.

```bash
# Build
xcodebuild -scheme ScreenTimeShield -destination 'platform=iOS Simulator,name=iPhone 16'

# Run the tests — BOTH commands are required, see the warning below
swift test --package-path UnplugCore
xcodebuild test -scheme ScreenTimeShield -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

`fastlane test` runs both in one step, if you have fastlane installed.

Simulator names change between Xcode versions; `xcrun simctl list devices available` shows what
exists. A destination that doesn't exist makes `xcodebuild` print the device list **and still exit
0**, so check for `BUILD SUCCEEDED`/`TEST SUCCEEDED` rather than trusting the exit code.

### ⚠️ `xcodebuild test` and ⌘U do not run every test

The pure schedule and pricing logic is tested in the **`UnplugCore`** SwiftPM package. Its test
target cannot be referenced from the app scheme's `TestAction`, so neither ⌘U nor
`xcodebuild test -scheme ScreenTimeShield` executes it — they report success while those tests fail.

A green ⌘U on its own does not mean the test suite passes. Always run `swift test` too.

The app requires the **Family Controls** entitlement and must be run on a real device or simulator with Screen Time capabilities. It uses the `group.screentimeshield` app group for shared UserDefaults between the main app and extensions.

## Architecture

The app has **four targets** that work together:

1. **ScreenTimeShield** (main app) — SwiftUI app with a single-screen UI (`ContentView`). Uses `FamilyControls` for authorization and app selection.

2. **CustomDeviceActivityMonitor** (extension) — `DeviceActivityMonitor` subclass that runs in a separate process. Handles `intervalDidStart`/`intervalDidEnd` to apply and clear `ManagedSettings` restrictions. Also fires "refocus" notifications at 5-minute intervals when the user is on restricted apps outside blocked hours.

3. **CustomShieldAction** (extension) — `ShieldActionDelegate` that handles shield button taps. Both primary and secondary buttons close the shield (no bypass).

4. **CustomShieldConfiguration** (extension) — `ShieldConfigurationDataSource` that provides the dark-themed shield UI shown when a restricted app is opened.

### Key Data Flow

- **Model** (`Model.swift`) — Singleton (`Model.shared`) used by both the main app and the device activity monitor extension. Persists app selection via `PropertyListEncoder` into shared `UserDefaults`. Manages `ManagedSettingsStore` for applying/clearing shields.
- **Schedule** (`Schedule.swift`) — Static methods to register `DeviceActivitySchedule` with the system. Supports both repeating daily schedules and one-off hourly restrictions. Also manages an inverse "notification schedule" that monitors app usage outside restriction hours.
- **State sharing** — Extensions and the main app communicate through the `group.screentimeshield` app group UserDefaults. Key values: `ScreenTimeSeletion` (the encoded `FamilyActivitySelection`), `inside_interval` (bool), `start_minutes`/`end_minutes` (Int, minutes since midnight), `is_armed` (bool), `block_outside_window` (bool), `notifications_enabled` (bool), `enforcement_allowed` (bool, the cached entitlement gate the extensions read), `trial_start`, `times_stopped`.
- **The schedule window is minutes-of-day, not `Date`** — `Model.start`/`end` are `Int` (0..<1439). They used to be `Date` instants re-interpreted through `Calendar.current` on every read, which made the window drift an hour at each DST change and let the slider's right-hand edge resolve to nothing. A one-time migration (`Model.migrateScheduleStorage`) reads the undrifted interval back from `DeviceActivityCenter.schedule(for: .daily)` where one is registered, and falls back to converting the legacy `start`/`end` instants otherwise.

### Dependencies

- **AlertToast** (Swift Package) — used for toast notifications in the UI

## Localization

Strings are localized via `Localizable.xcstrings` (Xcode string catalog format) into 10 languages: en, de, es, fr, it, ja, ko, pt-PT, zh-Hans, zh-Hant. Use `String(localized:)` for new user-facing strings.

## Project Docs

Product notes and marketing plan are in Obsidian: `~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Notes/Amerish/projects/unplug/`

## Key Conventions

- `DeviceActivityName` extensions are duplicated in both `Schedule.swift` and `DeviceActivityMonitorExtension.swift` since extensions run in separate processes and can't share the main app's code directly
- The `insideInterval` flag is the source of truth for whether restrictions are currently active — it gates UI controls (schedule pickers become disabled)
- `validateRestriction()` prevents removing apps from a block, but only while `insideInterval` is true (`ContentView.swift:221`) — during the armed-but-not-yet-active state a selection can still be emptied. That gap is a known, accepted risk (`V09` in `qa/README.md`), and nothing tests it.
- `Schedule.setSchedule`/`setNotificationSchedule` take a completion that reports registration failure on the main queue. Use it on any arming path: a thrown `startMonitoring` leaves nothing registered, and the UI must not claim a block the system never accepted.
- `UnplugCore` is linked by the app, `CustomShieldConfiguration` **and** `CustomDeviceActivityMonitor` (the last one because it compiles `Model.swift`). It declares `platforms: [.iOS(.v16), .macOS(.v13)]` so `swift test` runs natively against the same availability the app gets.
