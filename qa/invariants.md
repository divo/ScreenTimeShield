# Invariants — features 3, 4, 9

The spec that bugs are judged against. Every entry is **intended** behaviour, derived from code
comments, `status.md`, `CLAUDE.md` and the product promise ("a block cannot be bypassed"). Nothing
here is an assertion that the code is correct — these are the statements a bug would violate.

Grounding sources per invariant are cited so a reviewer can check the intent claim itself.

---

## F3 — Schedule configuration

**Files:** `ScreenTimeShield/ScheduleRangeSlider.swift`, `ScreenTimeShield/ScheduleCard.swift`,
`UnplugCore/Sources/UnplugCore/ScheduleMath.swift`, `ScreenTimeShield/Model.swift:36-53`

| ID | Invariant | Grounded in |
|---|---|---|
| F3.1 | The minute↔pixel mapping round-trips: for every 5-minute `m` in `[0, 1440]`, `minute(forX: x(for: m)) == m`. | `ScheduleRangeSlider.swift:44-52` — the two functions are declared inverses ("everything shares one coordinate system") |
| F3.2 | Both handles map time onto the same inset coordinate space as the track, fill and axis labels, so no element is drawn out of alignment with the value it represents. | `ScheduleRangeSlider.swift:28-30` comment |
| F3.3 | The window is never shorter than `minGap` (15 min), under any drag order or speed, and `start` never crosses `end`. | `ScheduleRangeSlider.swift:25`, `:129-138` |
| F3.4 | `dateAtMinute(_:)` always yields a real `Date` at the requested hour/minute — it never silently falls back to `Date()` (i.e. "now"), which would substitute an unrelated time for the user's choice. | `ScheduleRangeSlider.swift:39-42` — the `?? Date()` is a fallback, not an intended behaviour |
| F3.5 | The window the user sees on the slider and the interval handed to `DeviceActivitySchedule` always describe the same span of wall-clock time, in **both** modes. | `Model.swift:34-38`, `ScheduleCard.swift:23-29` |
| F3.6 | In Allow-only mode the blocked interval is exactly the complement of the picked window within a day. | `Model.swift:28-29`, `:36-38` |
| F3.7 | A schedule is only ever registered for a non-degenerate interval; `start == end` after inversion must not be handed to the system as if it were meaningful. | `ScheduleMath.windowContains` treats `start == end` as empty (`ScheduleMath.swift:17`), so the app's own math and the system must agree |
| F3.8 | Displayed times are consistent with each other: handle pills, the "now" marker and the hour axis all use one clock convention for the user's locale. | `ScheduleRangeSlider.swift:54-56` uses locale-aware `.shortened`; `:160` hardcodes `%02d:00` |
| F3.9 | Editing the window is impossible while a block is active — the picker is disabled, gestures are removed, and no write to `start`/`end` can occur. | `ScheduleCard.swift:21`, `ScheduleRangeSlider.swift:129`; `status.md` "Schedule locked while a block is active" |
| F3.10 | The persisted window survives a cold launch and a timezone change without changing the user's intended local hours. | `Model.swift:41-53` persists absolute `Date`s but only hour/minute are ever used (`Schedule.components(from:)`) |
| F3.11 | `freeMinutes` correctly reports unblocked minutes for the *effective* mode, since it gates the risk confirmation. | `ScheduleMath.swift:29-32`, consumed at `ContentView.swift:129-132` |

---

## F4 — Arm / disarm

**Files:** `ScreenTimeShield/ContentView.swift:37-133`, `ScreenTimeShield/Schedule.swift`,
`ScreenTimeShield/Model.swift`, `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift`

