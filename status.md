# Unplug — Status Tracker

## Bugs
- [ ] Notifications bug — needs investigation and documenting
- [ ] Outstanding bug mentioned in README — needs documenting

## Features
- [ ] Finish localization — original UI + new paywall/trial strings now translated across all 10 languages; QA-menu strings intentionally untranslated (reverted before prod). Spot-check quality.
- [ ] Search engine block (private browsing loophole — block search engines in settings) — **attempted, not solved.** Could not get reliable enforcement; no implementation landed in code. Needs a fresh approach.
- [x] Change pricing model — implemented (see Pricing section)
- [~] Full UI redesign — in progress on `ui-redesign`. Done: status-led layout (status banner → app-grid card → 24h range slider → pinned CTAs), gear→Settings sheet with the refocus toggle + QA entry moved off the main screen, NavigationStack migration, custom `ScheduleRangeSlider`, token-rendered app grid. Targets in `design/targets/`. **Follow-ups:** overnight schedules (slider is same-day only; backend supports wrap); real-device QA of token grid + block-active state (sim can't render real tokens or force active); split inline `ScheduleRangeSlider`/`SettingsView` into their own files.

## Polish
- [ ] Rework the time picker — current UX is confusing, needs a clearer interaction
- [ ] Optimise App Store page (description, screenshots, keywords)
- [ ] Remove orphaned `ScreenTimeShieldControlExtension.entitlements` (leftover from removed control center widget)
- [x] Write real unit tests — pure access/trial logic now tested in `UnplugCore` (`swift test`, no simulator)

## Pricing (free trial + lifetime IAP — see [[.worklog/2026-06-16-pricing-rework]])
- [x] Implement free download + 7-day trial + one-time "lifetime unlock" IAP, with grandfathering (code complete on `pricing-rework`, merged to main)
- [ ] Revisit the grandfathering logic
- [ ] **Revert QA before production** — remove the QA/Debug menu exposure (commit `b90291f`) and the `UNPLUG_SKIP_FC` launch hook (commit `778f8a6`). These shipped intentionally for TestFlight QA; pull them before the App Store submission.
- [ ] Manual QA the trial → paywall → purchase flow on a real device (simulator blocked by Family Controls Apple-ID auth)
- [ ] Verify the ScrollView layout fix in block-active state on a real iPhone 16 Pro
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
*last updated: 2026-06-16*
