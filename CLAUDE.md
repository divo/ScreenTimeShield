# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**Unplug** (marketed as "Unplug ∎") is an iOS app that enforces unskippable screen time limits using Apple's Screen Time APIs. Users select apps/websites to restrict, set a schedule, and the restrictions are locked during the active interval — they cannot be bypassed or removed while active.

## Build & Run

This is an Xcode project (no SPM Package.swift or CocoaPods). Open `ScreenTimeShield.xcodeproj` in Xcode.

```bash
# Build
xcodebuild -scheme ScreenTimeShield -destination 'platform=iOS Simulator,name=iPhone 16'

# Run tests
xcodebuild test -scheme ScreenTimeShield -destination 'platform=iOS Simulator,name=iPhone 16'
```

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
- **State sharing** — Extensions and the main app communicate through the `group.screentimeshield` app group UserDefaults. Key values: `ScreenTimeSeletion` (the encoded `FamilyActivitySelection`), `inside_interval` (bool), `start`/`end` (dates), `notifications_enabled` (bool).

### Dependencies

- **AlertToast** (Swift Package) — used for toast notifications in the UI

## Localization

Strings are localized via `Localizable.xcstrings` (Xcode string catalog format) into 10 languages: en, de, es, fr, it, ja, ko, pt-PT, zh-Hans, zh-Hant. Use `String(localized:)` for new user-facing strings.

## Key Conventions

- `DeviceActivityName` extensions are duplicated in both `Schedule.swift` and `DeviceActivityMonitorExtension.swift` since extensions run in separate processes and can't share the main app's code directly
- The `insideInterval` flag is the source of truth for whether restrictions are currently active — it gates UI controls (schedule pickers become disabled)
- `validateRestriction()` exists in Model but is currently commented out in the UI — it was designed to prevent removing apps from an active block
