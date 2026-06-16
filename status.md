# Unplug — Status Tracker

## Bugs
- [ ] Notifications bug — needs investigation and documenting
- [ ] Outstanding bug mentioned in README — needs documenting

## Features
- [ ] Finish localization — partially done, needs review across all 10 languages
- [ ] Search engine block (private browsing loophole — block search engines in settings) — **attempted, not solved.** Could not get reliable enforcement; no implementation landed in code. Needs a fresh approach.
- [ ] Change pricing model — rework how pricing works (see below)

## Polish
- [ ] Rework the time picker — current UX is confusing, needs a clearer interaction
- [ ] Optimise App Store page (description, screenshots, keywords)
- [ ] Remove orphaned `ScreenTimeShieldControlExtension.entitlements` (leftover from removed control center widget)
- [ ] Write real unit tests (currently boilerplate only)

## Pricing
- [ ] Change how pricing works — currently $1 one-time upfront purchase. Decide and implement the new model (details TBD). Touches App Store Connect pricing config and possibly in-app purchase/StoreKit code.

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
