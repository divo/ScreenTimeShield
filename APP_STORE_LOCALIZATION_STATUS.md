# App Store Connect Localization — Status & Handoff

**App:** Unplug Screentime · **App ID:** 6462699154 · **Version:** 1.3 (Prepare for Submission)
**Date:** 2026-06-19

> **✅ UPDATE — localization COMPLETE (done via the App Store Connect REST API).**
> All 10 non-English storefronts (de-DE, es-ES, es-MX, fr-FR, it, pt-PT, ja, ko, zh-Hans, zh-Hant)
> now have localized **Name + Subtitle + Description + Keywords** and **4× 6.5" screenshots**
> (all assets COMPLETE), as drafts. The API approach (recommendation #1 below) eliminated the
> name cascade / 1Password / tab issues. Names use localized "Screen Time" (e.g. "Unplug
> Bildschirmzeit", "Unplug スクリーンタイム") — accepted with zero conflicts. en-US unchanged.
> **Remaining:** submit v1.3 for review (gated on US→Ireland account move); optionally delete the
> stale old 5.5" English screenshots; trademark action on the copycat is now optional.
> The sections below are the original pre-API handoff, kept for history.

## TL;DR

The blocker is **the localized app NAME (title) field**, not the subtitles/descriptions/keywords themselves.

- To add a localized **Subtitle** on the App Information page, App Store Connect (ASC) **requires a localized Name** too (Name is mandatory per localization; it cannot be left blank to inherit the primary).
- Apple enforces **app-name uniqueness per storefront** (plus fuzzy "confusingly similar" matching). Reusing the primary name **"Unplug Screentime"** is rejected in several locales with: *"the app name you entered is already being used. If you have trademark rights to this name… submit a claim."*
- Likely cause: the copycat app **"Bildschirmzeit: Unplugged"** (present in the German, English, and Spanish stores) + Apple's similarity matching on "Unplug" + screen-time terms. (Owner believes that app copied this one and was published later — possible trademark action to pursue separately.)
- **Workaround:** give each locale a distinct localized Name (e.g. translate "screen time" or use "Unplug - Focus").
- **Instability:** ASC's Save on the App Information page re-validates/re-submits **all** localizations at once. Saving one locale intermittently re-flags a *different*, previously-good locale's Name as "already being used." It cycles instead of converging, and ASC throws intermittent "Sorry, something went wrong" server errors. This is the main reason progress stalled.

## What the task is

Localize the listing into 9 locales: **de, es, fr, it, pt-PT, ja, ko, zh-Hans, zh-Hant**
(Owner decided **es = both es-MX and es-ES**, so effectively 10 storefronts.)

For each: localized **Subtitle** (App Information page), **Description** + **Keywords** (Version 1.3 page), and **4 screenshots** in the iPhone 6.5" slot (Version page). Source copy is in the original handoff (`localization-handoff.md`).

Field limits: Subtitle ≤30, Keywords ≤100, Description ≤4000.

## Two locations in ASC (important distinction)

| Field | Page | Name-conflict risk? |
|---|---|---|
| App **Name** + **Subtitle** | App Information (`/distribution/info`) | **YES** — Name is the problem |
| **Description, Keywords, Promo, What's New, Screenshots** | Version 1.3 (`/distribution/ios/version/inflight`) | **No** — no Name field here |

The Description / Keywords / Screenshots (the bulk of the work) have **none** of these conflicts. They have **not been started yet**.

## Current persisted state — App Information (as of last check)

| Locale | Name used | Subtitle | Status |
|---|---|---|---|
| English (U.S.) — primary | Unplug Screentime | Unstoppable App Limits | unchanged |
| German | `Unplug - Focus` | Unumgehbare App-Limits | ✅ saved |
| Spanish (Mexico) | `Unplug – Tiempo de uso` | Límites que no puedes saltar | ✅ saved |
| Spanish (Spain) | `Unplug – Tiempo de uso` | Límites que no puedes saltar | ✅ saved |
| French | `Unplug : Temps d'écran` | Des limites incontournables | ✅ saved (after remove + re-add) |
| Italian | `Unplug – Tempo di utilizzo` | Limiti che non puoi saltare | ⚠️ flagged "already being used" on last reload |
| Portuguese (Portugal) | (attempted `Unplug – Tempo de ecrã`) | Limites que não podes saltar | ❌ removed; needs re-add |
| Japanese | — | — | not started |
| Korean | — | — | not started |
| Chinese (Simplified) | — | — | not started |
| Chinese (Traditional) | — | — | not started |

Note: the "flagged/clean" status cycles between Italian/French/Portuguese on successive saves due to the re-validation behavior below, so treat the table as a snapshot.

## Names tried (Name field only)

- German `Unplug – Bildschirmzeit` → **rejected** (too similar to "Bildschirmzeit: Unplugged"). `Unplug - Focus` → **accepted**.
- French `Unplug : Temps d'écran` → **accepted** (when added fresh).
- Italian `Unplug – Tempo di utilizzo`, Spanish `Unplug – Tiempo de uso` → **accepted** at least once, but get re-flagged on later saves.
- Portuguese `Unplug – Tempo de ecrã` → **rejected / unstable**.

## Root technical findings (for the orchestrator)

1. **Subtitle requires Name.** A localized Subtitle cannot exist without a localized Name (mandatory field). So "just localize the subtitle" is not possible without solving the Name.
2. **Name uniqueness is per-storefront + fuzzy.** "Unplug Screentime" collides in multiple stores. Distinct per-locale names are required.
3. **Save is all-or-nothing-ish across locales.** The App Information Save re-validates/re-submits every localization. A single bad/duplicate Name makes the whole save error and can revert or re-flag other locales. Cascading, non-convergent.
4. **Intermittent ASC server errors** ("Sorry, something went wrong") during rapid programmatic saves — may be aggravated by automation speed.
5. **Multiple concurrent ASC browser tabs corrupt save state** — each tab holds its own unsaved React state and they clobber each other's saves. Must use a single tab.
6. **1Password autofill hijacks the Name field** — its inline iframe steals focus and blocks clicks/keystrokes/scripts on the tab. Workaround used: set input values via React-aware JS (native `HTMLInputElement` value setter + dispatch `input`/`change`/`blur`) instead of typing, and/or disable 1Password for `appstoreconnect.apple.com`.

## Recommendations

1. **Strongly consider the App Store Connect API instead of browser automation** for the metadata. Endpoints `appInfoLocalizations` (Name/Subtitle) and `appStoreVersionLocalizations` (Description/Keywords/screenshots via `appScreenshotSets`) are far more deterministic than the React UI and avoid the cascade/1Password/tab issues entirely. This is the single biggest reliability win.
2. **Decide a final, conflict-free Name scheme up front** for all non-English locales (one batch, distinct names), e.g. "Unplug - Focus" everywhere, or per-language translations. Enter once; don't iterate.
3. If staying in the UI: **edit and Save one localization per page load, reload between each**, to avoid re-submitting (and re-breaking) already-saved locales.
4. **Separate the two workstreams:** the Description/Keywords/Screenshots (Version page) are unblocked and high-value — do those independently of the Name puzzle.
5. **Trademark:** if Unplug owns the mark, pursue the "Bildschirmzeit: Unplugged" copycat via Apple's name-claim / dispute process; that could free up the original names.

## Not yet done

~~App Information subtitles~~ ✅ done (all 10 locales, via API)
~~Version Descriptions + Keywords~~ ✅ done (all 10 locales, via API)
~~All screenshots (4 per locale, 6.5")~~ ✅ done (all 11 locales 4/4 COMPLETE, via API — no native dialog needed)

Genuinely remaining:
- **Submit v1.3 for review** — intentionally not done; gated on the US→Ireland account move.
- Delete the stale old pre-redesign **5.5" English screenshots** (left from the earlier browser session) so they don't ship.
- Optional/adjacent: trademark action on the "Bildschirmzeit: Unplugged" copycat; Accessibility (VoiceOver) metadata; EU trader disclosure on the Irish entity.
