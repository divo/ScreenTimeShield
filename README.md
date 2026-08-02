# Unplug

## Goal
Market the app and grow downloads. Bug fix + search engine block feature also pending.

## Status: Shipped — needs marketing push

## What it is
iOS app ($1). Blocks apps on a schedule with no way to bypass.
Divo built it, uses it himself (blocks apps at 10pm).

## Platform
- iOS only
- **Currently** $0.99 upfront on the App Store
- **From 1.3 (unshipped)** free download + 7-day trial + a one-time $4.99 "lifetime unlock" IAP.
  Anyone whose original download predates `PricingConfig.cutoverDate` keeps permanent free access
- Some existing users

## Key Differentiator
No bypass. iOS Screen Time can be circumvented in seconds. Unplug can't.

## Pending Work

`status.md` is the canonical task list. Highlights:

- [ ] Ship 1.3 with the lifetime IAP — build 17 is currently a **dev build that must not be
      submitted**; see the revert checklist at the top of `status.md`
- [ ] Finish the QA fix pass — 9 of 17 done, remaining work and per-finding status in `qa/README.md`
- [ ] Run `qa/device-matrix.md` on a real phone; none of the fixes have been observed working yet
- [ ] Add search engine block (private browsing loophole — block search engines in settings)
- [ ] Optimise App Store page (description, screenshots, keywords)
- [ ] Execute marketing plan → see marketing-plan.md

## Localization
Strings live in `Localizable.xcstrings` (10 languages: en, de, es, fr, it, ja, ko, pt-PT, zh-Hans, zh-Hant). The original UI strings were translated with an early version of the **String Catalog – AI Translate** tool (https://sergey-rezanov.github.io/string-catalog/). New strings since then have been translated with Claude Code. There's no tool config checked into the repo.

## Notes
- Small win potential — already built and shipped, just needs push
- Passive income if maintained and marketed well
