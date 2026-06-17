# Unplug — Status Tracker

## Bugs
- [ ] Notifications bug — needs investigation and documenting
- [ ] Outstanding bug mentioned in README — needs documenting

## Features
- [ ] Finish localization — original UI + paywall/trial strings translated across all 10 languages. **New `ui-redesign` strings are English-only** (arm/Block-Allow/add-apps copy: "Start blocking", "Block these hours", "Choose apps & websites", confirm messages, etc.) — extracted to the catalog, not yet translated. QA-menu strings intentionally untranslated.
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
- [ ] Revisit the grandfathering logic
- [ ] **Revert QA before production** — remove the QA/Debug menu exposure (commit `b90291f`), the `UNPLUG_SKIP_FC` launch hook (commit `778f8a6`), the `UNPLUG_SKIP_FC` guard added to the `scenePhase`/`AppDelegate` paths, and the "Reset to fresh install" QA button (`AccessController.qaResetToFreshInstall` + its QAMenu entry) on `ui-redesign`. These shipped intentionally for TestFlight QA; pull them before the App Store submission.
- [ ] Manual QA the trial → paywall → purchase flow on a real device (simulator blocked by Family Controls Apple-ID auth)
- [ ] Verify the main-screen layout in block-active state on a real device — the old `ScrollView`/`minHeight` hack was removed on `ui-redesign` (now a fixed layout with a flexible, internally-scrolling app list); confirm it holds on short + tall devices and while a block is active
- [ ] App Store Connect: create the Non-Consumable IAP (`com.halfspud.ScreenTimeShield.lifetime`), set price → Free, submit first IAP with a build (blocked by US→Ireland account move)
- [ ] Confirm `MARKETING_VERSION` (1.3 may be released → likely bump) and that cutover build = 12 matches the actual IAP release

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
*last updated: 2026-06-17*