| ID | Invariant | Grounded in |
|---|---|---|
| F4.1 | `model.isArmed` is true **iff** a `.daily` activity is registered with `DeviceActivityCenter`. | `Model.swift:30-32` ("Whether the daily schedule is currently registered (armed)"), resynced at `ContentView.swift:248` |
| F4.2 | Only an explicit "Start blocking" tap ever arms. No edit — of selection, window, or mode — can start a block. | `ContentView.swift:57-58`, `:90-92`, `:230-232`; `status.md` "explicit arm/disarm model … no auto-arm on edit" |
| F4.3 | No reachable path leaves `insideInterval == true` while nothing is registered to eventually clear it. This is the lock-out state: the UI would show "Blocking" with a disabled CTA forever. | `ContentView.swift:44-46` disables the CTA on `insideInterval`; only the extension clears it (`DeviceActivityMonitorExtension.swift:74-78`) |
| F4.4 | While `insideInterval`, the enforced token set can only grow. No user action removes an app, category or domain from an active block. | `ContentView.swift:218-229`, `Model.validateRestriction()` `Model.swift:74-81`; product promise |
| F4.5 | While `insideInterval`, the schedule window and mode cannot change. | `ContentView.swift:44-46`, `ScheduleCard.swift:21` |
| F4.6 | Every arm attempt either results in a registered schedule or surfaces a failure to the user. A registration error must not leave the UI claiming a block is armed. | `Schedule.swift:36-39` currently only `print`s; `status.md` flags this: "`Schedule` still swallows `startMonitoring` errors … surface/validate next" |
| F4.7 | Disarming stops **every** activity that could re-apply restrictions, and clears the active shields. | `ContentView.swift:82-86` |
| F4.8 | Re-registering a schedule (after a selection edit) never widens or narrows the currently-enforced block, and never strands `insideInterval`. | `ContentView.swift:228` → `applySchedule()` `:59-68` |
| F4.9 | Start/stop ordering is preserved under rapid interaction: a stop followed by a start cannot land out of order, and no interaction storm can queue unbounded XPC work. | `Schedule.swift:18-23` comment (serial queue exists precisely for this) |
| F4.10 | Nothing in the arm path blocks the main thread long enough to stall the UI. | `Schedule.swift:18-21`; `status.md` bug entry "Arm-confirm UI stall" |
| F4.11 | The risk confirmation is shown whenever arming would lock the user in immediately or leave ≤30 free minutes, and the message shown matches what will actually happen. | `ContentView.swift:123-148` |
| F4.12 | The notification schedule registered as a side effect of arming is torn down whenever the block is torn down, and never outlives it. | `ContentView.swift:64-67`, `:84` |
| F4.13 | A determined user cannot end an active block early by any means available on the device short of the documented escape hatches. | Product promise; `README.md` "No bypass" |

---

## F9 — Trial / paywall / lifetime unlock

**Files:** `ScreenTimeShield/Store.swift`, `ScreenTimeShield/AccessController.swift`,
`UnplugCore/Sources/UnplugCore/AccessControl.swift`, `ScreenTimeShield/PaywallView.swift`

| ID | Invariant | Grounded in |
|---|---|---|
| F9.1 | The trial start date is written exactly once and never moved forward or backward by normal use. | `AccessController.swift:83-90` ("No-op afterwards") |
| F9.2 | `accessState == .expired` implies no restrictions are ever newly applied — the cached `enforcement_allowed` gate is authoritative for the extensions. | `AccessController.swift:117-118`, `DeviceActivityMonitorExtension.swift:56-59` ("Defense-in-depth") |
| F9.3 | The gate is fail-safe for legitimate users: a missing value must not disable a paying or grandfathered user's blocks. | `DeviceActivityMonitorExtension.swift:41-44` (explicit comment) |
| F9.4 | A grandfathered user (original download before `cutoverDate`) never loses access — including offline, after a reinstall, and on every cold launch. | `AccessControl.swift:22-27`, `Store.swift:70-81`; `status.md` grandfathering section |
| F9.5 | Entitlement state survives a cold launch with no network. A paid user is never shown the paywall because a server was unreachable. | `Store.swift:78-80` ("leave prior value untouched") |
| F9.6 | A completed purchase always results in `.fullAccess` being reflected in the UI, including purchases that complete outside the foreground buy flow (Ask to Buy, interrupted, restored on another device). | `Store.swift:33-49`, `PaywallView.swift:120-122` |
| F9.7 | Every verified transaction is finished exactly once, so StoreKit stops re-delivering it. | `Store.swift:42` |
| F9.8 | A revoked or refunded purchase removes full access. | `Store.swift:62` (`revocationDate == nil` check) |
| F9.9 | Access state cannot be improved by any client-side action available to a normal user (clock change, reinstall, offline, storage manipulation). | Revenue integrity; `status.md` pricing section |
| F9.10 | `trialDaysRemaining` is monotonically non-increasing over real time and never displays a misleading count (e.g. "0 days left" while still in trial, or a count before the trial has started). | `AccessControl.swift:60-69`, rendered at `TrialChip.swift:21` |
| F9.11 | Trial expiry that lands mid-block leaves the user in a coherent state: either the block continues to its natural end or it is cleanly torn down — not "armed but silently unenforced". **⚠️ This wording is now known to be misleading** — V19's verifier established the real defect is not the mid-block landing but that nothing ever tears down the registered `.daily` schedule on expiry. Fixing "F9.11" from this text alone would produce an unnecessary mid-block guard and miss the actual bug; read V19 and V21 in `qa/findings.md` instead. | `AccessController.swift:112-120` + `applySchedule` guard `ContentView.swift:60`; the "gate-and-drain" claim at `DeviceActivityMonitorExtension.swift:54-55` |
| F9.12 | The QA overrides (`qa_force_full_access`, injected trial dates) cannot affect a production user, and a value left behind by a QA build does not silently grant access. | `AccessController.swift:145-154`; `status.md` "QA hidden for production" |
| F9.13 | The cutover boundary is exact and total: every user is either grandfathered or not, with no undefined case (nil `originalPurchaseDate`, equal timestamps). | `AccessControl.swift:73-78` |
