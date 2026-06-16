# Worklog — 2026-06-16 — Pricing rework (free trial + lifetime IAP)

Branch: `pricing-rework` (merged to `main` at end of session).

## Goal
Move from a $1 upfront paid app to a **free download + one-time "lifetime unlock" IAP**, fronted by a **7-day free trial**. Grandfather existing paid users; preserve the "unbypassable" promise.

## Locked design decisions
- One-time **non-consumable** lifetime unlock (no subscription).
- Trial: **7 days**, starts **after the user sets up their first block**.
- Gating: **whole-app** — blocking disabled after trial until purchase.
- Grandfathering: entitlement when `AppTransaction.originalAppVersion` < **cutover build (12)**.
- Trial-end enforcement: **gate-and-drain** — stop scheduling new blocks; let an active block finish via `intervalDidEnd`. Never tear down an active shield.
- No CTA on the shield screen (can't deep-link; undercuts the pitch).
- Value comms: **"times stopped"** stat (shield-presentation hook, debounced, shown only when ≥ 5), time-anchored notification at the habitual block time, paywall on app open.

## What shipped (commits, oldest→newest)
1. `0d0be24` Pass 1 — repaired the broken test harness: `TEST_HOST`/`BUNDLE_LOADER` still pointed at pre-rename `ScreenTimeShield.app` (product is now `Unplug.app`); no scheme included the unit-test target. Added `StoreKit.storekit`.
2. `ff9ff7d` Pass 2 — access-control seams as stubs + failing tests (AccessEvaluator, Grandfather, StatGate, StopDebouncer, EntitlementProviding, KeyValueStore, Store via SKTestSession).
3. `cc0383c` Pass 3 — implemented logic to green; real StoreKit 2 `Store`.
4. `479e510` Extracted pure logic into a local **`UnplugCore` Swift package** so unit tests run via `swift test` with **no simulator** (`cd UnplugCore && swift test` — 18 tests, ~instant). App + shield extension depend on it.
5. `31c61d3` Pass 4 — wired behaviour: `AccessController` (app-only, owns trial + StoreKit state), `AppGroupStore`, `PaywallView`, trial countdown + gating in `ContentView`, gate-and-drain in `Schedule`/monitor extension, debounced "times stopped" counter in the shield extension, time-anchored notification.
6. `6042003` + `b90291f` — in-app **QA/Debug menu** (controls, then exposed via a bottom row). Drives trial/expiry/full-access/times-stopped in-process. **Two commits so the exposure is easy to revert before production.**
7. `8b1dd81` Bumped `CURRENT_PROJECT_VERSION` → **12** across all targets (app was 11, extensions were 1 — a mismatch that blocks upload).
8. `be8fe0b` String catalog update + stopped tracking `xcuserstate` (added `.gitignore`).
9. `778f8a6` **QA launch-env hook** `UNPLUG_SKIP_FC` — skips the Family Controls auth request + launch-time `AppTransaction`/StoreKit (both prompt for an Apple-ID sign-in on a simulator without one). Env-gated; revert before production.
10. `4ea5cba` Translated the 13 paywall/trial strings into all 10 languages; documented localization tooling in README.
11. `8a3c540` Always show the purchase CTA unless `.fullAccess` (was gated to `.trial`, so it vanished on expiry — left no buy path). Expired copy: "Trial ended · Unlock Unplug".
12. `ac6cb34` / `9613616` / `1ffaad3` Layout fixes — wrapped the locked-limits caption (was truncating), reverted a bad subtitle-padding attempt, then fixed the **real cause**: no scroll container → tall block-active content overflowed into the floating large title on short screens (16 Pro). Wrapped the screen in `GeometryReader` + `ScrollView` with `.frame(minHeight:)` (buttons stay pinned when content fits, scrolls when tall).

## Test story
- **Logic:** `cd UnplugCore && swift test` — 18 tests, native macOS, no simulator, ~instant. The fast loop.
- **StoreKit:** `SKTestSession` purchase/restore tests live in the hosted `ScreenTimeShieldTests` target. They **skip** under headless `xcodebuild` because the iOS 26 sim's StoreKit test daemon can't persist its config ("Error saving configuration file: SKInternalErrorDomain Code=3"). They run for real under Xcode GUI / device.

## Blockers hit (external — not code)
- **App Store Connect upload not possible from this machine:** archive fails at codesign (`errSecInternalComponent` — headless keychain can't reach the signing key); only a *development* cert is installed (no Apple Distribution); no upload credentials (API key / app-specific password).
- **App Store Connect frozen** by the in-progress developer-account country move (US → Ireland) — per `marketing-plan.md`.
- **iTunes Connect was down** during the session.
- **Simulator QA blocked:** Family Controls authorization requires an Apple-ID sign-in on the sim; the user's sign-in errored and looped. `UNPLUG_SKIP_FC` was added to bypass the app's own Apple-ID prompts, but the simulator's *system* iCloud/onboarding prompt still overlays. Created a throwaway **`QA-iPhone16Pro`** sim to reproduce the layout bug.

## Verified
- Full scheme builds green (app + 3 extensions + UnplugCore).
- Expired-state CTA confirmed on a real iPhone 16 Pro ("Trial ended · Unlock Unplug").
- Inactive/normal layout intact with the ScrollView (buttons pinned, title/subtitle spaced) on the 16 Pro sim.

## NOT done / next
- **Manual QA of the trial→paywall→purchase flow** on a real device (sim blocked).
- **Verify the ScrollView fix in block-active state on the real 16 Pro** (couldn't force active state in-sim).
- **Pass 5 — App Store Connect:** create the Non-Consumable IAP (`com.halfspud.ScreenTimeShield.lifetime`), set price → Free, submit first IAP with a build. Blocked on country move + upload setup.
- **Before production:** revert the QA menu exposure (`b90291f`) + QA env hook (`778f8a6`); confirm `MARKETING_VERSION` (1.3 may be released → likely bump to 1.4); confirm cutover build = 12 matches the actual IAP release.
- **UI redesign** — agreed to do a full main-screen redesign (not started). No iOS-native design skill available; will use HIG + `design-system.md` + screenshot-iterate against the sim.

## Notes / gotchas for next time
- `Model.swift` is shared with extensions — keep StoreKit/trial state OUT of it (it lives in app-only `AccessController`); extensions read a cached `enforcement_allowed` flag from the app group.
- All shared state uses the `group.screentimeshield` app group via `AppGroupStore`.
- Adding files to the (classic, non-synchronized) Xcode project requires the `xcodeproj` Ruby gem (installed `--user-install`).
- Available simulator runtime: iOS 26.3. Use `iPhone 16e`/`17`/`QA-iPhone16Pro`.
