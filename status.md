# Unplug — Status Tracker
- [~] **P1: Lifetime IAP** (`com.halfspud.ScreenTimeShield.lifetime`, Non-Consumable, $4.99) — **created in App Store Connect and "Ready to Submit."** All metadata in: 175 territories, US $4.99 base (36 storefronts manually set to local under-5 + 139 auto-adjust), 10 localizations, review screenshot + notes, tax = match parent. The "blocked by the account move" assumption was wrong — the only gate was an unaccepted *updated* Paid Applications agreement (now accepted); account is still US and IAPs work. Local testing wired via `StoreKit.storekit` (scheme reference). **Remaining:** the first IAP must be **submitted with an app build** (can't go live standalone); optionally swap the review screenshot for a post-em-dash-fix capture.
- [ ] P1: Triage remaning todos, grandfather logic and anything critical. Need to move to marketing

## Bugs
- [x] **Family Controls authorization not handled** (was a release blocker) — was: request at launch + swallow errors, so a denied/revoked/restricted user saw a working-looking app that enforced nothing (also surfaced as the spurious "selection was reset" toast). **Implemented:** `AccessController` now tracks `AuthorizationCenter.authorizationStatus` (live + re-read on scenePhase); when not `.approved`, `ContentView` shows `PermissionDeniedView` in place of the app card and disables the arm/quick CTAs. **There is no per-app Screen Time toggle in iOS Settings**, but re-calling `requestAuthorization` re-shows the system prompt — so the denied view is a single **"Allow access"** button that re-requests directly (no Settings trip). `UNPLUG_SKIP_FC` bypasses the gate. Strings localized ×10. **Verified on device** (deny → denied UI → tap Allow → prompt reappears → approve → returns to app list). Merged to `main`. Note: revoking auth in system settings while the app is running doesn't update `authorizationStatus` until next cold launch (Apple bug) — acceptable.
- [x] "App selection was reset" toast firing every launch — `has_selection` persisted true while invalidated tokens decoded empty; now surfaced once then the flag is cleared (`ContentView.onAppear`).
- [x] Arm-confirm UI stall — the synchronous `DeviceActivityCenter` start/stop XPC ran on the main thread (4 calls on confirm), freezing the UI. Moved off-main onto a serial queue in `Schedule` (UI/`Model` mutations stay on main; values captured before dispatch). Builds clean; **needs on-device confirm** (instant dismiss + enforcement still works). Note: `Schedule` still swallows `startMonitoring` errors (`catch { print }`) — likely culprit if a block ever silently fails to register; surface/validate next.
- [ ] Notifications bug — needs investigation and documenting
- [ ] Outstanding bug mentioned in README — needs documenting

## Features
- [ ] Finish localization — original UI + paywall/trial + the new `ui-redesign` strings (arm/Block-Allow/add-apps/confirm copy) now translated across all 10 languages; verified German renders on-sim. **Remaining:** native-speaker quality spot-check (machine-quality translations), and decide whether the brand wordmark should stay "Unplug" instead of its localized app-name (e.g. German "Netzstecker ziehen"). QA-menu strings intentionally untranslated.
- [ ] Search engine block (private browsing loophole — block search engines in settings) — **attempted, not solved.** Could not get reliable enforcement; no implementation landed in code. Needs a fresh approach.
- [x] Change pricing model — implemented (see Pricing section)
- [x] Full UI redesign — **merged to `main`**. Done: status-led layout (header → status banner → app-grid card → 24h range slider → pinned CTAs); gear→Settings sheet (refocus toggle + QA moved there); custom `ScheduleRangeSlider`; icon+name `RestrictedAppList` that flexes to fill height; **Block/Allow-only schedule mode** (handles wrapping windows incl. overnight & "block all except X" — `Model.blockedInterval`); **explicit arm/disarm model** ("Start blocking"/"Stop blocking"/"Blocking", no auto-arm on edit) with a **conditional confirm** for risky arming (`UnplugCore/ScheduleMath`, unit-tested); obvious add-apps affordance ("+ Choose apps & websites" / "+ Add"); paywall surfaced only from the trial chip + primary CTA; in-content header (dropped `NavigationStack`); QA "Reset to fresh install" debug button. All view components split into their own files; `AppGrid` removed (replaced by the list). Fixed a bug where toggling Block/Allow (or editing times) started a block — schedule-window/mode edits now **disarm while inactive**, so only an explicit Start arms. Targets in `design/targets/`.
  - **Redesign follow-ups:** merge → `main`; **real-device QA** (arm→confirm→disarm, wrapping-interval enforcement, active-block removal guard, real token icons in the list — sim can't do these); translate new strings; confirm the "schedule edit disarms while armed" behavior on device, or switch to a confirm-on-activate alternative; optional polish (list "+" tile, header on Dynamic Island, "1 apps"→"1 app").

## Polish
- [x] Rework the time picker — replaced the start/end `DatePicker`s with the `ScheduleRangeSlider` + Block/Allow mode on `ui-redesign`
- [ ] Optimise App Store page (description, screenshots, keywords)
- [ ] Remove orphaned `ScreenTimeShieldControlExtension.entitlements` (leftover from removed control center widget)
- [x] Write real unit tests — pure access/trial + schedule logic tested in `UnplugCore` (`swift test`, no simulator)

## Pricing (free trial + lifetime IAP — see [[.worklog/2026-06-16-pricing-rework]])
- [x] Implement free download + 7-day trial + one-time "lifetime unlock" IAP, with grandfathering (code complete on `pricing-rework`, merged to main)
- [~] Revisit the grandfathering logic — **reworked**: switched from a build-number comparison (`cutoverBuild`/`originalAppVersion`) to a date comparison (`PricingConfig.cutoverDate` vs `AppTransaction.originalPurchaseDate`). The old check was broken by our per-version build-number resets (semver-style patch resets meant future low-build downloads would be wrongly grandfathered). Date is monotonic and immune to that. `swift test` green.
  - [x] **Cutover date set** — `PricingConfig.cutoverDate` = **2026-06-25** (target release, ~1 week out). Users who downloaded before this are grandfathered. **Adjust if the release date slips.** (Tests use their own boundary constant and stay green.)
- [ ] **Revert QA before production** — remove the QA/Debug menu exposure (commit `b90291f`), the `UNPLUG_SKIP_FC` launch hook (commit `778f8a6`), the `UNPLUG_SKIP_FC` guard added to the `scenePhase`/`AppDelegate` paths, and the "Reset to fresh install" QA button (`AccessController.qaResetToFreshInstall` + its QAMenu entry) on `ui-redesign`. These shipped intentionally for TestFlight QA; pull them before the App Store submission.
- [ ] Manual QA the trial → paywall → purchase flow — the **purchase** part is testable now via the local StoreKit Configuration file (no App Store Connect / account-move dependency); only the Family-Controls bits need a real device (simulator blocked by Family Controls Apple-ID auth)
- [ ] Verify the main-screen layout in block-active state on a real device — the old `ScrollView`/`minHeight` hack was removed on `ui-redesign` (now a fixed layout with a flexible, internally-scrolling app list); confirm it holds on short + tall devices and while a block is active
- [x] App Store Connect: created the Non-Consumable IAP (`com.halfspud.ScreenTimeShield.lifetime`), $4.99, 175 territories, 10 localizations, review screenshot + notes — status **Ready to Submit** (driven via Chrome). Only gate was accepting the updated Paid Applications agreement (done); account still US. **Still must be submitted *with* an app build to go live.**
- [x] Versioning for release — **1.3 was never released, so `MARKETING_VERSION` stays 1.3**; bumped `CURRENT_PROJECT_VERSION` (build) 12 → **13**. Grandfathering is date-based now, so the build number no longer affects it.

## Marketing
- [ ] Execute marketing plan — see [[marketing-plan]]

## Done
- [x] Core app shipped and working
- [x] Shield UI (dark theme, no bypass)
- [x] Daily repeating schedules
- [x] Quick "restrict for next hour" action
- [x] Refocus notifications (5-min intervals outside blocked hours)
- [x] Localization scaffolding for 10 languages
- [x] String catalog (`Localizable.xcstrings`) set up

---
*last updated: 2026-06-18*
