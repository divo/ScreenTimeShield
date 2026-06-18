# Unplug — Status Tracker
- [ ] **P1: Set up & test the lifetime IAP** (`com.halfspud.ScreenTimeShield.lifetime`, Non-Consumable). Two *independent* parts — don't conflate them:
  - **Testing — NOT blocked, do now:** the full trial → paywall → purchase → grandfather flow runs against the local **StoreKit Configuration file** (`StoreKit.storekit` in the project), with no App Store Connect and no dependency on the account move. Verify the lifetime product is defined there, then exercise purchase/restore in the simulator.
  - **Production — blocked by the account move:** creating/selling the IAP in App Store Connect requires an active **Paid Applications Agreement**, which is pending until Step 2 of the US→Ireland move (banking/tax/agreement) completes — see [[account-country-move]]. The country change itself does *not* touch existing apps or IAPs (app IDs unchanged), so nothing needs recreating.
- [ ] P1: Triage remaning todos, grandfather logic and anything critical. Need to move to marketing

## Bugs
- [ ] Notifications bug — needs investigation and documenting
- [ ] Outstanding bug mentioned in README — needs documenting

## Features
- [ ] Finish localization — original UI + paywall/trial + the new `ui-redesign` strings (arm/Block-Allow/add-apps/confirm copy) now translated across all 10 languages; verified German renders on-sim. **Remaining:** native-speaker quality spot-check (machine-quality translations), and decide whether the brand wordmark should stay "Unplug" instead of its localized app-name (e.g. German "Netzstecker ziehen"). QA-menu strings intentionally untranslated.
- [ ] Search engine block (private browsing loophole — block search engines in settings) — **attempted, not solved.** Could not get reliable enforcement; no implementation landed in code. Needs a fresh approach.
- [x] Change pricing model — implemented (see Pricing section)
- [~] Full UI redesign — on `ui-redesign`, feature-complete, **ready to merge pending device QA + translations**. Done: status-led layout (header → status banner → app-grid card → 24h range slider → pinned CTAs); gear→Settings sheet (refocus toggle + QA moved there); custom `ScheduleRangeSlider`; icon+name `RestrictedAppList` that flexes to fill height; **Block/Allow-only schedule mode** (handles wrapping windows incl. overnight & "block all except X" — `Model.blockedInterval`); **explicit arm/disarm model** ("Start blocking"/"Stop blocking"/"Blocking", no auto-arm on edit) with a **conditional confirm** for risky arming (`UnplugCore/ScheduleMath`, unit-tested); obvious add-apps affordance ("+ Choose apps & websites" / "+ Add"); paywall surfaced only from the trial chip + primary CTA; in-content header (dropped `NavigationStack`); QA "Reset to fresh install" debug button. All view components split into their own files; `AppGrid` removed (replaced by the list). Fixed a bug where toggling Block/Allow (or editing times) started a block — schedule-window/mode edits now **disarm while inactive**, so only an explicit Start arms. Targets in `design/targets/`.
  - **Redesign follow-ups:** merge → `main`; **real-device QA** (arm→confirm→disarm, wrapping-interval enforcement, active-block removal guard, real token icons in the list — sim can't do these); translate new strings; confirm the "schedule edit disarms while armed" behavior on device, or switch to a confirm-on-activate alternative; optional polish (list "+" tile, header on Dynamic Island, "1 apps"→"1 app").

## Polish
- [x] Rework the time picker — replaced the start/end `DatePicker`s with the `ScheduleRangeSlider` + Block/Allow mode on `ui-redesign`
- [ ] Optimise App Store page (description, screenshots, keywords)
- [ ] Remove orphaned `ScreenTimeShieldControlExtension.entitlements` (leftover from removed control center widget)
- [x] Write real unit tests — pure access/trial + schedule logic tested in `UnplugCore` (`swift test`, no simulator)

## Pricing (free trial + lifetime IAP — see [[.worklog/2026-06-16-pricing-rework]])
- [x] Implement free download + 7-day trial + one-time "lifetime unlock" IAP, with grandfathering (code complete on `pricing-rework`, merged to main)
- [~] Revisit the grandfathering logic — **reworked**: switched from a build-number comparison (`cutoverBuild`/`originalAppVersion`) to a date comparison (`PricingConfig.cutoverDate` vs `AppTransaction.originalPurchaseDate`). The old check was broken by our per-version build-number resets (semver-style patch resets meant future low-build downloads would be wrongly grandfathered). Date is monotonic and immune to that. `swift test` green.
  - [ ] **Pick the final cutover date before release** — `PricingConfig.cutoverDate` is currently a placeholder (2026-06-18). Set it to the actual IAP go-live date (and keep the test constant in `AccessControlTests.swift` in sync).
- [ ] **Revert QA before production** — remove the QA/Debug menu exposure (commit `b90291f`), the `UNPLUG_SKIP_FC` launch hook (commit `778f8a6`), the `UNPLUG_SKIP_FC` guard added to the `scenePhase`/`AppDelegate` paths, and the "Reset to fresh install" QA button (`AccessController.qaResetToFreshInstall` + its QAMenu entry) on `ui-redesign`. These shipped intentionally for TestFlight QA; pull them before the App Store submission.
- [ ] Manual QA the trial → paywall → purchase flow — the **purchase** part is testable now via the local StoreKit Configuration file (no App Store Connect / account-move dependency); only the Family-Controls bits need a real device (simulator blocked by Family Controls Apple-ID auth)
- [ ] Verify the main-screen layout in block-active state on a real device — the old `ScrollView`/`minHeight` hack was removed on `ui-redesign` (now a fixed layout with a flexible, internally-scrolling app list); confirm it holds on short + tall devices and while a block is active
- [ ] App Store Connect: create the Non-Consumable IAP (`com.halfspud.ScreenTimeShield.lifetime`) and submit with a build. **Blocked specifically by Step 2 of the country move** — the Paid Applications Agreement + Irish banking/tax must be active before an IAP can be created/sold in ASC (see [[account-country-move]]). NOTE: IAPs have **no free price tier** (min ~$0.49); the earlier "price → Free" wording is wrong unless it meant the app *download* is free — resolve the intended price before setup.
- [ ] Confirm `MARKETING_VERSION` (1.3 may be released → likely bump). Grandfathering no longer depends on the build number (now date-based — see Pricing section); just set `PricingConfig.cutoverDate` to the real IAP go-live date.

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
