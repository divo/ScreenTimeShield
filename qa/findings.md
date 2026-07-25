# Findings — verified bug report (features 3, 4, 9)

Output of the adversarial verification stage. Every entry below was challenged by a skeptic
prompted to **refute** it, required to re-derive the failure trace from source and to check any
Apple API semantics it depended on against Apple's documentation. Findings classed as
bypass / lockout / revenue were escalated to a second, differently-lensed skeptic.

## Scoreboard

| Metric | Value |
|---|---|
| Clusters entering verification | 23 |
| **Confirmed** | **19** |
| Uncertain (turns on an unconfirmed runtime/API behaviour) | 3 |
| Refuted | 1 |
| Escalated to a second opinion | 16 |
| …where the second verifier disagreed with the first | 6 |
| Confirmed findings provable by a unit test today | 8 |

**Refutation rate 4%.** This is low, and it is
the number to be most skeptical about in this report. Two readings: the discovery stage's
evidence bar (no candidate without a concrete failure trace) filtered speculation before it
reached verification — or the verifiers were too agreeable. The
6 second-opinion disagreements are evidence for the first
reading, since they show verifiers were willing to contradict each other, but a human spot-check
of three findings is still the right next step before acting on the list.

**Not verified this round:** the 9 nit-severity clusters (V03, V10, V26–V32) were carried
forward unverified to keep agents on the important ones. They remain in `qa/candidates.md`.

Legend — **Impact class:** `bypass` = user escapes an active block (breaks the product promise);
`lockout` = legitimate user trapped or wrongly blocked; `revenue` = pays twice or gets it free.
**Proof:** `unit-testable` = provable now in `UnplugCore`/`SKTestSession`; `device` = needs a
real device; `reasoned` = argued from source only.

---

## Confirmed findings at a glance

| ID | Sev | Impact | Frequency | Proof | Finding |
|---|---|---|---|---|---|
| `V07` | 🔴 | bypass | occasional for an ordinary user (needs quick-restrict tapped inside the 60 min before the armed window starts); deterministic/repeatable for a user trying to break their own block | device | The one-hour quick block's intervalDidEnd clears a concurrently-active scheduled block (bypass) |
| `V14` | 🔴 | bypass | Split by leg. Wrong status display + inert CTA: common — it happens on any block that begins while the app is foregrounded, most notably the first-run habit of setting the window to start in a minute or two and watching. The stop-in-the-gap tap that actually deregisters .daily: adversarial-only, and even for the adversary it grants nothing they couldn't get one second earlier. The permanent-lockout tail: rare / adversarial-only (needs a tap inside the extension-launch race). | device | Disarm lock trusts a cross-process flag instead of the clock, so Stop blocking stays live during a block |
| `V01` | 🔴 | lockout | Two-tier. The core defect (end time silently replaced by the current clock) is **always** for the gesture the UI advertises — anyone who drags the end handle to the right end of the track hits it deterministically, not occasionally. The **~24h unstoppable block** on top of that is **occasional**: it additionally needs block-these-hours mode, `now < start`, and the user tapping Start despite a visibly collapsed window. Not adversarial in either tier — no hostile intent required. | reasoned | End handle at 24:00 -> Calendar returns nil -> `?? Date()` substitutes 'now' for the user's chosen end time |
| `V02` | 🔴 | lockout | common across the user base, occasional per user: guaranteed twice a year for every armed user in a DST-observing region (i.e. most of the 10 shipped locales), the moment they next open the app, plus any trip across time zones. Fires for a completely ordinary user who touches nothing — not an adversarial or self-sabotage path. | unit-testable | Window persisted as absolute Date but read as hour/minute in current zone -> silently shifts on DST change or travel |
| `V05` | 🔴 | lockout | Split, and the first verifier collapsed the two: the wrong-picture half is COMMON (every upgrader with a legacy overnight window — the app's core use case); the "23h45m block, no confirmation" lockout half is RARE (needs the collapsing end-handle drag AND arming within 30 min before the window start). | unit-testable | Risk gate and slider fill use non-wrapping window math while the registered interval wraps midnight |
| `V09` | 🔴 | lockout | rare via the mechanism as written (deliberate deselect-all while armed and pre-window); occasional via the token-invalidation variant of the same missing guard (see note) | device | Removing every selected app while armed leaves .daily registered, so the block activates and locks with nothing shielded |
| `V11` | 🔴 | lockout | common | device | App never observes the extension's inside_interval write, so lock-while-active UI does not engage in a foregrounded app |
| `V15` | 🔴 | lockout | rare — requires an out-of-band transaction (Ask to Buy approval, same-Apple-ID purchase on a second device, an externally-completed interrupted purchase) to land while this app is in an uninterrupted foreground session. Offer-code redemption and interrupted-purchase-on-relaunch both self-heal via the existing scenePhase/.task refreshes, so they do not hit it. Not an ordinary-evening bug for an ordinary paying user. | unit-testable | No Transaction.updates listener: out-of-band transactions never observed, never finished |
| `V18` | 🔴 | lockout | occasional | unit-testable | Grandfathered access is unpersisted derived state: one failed AppTransaction fetch demotes a legacy user to expired |
| `V20` | 🔴 | revenue | occasional for ordinary users (leak runs from trial end until the user's next foreground visit — days to weeks for a set-and-forget user); indefinite only for someone who deliberately never opens the app, i.e. the "free forever" version is closer to adversarial-but-trivial than to always | device | Enforcement gate only recomputed while foregrounded -> never reopen the app and the trial never expires |
| `V21` | 🔴 | revenue | common among users who convert after trial expiry (the app's own designed conversion path routes them into the window); occasional across all users. Not adversarial — the user is actively trying to make their block work. | device | Buying the unlock mid-window does not restore enforcement for the window already in progress |
| `V22` | 🔴 | revenue | Conditional: zero users today (1.3 is unshipped, so nothing can fire). Once 1.3 ships unchanged it is "always" — deterministic for 100% of the affected cohort on ordinary use, no adversarial action needed. Cohort is bounded and probably small: every $0.99 download between 2026-06-25 and the actual release (app is still paid and pre-marketing, `status.md:3` "Need to move to marketing"), growing one day per day of slip. | unit-testable | cutoverDate (2026-06-25) is already in the past while the IAP build is unshipped -> post-cutover paying users not grandfathered |
| `V23` | 🔴 | revenue | adversarial-only (but the adversary here is the ordinary user in a moment of weakness, which is this product's *primary* threat model — not an exotic attacker). No honest-clock user ever hits the backward path. A rare accidental variant exists (see note item 4). | unit-testable | Expired trial fully restored by moving the device clock backward |
| `V04` | 🔴 | ux | — | reasoned | At short windows the start handle is fully occluded by the end handle |
| `V16` | 🔴 | ux | — | unit-testable | purchase() collapses .pending and unverified into bare false; paywall shows no explanation |
| `V19` | 🔴 | ux | — | device | Nothing tears down the registered .daily schedule on expiry -> app sits 'armed but unenforced' |
| `V24` | 🟡 | revenue | rare — zero App Store users; only the developer's own device plus any tester of the pulled build 13 who deliberately flipped "Force full access" | reasoned | qa_force_full_access is read by release builds and can never be cleared once set |
| `V06` | 🟡 | ux | — | unit-testable | Allow-only mode can hand DeviceActivity a blocked interval shorter than the 15-minute minimum |
| `V17` | 🟡 | ux | — | reasoned | Restore asserts 'No previous purchase found' when AppStore.sync() actually failed (offline) |

---

## Confirmed (19)

Survived adversarial refutation.

### `V07` · The one-hour quick block's intervalDidEnd clears a concurrently-active scheduled block (bypass)

- **🔴 Important** · impact **bypass** · needs device · hit **occasional for an ordinary user (needs quick-restrict tapped inside the 60 min before the armed window starts); deterministic/repeatable for a user trying to break their own block**
- **Feature** F4 · **Discovery IDs** F4-STATE-01, F4-XPROC-02, F4-HOSTILE-01 (3 agents found this independently)
- **Already in status.md:** Not recorded. `status.md` has two undocumented placeholders — line 9 "Notifications bug — needs investigation and documenting" and line 10 "Outstanding bug mentioned in README — needs documenting" (README.md:21 "Fix outstanding bug (needs documenting)") — but neither names a mechanism, so neither can be matched to this. The only shield/schedule entries under "## Bugs" are the closed Family-Controls-authorization item and the closed arm-confirm main-thread XPC stall; `status.md:44` records "Quick restrict for next hour" only as a shipped feature. Grepping status.md for hourly/quick/inside_interval/overlap/concurrent turns up nothing about the daily↔hourly collision. `qa/invariants.md:51` states the invariant this violates (F4.13, "a determined user cannot end an active block early") but records no known violation of it.

**Verifier's reasoning**

Every cited line says what the three reports claim, and I found no guard anywhere that prevents the collision.

Code truth, line by line:
- `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:68-79` — `intervalDidEnd(for:)` is `if activity.rawValue == "daily" || activity.rawValue == "hourly" { model.clearRestrictions(); model.insideInterval = false }`. No per-activity bookkeeping, no clock check, no `isArmed` check. Exactly as claimed (the anchor line :74 is current, not stale).
- `ScreenTimeShield/Schedule.swift:29` — `let activityName: DeviceActivityName = repeats ? .daily : .hourly`, and `:34` stops monitoring **only** `[activityName]`. So registering `.hourly` provably does not disturb `.daily`.
- `ScreenTimeShield/ContentView.swift:31-33` — `isQuickRestrictDisabled = !access.fcAuthorized || model.insideInterval || isExpired || …applicationTokens.isEmpty`. No `isArmed` term. `PinnedActions.swift` only `.disabled(quickRestrictDisabled)`, so the button is live while armed-but-inactive.
- `ScreenTimeShield/ContentView.swift:100-110` — `restrictForNextHour()` → confirm alert (`:271-284`) → `performRestrictHour()` registers `.hourly` for `now → now+1h` with zero awareness of `.daily`.
- Single shield store, and this needs **no** cross-process API assumption: both callbacks run in the *same* extension process against the *same* object, `Model.shared` (`Extension:60` and `Extension:75`), whose `store` is one `ManagedSettingsStore()` (`Model.swift:18`). `clearRestrictions()` nils applications/applicationCategories/webDomains (`Model.swift:100-104`).
- No re-application path: `grep` shows `setRestrictions()` has exactly one call site in the whole repo — `DeviceActivityMonitorExtension.swift:62`, inside `intervalDidStart`. Nothing in the app re-applies shields.

Mitigations I actively looked for and did **not** find:
- No `isArmed`/`windowContains` guard in the extension (the pure helper `ScheduleMath.windowContains` exists in UnplugCore and is used at `ContentView.swift:126-128`, but never in the monitor).
- `enforcementAllowed` guard exists only on `intervalDidStart` (`Extension:56`), not on the clear path — it can only make things worse, never better.
- `stop()` (`ContentView.swift:82-86`) stops `[.daily, .notificationSchedule]` — it never even knows about `.hourly`.
- `onAppear` (`:245-255`) reconciles only `isArmed` from `DeviceActivityCenter().activities`; it never reconciles `insideInterval` or re-applies shields.
- The only real recovery is manual and undiscoverable: the user re-taps Start, and `applySchedule()` re-registers `.daily` while `now` is inside the window, which per Apple's `startMonitoring` docs may fire `intervalDidStart` immediately. Nothing tells the user their block died, so this does not blunt the bypass.

Downstream UI claims also verified: `StatusBanner.swift:26-33` keys the dot and "Block active/inactive" purely off `model.insideInterval`; `ScheduleCard.swift:21` and the "Schedule locked…" caption key off it; `ContentView.swift:38-48` renders an enabled "Stop blocking" once `insideInterval == false` and `isArmed == true`. So post-wipe the user gets an unenforced block that also presents itself as inactive and stoppable.

**Correction to the original claim**

Two refinements, neither of which weakens the finding:

1. **Precise reachability window.** The reports say "shortly before" the scheduled start. The collision requires the hourly interval's *end* to land strictly inside the daily blocked interval, and the hourly interval is exactly 60 minutes from the tap (`ContentView.swift:107-109`). So the exploitable/accident window is precisely **the 60 minutes immediately preceding the daily block's start**. Tap at T; if `windowContains(T+60, dailyStart, dailyEnd)` the daily block dies at T+60. Tapping earlier than 60 min before the start is harmless (the wipe lands before `intervalDidStart(.daily)` re-applies). With the default 09:00 start, 08:00–09:00 is the accidental window; for a hostile user it is a deliberate, repeatable one-tap recipe every day.

2. **The UI half is delayed, not immediate.** `insideInterval` is `@AppStorage` on a shared suite (`Model.swift:25`) written by another process, so the app in the foreground will not necessarily flip to "Block inactive" at the moment of the wipe — it reads false on the next launch/`onAppear`. The *enforcement* half (shields gone) is immediate and is the part that matters; the "Stop blocking" CTA becoming enabled is a next-launch consequence, not a same-second one.

Also worth noting as a distinct, adjacent hole surfaced while verifying: `stop()` never stops `.hourly` (`ContentView.swift:84` passes only `[.daily, .notificationSchedule]`), so a pending `.hourly` end can also wipe shields after a subsequent re-arm. Same root cause — no per-activity ownership of the shield store.

**Failure trace (re-derived from source by the verifier)**

Preconditions: apps selected, Screen Time approved, access not expired, mode "Block these hours", window 22:00–07:00, user tapped Start earlier → `is_armed = true`, `.daily` registered for 22:00→07:00 (`ContentView.swift:76-80` → `Schedule.swift:25-41`), `inside_interval = false`, shield store empty.

1. 21:30. `isQuickRestrictDisabled` evaluates false (`fcAuthorized`, `insideInterval == false`, not expired, tokens non-empty — `ContentView.swift:31-33`), so "Restrict for next hour" is tappable. User taps → `restrictForNextHour()` → `armRequest = .hour` → alert "This blocks everything for the next hour and can't be stopped until then." → user confirms → `performRestrictHour()` → `Schedule.setSchedule(start: 21:30, end: 22:30, repeats: false)` → `stopMonitoring([.hourly])`; `startMonitoring(.hourly, during: {21:30→22:30, repeats:false})`. `.daily` untouched (`Schedule.swift:29,34`).
2. 21:30 (immediately — Apple: "may begin receiving callbacks as soon as the system calls this method if the activity's scheduled interval is ongoing"). `intervalDidStart(.hourly)` → `enforcementAllowed` true → `Model.shared.loadSelection(); setRestrictions(); insideInterval = true`. Shields applied on `Model.shared.store`.
3. 22:00, device in use. `intervalDidStart(.daily)` → same three calls. Shields re-applied (same token set), `inside_interval` already true. Idempotent.
4. 22:30 (or the user's next pickup after 22:30 — Apple: "the system only invokes this method when the device is in use"). `intervalDidEnd(for: .hourly)` → `Extension:74` matches on `"hourly"` → `Model.shared.clearRestrictions()` sets `store.shield.applications/applicationCategories/webDomains = nil` (`Model.swift:100-104`) → `model.insideInterval = false` written to `group.screentimeshield`.
5. Persisted state: `is_armed = true`, `inside_interval = false`, `.daily` still registered with the system (repeating; its own `intervalDidEnd` is not due until 07:00), ManagedSettingsStore **empty**.
6. 22:31 → 07:00. Every "blocked" app opens normally. `setRestrictions()` has no other caller, and `intervalDidStart(.daily)` will not be redelivered for this occurrence (Apple: "An activity starts when someone **first** uses the device within the activity's scheduled time interval"), so nothing restores the shields until 22:00 the following night.
7. Next time the user opens Unplug: `onAppear` sets `isArmed = activities.contains(.daily)` = true and leaves `inside_interval` false → StatusBanner shows the grey dot and "Block inactive" (`StatusBanner.swift:26-33`), the CTA renders an **enabled** "Stop blocking" (`ContentView.swift:39,46`; `primaryDisabled` returns false for armed+inactive), and the schedule card/slider unlock (`ScheduleCard.swift:21`). So the user can also disarm outright — and gets no signal that their block stopped enforcing 90 minutes into a 9-hour window.

**Apple API semantics checked**

Fetched Apple's doc JSON directly (the HTML pages are JS-rendered and WebFetch returns nothing useful).

1. `DeviceActivityMonitor.intervalDidEnd(for:)` — "An activity ends when someone first uses the device outside **the activity's** scheduled time interval or when your app stops monitoring an activity with an ongoing interval. In other words, the system only invokes this method when the device is in use." → Confirms the callback is per-activity and is delivered for the hourly activity's own end, at the latest on the user's next device use (which in this trace is still inside the daily window). The "device in use" caveat only delays the wipe; it cannot prevent it.

2. `DeviceActivityMonitor.intervalDidStart(for:)` — "An activity starts when someone **first** uses the device within the activity's scheduled time interval." → Confirms the strongest possible refutation does NOT hold: `intervalDidStart(.daily)` is not redelivered on each subsequent device use inside 22:00–07:00, so there is no framework-level self-heal after the wipe.

3. `DeviceActivityCenter.startMonitoring(_:during:events:)` — "If the app **already monitored the activity**, this method overwrites the previous schedule and events." (per-name, so starting `.hourly` cannot displace `.daily`); "Attempting to monitor too many activities or activities that are too tightly scheduled can cause this method to throw an error" (the documented failure is about *many*/tight activities; 2–3 named activities is normal, and the app already co-registers `.daily` + `.notificationSchedule`); "The application extension's monitor may begin receiving callbacks as soon as the system calls this method if the activity's scheduled interval is ongoing" (confirms step 2 of the trace, and confirms the manual re-arm recovery).

Not needed: any assumption about the unnamed `ManagedSettingsStore` being shared across processes, or about cross-process `@AppStorage`/`didChangeNotification`. The apply and the clear both execute in the same monitor-extension process against the same `Model.shared.store`, so the shield collision is a same-process fact. The `@AppStorage` staleness only affects how fast the UI reflects it (see correctedMechanism).

Residual, non-refuting risk: Apple Developer Forums reports that `intervalDidEnd` sometimes does not fire for non-repeating schedules. If it never fires, this trace is replaced by the mirror-image defect (`inside_interval` stuck true, the F4.3 lock-out). Either way the daily/hourly collision is unhandled.

**Second opinion (agrees)**

_Worst realistic outcome:_ An armed daily block silently stops enforcing part-way through its window — e.g. a 22:00–07:00 block dies at 22:30 — and stays unenforced until the next day's window start unless the user happens to cold-launch Unplug during the window. Meanwhile the app reports "Block inactive" with an enabled "Stop blocking" and an unlocked schedule slider, so the user is neither protected nor told, and can disarm outright.

I re-derived the whole trace independently and agree: CONFIRMED, class = bypass, severity = important. All anchors are current, not stale. But the first verifier over-claimed the recovery story and under-stated one Apple semantic.

WHAT THEY GOT WRONG — the self-heal is automatic on cold launch, not "manual and undiscoverable"

They wrote: "The only real recovery is manual and undiscoverable: the user re-taps Start... nothing restores the shields until 22:00 the following night." That is wrong as stated. A plain cold launch of Unplug restores enforcement with zero taps:

`ScreenTimeShield/ContentView.swift:245-246` — `.onAppear { model.loadSelection() }`. On a cold launch the singleton's `selectionToRestrict` starts as an empty `FamilyActivitySelection()` (`ScreenTimeShield/Model.swift:40`) and `loadSelection()` (`Model.swift:59-64`) assigns the saved non-empty one, so the value genuinely changes → `.onChange(of: model.selectionToRestrict)` at `ContentView.swift:218-229` fires. Post-wipe `insideInterval == false`, so the `validateRestriction()` early-return at `:221` is skipped and it falls through to `applySchedule()` at `:228`. `applySchedule()`'s guard (`:60`) is `isArmed && !isExpired && !isEmpty()` — all true (`is_armed` is still true, which is the bug's own premise) → `Schedule.setSchedule(..., repeats: true)` → `stopMonitoring([.daily])` + `startMonitoring(.daily, during: 22:00→07:00)` (`Schedule.swift:32-40`).

I confirmed the Apple semantic that makes this land, from the docs JSON for `DeviceActivityCenter.startMonitoring(_:during:events:)`: "The application extension's [monitor] may begin receiving callbacks as soon as the system calls this method if the activity's scheduled interval is ongoing." So re-registering `.daily` at 23:00 re-fires `intervalDidStart(.daily)` → `setRestrictions()` → shields back. Note this is the *same* sentence the bug's own step 2 depends on for the hourly block to start at all, so you cannot accept the mechanism and reject this mitigation.

How much this blunts it: not much, but it must be stated correctly. (a) It does not help the hostile user — they simply do not open Unplug. (b) It requires a *cold* launch: a warm resume does not re-run root-view `onAppear`, and the only scenePhase hook (`ScreenTimeShieldApp.swift:95-104`) just calls `refreshAccess()`. (c) A user in a 09:00–17:00 or 22:00–07:00 block has little reason to open Unplug. So the exposure is still hours, but "nothing restores the shields until the following night" should be "nothing restores them unless the app is cold-launched during the window."

SEMANTIC THEY MISSED — `stopMonitoring` itself delivers `intervalDidEnd`

The docs for `DeviceActivityMonitor.intervalDidEnd(for:)` read: "An activity ends when someone first uses the device outside the activity's scheduled time interval **or when your app stops monitoring an activity with an ongoing interval**." They only quoted the first clause. Consequence: the self-heal above is a clear-then-reapply race — `stopMonitoring([.daily])` on an ongoing interval delivers `intervalDidEnd(.daily)` → `clearRestrictions()` + `inside_interval = false`, immediately before the start callback re-applies. Serial queue (`Schedule.swift:23`) guarantees stop-before-start on the app side, so it should settle shields-on, but the recovery is not airtight. (This is F4-STATE-02's territory; I note it only because they leaned on the recovery path.)

WHAT MAKES THE CLAIM STRONGER THAN THEY ARGUED

Their step 3 (`intervalDidStart(.daily)` at 22:00) is not load-bearing. If the daily start never fires (device idle), the hourly has already applied the identical shields and set `inside_interval = true`, and `intervalDidEnd(.hourly)` at 22:30 wipes them just the same. The bug survives either delivery order.

Also, in the hostile case the trigger is self-guaranteeing: to enjoy the unblocked apps at 22:30 the user must use the device, which is precisely the condition Apple requires for `intervalDidEnd` delivery ("the system only invokes this method when the device is in use").

MITIGATIONS I SEARCHED FOR AND CONFIRMED ABSENT
- One unnamed `ManagedSettingsStore()` app-wide: `ScreenTimeShield/Model.swift:18` and `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:24`; `grep -rn ManagedSettingsStore` returns only those two plus three commented-out lines in `CustomShieldAction/ShieldActionExtension.swift:19,34,49`. No `ManagedSettingsStore(named:)` anywhere, so there is no per-activity isolation.
- `setRestrictions()` has exactly one caller repo-wide, `DeviceActivityMonitorExtension.swift:62`. Nothing else ever re-applies.
- `Model.swift` is in two Sources phases (`project.pbxproj:590` app, `:652` monitor extension), so `Model.shared` in the extension is a real second instance writing the shared group — no cross-process assumption needed for the wipe itself; both callbacks run in the same extension process against the same object.
- No `isArmed` term in `isQuickRestrictDisabled` (`ContentView.swift:31-33`) and no window/clock check anywhere in the monitor. `ScheduleMath.windowContains` is used only at `ContentView.swift:126-128`.
- The `.hour` confirm copy (`ContentView.swift:138`) says nothing about the collision, and `isRiskyToArm()` is not consulted for `.hour` at all (`:100-103`).
- `stop()` (`:82-86`) stops `[.daily, .notificationSchedule]` and never `.hourly`.
- `enforcementAllowed` gates only `intervalDidStart` (`Extension:56`), never the clear path.
- Only 3 activities are ever registered, so `.excessiveActivities` cannot block the hourly registration.

NOT KNOWN IN status.md. I read the whole file: the Bugs section covers Family Controls authorization, the "selection was reset" toast, and the arm-confirm UI stall. "Quick 'restrict for next hour' action" is listed under Done with no caveat. This mechanism is news. It maps to `qa/invariants.md:51` (F4.13).

RESIDUAL RUNTIME RISK (does not change my verdict): Apple Developer Forums 820956 reports `intervalDidEnd` occasionally not firing for non-repeating schedules. If it never fires, this exact bypass is replaced by the inverse defect (`inside_interval` stuck true). Device test settles it: arm a daily window, quick-restrict 30 min before it starts, then check enforcement 5 min after the hour elapses.

FRAMING CORRECTION ON FREQUENCY: they presented this as firing "for an ordinary user on an ordinary evening." It is narrower than that — the reachable trigger window is the ~60 minutes preceding the armed window's start. That is a genuinely plausible ordinary-user moment ("my block starts at 22:00, it's 21:20 and I want to stop scrolling now"), so it is not adversarial-only, but "occasional" is the honest label rather than "common". The bypass reading, by contrast, is deterministic and repeatable nightly.

**Proof path**

Not provable today. The buggy decision is inline in `DeviceActivityMonitorExtension.intervalDidEnd(for:)` (extension target, `DeviceActivityMonitor` subclass, touching `ManagedSettingsStore` and app-group `UserDefaults`) — nothing in `UnplugCore` encodes it and `SKTestSession` is irrelevant here (this is DeviceActivity, not StoreKit).

Extraction needed: a pure decision function in `UnplugCore`, e.g.
`EnforcementPolicy.shouldClearShields(endingActivity: ActivityKind, isArmed: Bool, dailyStartMinute: Int, dailyEndMinute: Int, nowMinute: Int) -> Bool`
returning false when `endingActivity == .hourly && isArmed && ScheduleMath.windowContains(now:start:end:)` — plus a mirror case for `.daily` ending while an `.hourly` interval is still running (needs the hourly end persisted to the app group, which today it is not). `intervalDidEnd` then becomes a two-line call into it.

Tests that would then prove it, all pure:
- `shouldClearShields(.hourly, isArmed: true, daily 22:00→07:00, now 22:30) == false` (the exact bug).
- `shouldClearShields(.hourly, isArmed: true, daily 09:00→17:00, now 09:30) == false` (default-schedule accidental case).
- `shouldClearShields(.hourly, isArmed: true, daily 22:00→07:00, now 21:30) == true` (tap >60 min before start must still clear).
- `shouldClearShields(.hourly, isArmed: false, …) == true` (quick block alone still ends).
- `shouldClearShields(.daily, isArmed: true, …, hourlyEndsAt: later) == false` (mirror case).

`ScheduleMath.windowContains` already handles the wrapping 22:00→07:00 case (`UnplugCore/Sources/UnplugCore/ScheduleMath.swift:16-24`) and is covered by `ScheduleMathTests.swift`, so the wrap arithmetic the fix depends on is already trustworthy. On-device confirmation is still wanted for the callback sequence itself (register `.hourly` ending inside an armed `.daily`, watch the extension log for `intervalDidStart daily` then `intervalDidEnd hourly`, then check a restricted app opens).

---

### `V14` · Disarm lock trusts a cross-process flag instead of the clock, so Stop blocking stays live during a block

- **🔴 Important** · impact **bypass** · needs device · hit **Split by leg. Wrong status display + inert CTA: common — it happens on any block that begins while the app is foregrounded, most notably the first-run habit of setting the window to start in a minute or two and watching. The stop-in-the-gap tap that actually deregisters .daily: adversarial-only, and even for the adversary it grants nothing they couldn't get one second earlier. The permanent-lockout tail: rare / adversarial-only (needs a tap inside the extension-launch race).**
- **Feature** F4 · **Discovery IDs** F4-HOSTILE-03
- **Already in status.md:** Not recorded. `status.md` (50 lines) has no entry for this mechanism: the Bugs section lists only Family Controls authorization (done), the notifications bug, and the undocumented README bug. `status.md:16` describes the explicit arm/disarm model as shipped and correct, and specifically claims the fixed bug was the inverse direction ("toggling Block/Allow … started a block — edits now disarm while inactive") — it does not contemplate a stop landing after the start instant. The relevant invariants exist only as *assertions* in `qa/invariants.md` (F4.3 "No reachable path leaves insideInterval == true while nothing is registered to eventually clear it", F4.13 "A determined user cannot end an active block early"), i.e. as things believed true, not as known-open bugs. So this is news.

**Verifier's reasoning**

Every cited line says what the claim says it says, and I found no guard anywhere that prevents the mechanism.

Code truth, verified line by line:
- `ScreenTimeShield/ContentView.swift:43-48` (`primaryDisabled`) and `:50-53` (`onPrimary`) gate the lock exclusively on `model.insideInterval`. `:82-86` (`stop()`) does `model.isArmed = false`, `Schedule.stopMonitoring([.daily, .notificationSchedule])`, `model.clearRestrictions()` — and never writes `insideInterval = false`. Anchor line 43 is exactly `private var primaryDisabled: Bool {`.
- `ScreenTimeShield/Model.swift:25` — `@AppStorage("inside_interval", store: UserDefaults(suiteName:)) var insideInterval: Bool = false` on a plain `ObservableObject` (class `Model: ObservableObject`, Model.swift:16). Not `@Published`, no `objectWillChange`. `Model.swift:40,41,48` show the author does use `@Published` elsewhere, so this is a genuine asymmetry, not a misread.
- I grepped every writer of the flag: `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:63` (true, in `intervalDidStart`), `:77` (false, in `intervalDidEnd`), and `ScreenTimeShield/AccessController.swift:199` inside `qaResetToFreshInstall()` — which `status.md:29` records as unreachable in production (the SettingsView Section is commented out). So in production the flag is written *only* by the out-of-process extension. Confirmed.
- No clock-derived activeness check exists anywhere in the lock path. `ScheduleMath.windowContains` (`UnplugCore/Sources/UnplugCore/ScheduleMath.swift:16-24`) correctly handles wrapping windows and is used only at `ContentView.swift:126-128` and `:141-143` (risk confirm). The claim that the app already has and uses the right helper two functions later is accurate.
- Shields are applied only by the extension: `grep setRestrictions` returns exactly one caller, `DeviceActivityMonitorExtension.swift:62`. So between the scheduled start and the extension's launch, nothing is shielded and the flag is false.

Mitigations I actively searched for and did not find:
- `.onAppear` (`ContentView.swift:245-255`) re-derives only `isArmed` from `DeviceActivityCenter().activities`. It never reconciles `insideInterval` against the clock.
- No timer, no `DeviceActivityCenter` interval inspection, no `scenePhase` handler touches the flag. `ScreenTimeShieldApp.swift:99-104` only calls `AccessController.refreshAccess()`.
- Foregrounding *does* force a re-render (`refreshAccess()` assigns the `@Published fcAuthorized`/`accessState`, AccessController.swift:91-99+117), so the stale-CTA half of the claim is limited to a continuously-foregrounded app — which is exactly the trace the candidate specifies. Not a refutation.
- `StatusBanner.swift:30`'s `.onChange(of: model.insideInterval)` cannot rescue anything: with nothing publishing, body is not re-evaluated, so the comparison never runs.
- `PinnedActions.swift:37` `.disabled(primaryDisabled)` faithfully forwards the same flag; no independent guard there.

One correction to the claim's framing, and one leg I would not defend — see correctedMechanism.

**Correction to the original claim**

The mechanism is real but the claim over-weights the tap-race and under-weights the missed-callback case; also its own failure trace picks a window where the in-app promise copy never appears.

1. Sharpen the harm. In the sub-second case Outcome A adds almost nothing, because tapping Stop at 21:59:59 is a *legitimate, by-design* disarm — the user could have escaped one second earlier legally. The real bite is that `.daily` is registered `repeats: true` (`Schedule.swift:25-29`), so the tap does not merely skip tonight: `stopMonitoring([.daily])` deregisters the repeating schedule permanently. Every subsequent night is unprotected until the user re-taps Start. The harm therefore scales with the latency window, and the escalation over a legal 21:59 disarm is "the block that would have engaged when the extension launched never engages, ever."

2. The stronger, non-racy case the claim buries in "API semantics relied on": because the lock has no clock fallback, a *missed* `intervalDidStart` — not merely a delayed one — leaves the app believing no block is active for the entire night, with Stop live the whole time. Apple's forums document this failure mode repeatedly (threads 819224, 736682, 733562, 745035, 721945; one titled "intervalDidStart never called on iOS 26.3.1"). This needs no race and no boundary timing: the user just opens the app during the promised window and taps an enabled "Stop blocking". That is the case I would lead with, and it is squarely a code-truth defect since `windowContains` is already in the binary.

3. Outcome B (stranded `insideInterval == true` → permanent F4.3 lockout) I would not defend as stated. The code fact is true — `stop()` at ContentView.swift:82-86 genuinely never clears the flag — but the consequence needs the extension's write to land *after* `stop()`, and my search surfaced (secondary, non-Apple) sources claiming `intervalDidEnd` fires when `stopMonitoring()` is called, which would self-heal it. Apple's own doc pages for `intervalDidStart(for:)`/`intervalDidEnd(for:)` are JS-rendered and I could not extract their Discussion text, so I could not settle this either way. Report leg 3 as a latent invariant violation (F4.3: `stop()` should defensively write `insideInterval = false`), not as a demonstrated lockout.

4. Minor factual fix to the candidate's trace: for a 22:00–07:00 Block-mode window, `isRiskyToArm()` returns false — `freeMinutes(windowStart: 1320, windowEnd: 420, blockOutsideWindow: false)` = `1440 - max(0, 420-1320)` = 1440 (the wrapping bug the candidate itself notes as F3.11) — so no confirm alert is shown and the user never sees "can't be stopped until 07:00". The broken promise in this trace comes from README/product framing and the locked "Blocking" CTA, not from in-app copy. The candidate's "the UI actively invites the tap" stands; "the app told them it couldn't be stopped" does not, for this window.

Suggested fix shape: derive the lock as `insideInterval || ScheduleMath.windowContains(now:start:end:)` when `isArmed`, and have `stop()` write `insideInterval = false`.

**Failure trace (re-derived from source by the verifier)**

Preconditions: Family Controls approved, access not expired, apps selected, Block mode, window 22:00→07:00, user tapped Start earlier in the day (`performArm()`, ContentView.swift:76-80 → `isArmed = true`, `Schedule.setSchedule(start: 22:00, end: 07:00, repeats: true)`), so `.daily` is registered and `inside_interval == false`.

1. 21:55 — user opens Unplug and leaves it foregrounded. Body evaluates: `access.fcAuthorized == true`, `model.insideInterval == false`, `model.isArmed == true` → `primaryTitle` = "Stop blocking" (:39), `primaryDisabled` = false (:46), `primaryLocked` = false (:200). StatusBanner shows "Block inactive". CTA enabled.

2. 22:00:00 — the DeviceActivity daemon's interval begins. Nothing has happened in the app's process: no shield is applied (`setRestrictions()` has exactly one caller, Extension:62) and `inside_interval` is still false in `group.screentimeshield`.

3. 22:00:00 → T (T = the moment iOS launches CustomDeviceActivityMonitor and it reaches Extension:63; or never, per forum 819224). Throughout this interval the app's model state is unchanged AND the UI is not re-evaluated, because `insideInterval` is `@AppStorage` on a non-`@Published` `ObservableObject` (Model.swift:25) — no `objectWillChange`, so `StatusBanner.swift:30`'s `onChange` never runs and the CTA keeps rendering enabled "Stop blocking".

4. User taps the CTA → `PinnedActions.swift:19` `onPrimary` → `ContentView.swift:50-53`. `model.insideInterval` reads false (the extension has not written yet, so no cross-process freshness question arises), `model.isArmed` is true → `stop()`.

5. `stop()` (:82-86): `model.isArmed = false` → persisted to `is_armed` in the app group; `Schedule.stopMonitoring([.daily, .notificationSchedule])` → enqueued on `Schedule.queue` (Schedule.swift:63-67) → `DeviceActivityCenter().stopMonitoring([.daily, .notificationSchedule])`; `model.clearRestrictions()` → `store.shield.applications/applicationCategories/webDomains = nil` (Model.swift:100-104). `inside_interval` is left at false (nothing writes it here).

6. Persisted state after the tap: `is_armed = false`, `inside_interval = false`, no `.daily` and no `.notificationSchedule` registered, `ManagedSettingsStore` empty, `ScreenTimeSeletion` untouched.

7. What the user sees: `isArmed == false`, `insideInterval == false` → CTA reads "Start blocking", banner reads "Block inactive". Restricted apps open normally for the rest of the night. Because `.daily` was a `repeats: true` registration, the same is true tomorrow night and every night after, until the user voluntarily taps Start again. `onAppear` (:248) re-derives `isArmed = activities.contains(.daily)` = false on the next launch, so nothing self-corrects — the state is internally consistent and silently unprotected.

**Apple API semantics checked**

Three semantics mattered; I could confirm two well enough to keep the verdict and one only partially.

1. `intervalDidStart` timing/reliability — Apple documents no timing guarantee at all (the doc pages are one-line "Tells the app extension…" stubs; I attempted `developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidstart(for:)` and `intervaldidend(for:)` via WebFetch and both are JS-rendered with no extractable Discussion text). What I could confirm is the architectural fact that makes the window unavoidable: the callback runs in a separate app-extension process that the system must launch, so it cannot be simultaneous with the scheduled instant. Magnitude is undocumented. Multiple Apple Developer Forums threads report the callback delayed or never firing: 819224 ("intervalDidStart never called on iOS 26.3.1"), 736682, 733562, 745035, 721945, 774285 (the intervalDidEnd counterpart). That is enough to establish the window is real and can be large or infinite; it is not enough to put a number on it, hence needsDevice.

2. `@AppStorage` in a non-View class — confirmed by construction rather than by doc: `AppStorage` is a `DynamicProperty` whose `update()`/subscription machinery is driven by SwiftUI's view graph. `Model` is a plain `ObservableObject` (Model.swift:16) with no `objectWillChange.send()` on that property, so a write (from this process or another) publishes nothing to `ContentView`/`StatusBanner`. The getter does read through to the shared suite, so the *guard* is value-correct whenever it runs; only the *rendering* is stale. Note this makes the claim's aggravating-factor-1 correct but non-load-bearing: the primary hole is that the extension has not yet written `true` at all, which needs no staleness argument. I deliberately did not rest the verdict on cross-process `UserDefaults` cache freshness, which I could not confirm.

3. Does `stopMonitoring()` deliver `intervalDidEnd`? NOT confirmed. Search surfaced a secondary source (letvar's "Time After (Screen) Time, part 3") asserting `intervalDidEnd` "can be triggered … when you stop the monitor with stopMonitoring()", and forum thread 774285 reporting the opposite (never called). Apple's page is unreadable as above. This is the sole reason I downgraded the candidate's Outcome B from a demonstrated lockout to a latent invariant violation — it does not affect the confirmed Outcome A path, which never depends on this.

**Second opinion (**DISAGREES** with the first verifier)**

_Worst realistic outcome:_ The user's chosen apps stay shielded indefinitely with no in-app way out. If the Stop tap lands inside the extension-launch race, `stop()` clears shields and deregisters `.daily` (ContentView.swift:84-85), then `intervalDidStart` re-applies shields and writes `inside_interval = true` (Extension:62-63). Nothing is monitored any more, so `intervalDidEnd` never runs, and the flag is never reconciled (onAppear only syncs `isArmed`, ContentView.swift:248). The CTA renders locked "Blocking" and `onPrimary` early-returns (ContentView.swift:45, :51), the quick action is disabled (:32), and the QA reset that writes `insideInterval = false` (AccessController.swift:199) is unreachable in production (SettingsView.swift:25-29 commented out). Recovery requires deleting the app.

The code is exactly as both the claim and the first verifier describe — I independently re-checked ContentView.swift:43-53 and :82-86, Model.swift:25 (`@AppStorage` on a plain `ObservableObject`, no `@Published`), the only three writers of `inside_interval` (Extension:63, :77, AccessController.swift:199), the single `setRestrictions()` caller (Extension:62), and the absence of any clock reconciliation (no Timer/TimelineView/onReceive anywhere in ScreenTimeShield/; scenePhase only calls `refreshAccess()`, ScreenTimeShieldApp.swift:95-104). The defect is real and worth fixing. But the first verifier accepted "bypass" and I think that is wrong, for three reasons they did not weigh.

1. There is no bypass delta over the sanctioned behaviour. Stopping an armed-but-inactive block is by design (ContentView.swift:46 `if model.isArmed { return false }`). A user who wants out of tonight's 22:00 block just taps "Stop blocking" at 21:59 — same result, same persisted state (`.daily` gone, no block tonight or any night), zero timing skill. The bug extends that permission by exactly the extension-launch latency, and that is precisely the interval during which `setRestrictions()` (Extension:62) has not run and nothing is shielded. Lines 62 and 63 are adjacent: the lock closes at the same instant enforcement begins. So nothing that was enforced ever becomes unenforced through this path. The product promise ("cannot be bypassed once active") is broken only in the letter — for a definition of "active" the app never enforces anyway.

2. The stale-render leg — the half the claim leans on hardest — cannot produce a bypass, and the verifier's trace quietly concedes this without saying so. `onPrimary` re-reads `model.insideInterval` at tap time and `@AppStorage`'s getter reads through to the shared suite (Model.swift:25), while the extension calls `defaults?.synchronize()` on write (Extension:36). So in the scenario where the extension has already fired but the button is still rendering enabled "Stop blocking", the tap hits `if model.insideInterval { return }` (ContentView.swift:51) and does nothing. What the user actually gets there is a wrong banner ("Block inactive" while blocked, StatusBanner.swift:33), a wrong card label ("Will be restricted", AppCard.swift:27), an unlocked-looking button missing its lock glyph (PinnedActions.swift:22), and a dead tap — a status-integrity bug, not an escape. The only thing that would upgrade this leg to a genuine bypass is the app process's CFPreferences cache serving a stale `false` at tap time despite the extension's `synchronize()`. Neither of us established that, and it is the single measurement that would settle the classification: on device, block active and shields verifiably applied, app foregrounded continuously across the boundary, tap the stale "Stop blocking" and check whether shields drop.

3. The "never fires" tail the claim cites for window length ([forums 819224](https://developer.apple.com/forums/thread/819224), [736682](https://developer.apple.com/forums/thread/736682)) argues against it, not for it: if `intervalDidStart` never arrives, there was never a block to bypass — that is an enforcement-delivery failure belonging to a different finding. And I could find no Apple documentation or report establishing a latency figure, so "the lock is only as prompt as the extension launch" is directionally right but unquantified; the exploitable window is plausibly sub-second on a healthy device.

Two things both the claim and the verifier missed. (a) The claim's own headline ("the stop path leaves `inside_interval` stuck true") only holds in Outcome B; in Outcome A the flag stays false, which is correct-by-accident — the verifier repeated the headline without flagging the overstatement. (b) `Schedule.setSchedule` (Schedule.swift:26-28) never passes a `warningTime`, so `intervalWillStartWarning` (Extension:137) can never fire and cannot pre-warm the flag — the one mitigation the framework offers here is unused, which is the real reason the gap exists and a cheaper fix hint than the verifier's framing suggests.

Not in status.md: the Bugs section (status.md:5-11) lists only the notifications bug and an undocumented README bug, so this is news.

Bottom line: reclassify from "bypass" to state-reconciliation / status-display, with a rare permanent-lockout tail. Keep it important on the strength of the wrong-status display (common) and the lockout (severe if rare); on bypass grounds alone it would be a nit. Fix is cheap and the codebase already has the pieces: OR the clock into the lock (`ScheduleMath.windowContains`, already used at ContentView.swift:126-128), and have `stop()` write `model.insideInterval = false` so Outcome B cannot strand.

Sources: [819224](https://developer.apple.com/forums/thread/819224), [736682](https://developer.apple.com/forums/thread/736682), [774285](https://developer.apple.com/forums/thread/774285)

**Proof path**

Not provable today. The whole decision — "is this block locked?" — lives inside the SwiftUI view as `ContentView.primaryDisabled` (ContentView.swift:43-48) and `ContentView.onPrimary` (:50-53), private computed members of a `View` struct, so no test can reach them without launching the app. `SKTestSession` is irrelevant (no StoreKit involved), and `UnplugCore` currently owns only `ScheduleMath`/`AccessControl`, neither of which knows about `insideInterval`.

Extraction needed (small, and it makes the fix and the test the same change): add a pure decision function to `UnplugCore`, e.g.

  BlockLock.canStop(nowMinutes: Int, startMinutes: Int, endMinutes: Int, isArmed: Bool, insideInterval: Bool) -> Bool

returning `isArmed && !insideInterval && !ScheduleMath.windowContains(now:start:end:)`, and have `primaryDisabled`/`primaryTitle`/`onPrimary` call it instead of reading the flag directly.

Then the confirmed bug is provable by a pure test in `UnplugCore/Tests/UnplugCoreTests/` with zero device dependency:
- `canStop(nowMinutes: 1320 /*22:00*/, startMinutes: 1320, endMinutes: 420 /*07:00*/, isArmed: true, insideInterval: false)` must be `false` — this is the assertion that fails against today's flag-only logic, and it covers both the launch-latency window and the never-fired-callback case in one shot.
- `canStop(nowMinutes: 1319 /*21:59*/, …, insideInterval: false)` must be `true` — pins the legitimate pre-start disarm so the fix doesn't over-lock.
- Wrapping coverage at `nowMinutes: 0` and `419` (inside the post-midnight leg) must be `false`.
- A regression test that `insideInterval: true` forces `false` regardless of clock, so the flag remains an additional lock and not a replacement.

Separately, the leg-3 invariant (F4.3) is testable only after `stop()`'s state mutation is also extracted (e.g. a `StopOutcome` value describing which activities to deregister plus `insideInterval = false`); asserting `stop()` clears the flag is otherwise unreachable from a test.

The device measurement that remains is only the *magnitude* of the exploit window: arm a 22:00 block, sit in the foreground across the boundary with console logging on `intervalDidStart`, and measure the delay between 22:00:00 and Extension:63 (and how often it never arrives).

---

### `V01` · End handle at 24:00 -> Calendar returns nil -> `?? Date()` substitutes 'now' for the user's chosen end time

- **🔴 Important** · impact **lockout** · reasoned from source · hit **Two-tier. The core defect (end time silently replaced by the current clock) is **always** for the gesture the UI advertises — anyone who drags the end handle to the right end of the track hits it deterministically, not occasionally. The **~24h unstoppable block** on top of that is **occasional**: it additionally needs block-these-hours mode, `now < start`, and the user tapping Start despite a visibly collapsed window. Not adversarial in either tier — no hostile intent required.**
- **Feature** F3 · **Discovery IDs** F3-TIME-01, F3-MAP-01 (2 agents found this independently)
- **Already in status.md:** No matching entry. status.md's Bugs section (lines 5-11) lists Family Controls authorization (done), the "selection was reset" toast (done), the arm-confirm UI stall (done), "Notifications bug — needs investigation", and "Outstanding bug mentioned in README". None describe the slider's minute→Date mapping. Greps of status.md for `24:00`, `1440`, `midnight`, `bySettingHour`, `dateAtMinute` return only the two `ScheduleRangeSlider` feature entries (line 16, line 20) that record building the slider, with no mention of this defect. The nearest adjacent known item is the already-recorded "`Schedule` still swallows `startMonitoring` errors (`catch { print }`)" note on line 8, which is a different mechanism. This is news.

**Verifier's reasoning**

Every cited line says what the claim says it says, and I found no guard anywhere on the path.

1. Minute 1440 is representable in the pixel→minute domain. `ScheduleRangeSlider.swift:24` `totalMinutes = 24*60`; `ScheduleRangeSlider.swift:51` clamps with `min(totalMinutes, snapped)`, so 1440 is a legal output, not an overshoot artefact.

2. Minute 1440 is *not* representable by `dateAtMinute`. `ScheduleRangeSlider.swift:40-41`: `let m = max(0, min(totalMinutes, minute))` — the clamp ceiling is 1440, not 1439 — then `Calendar.current.date(bySettingHour: m / 60, ...) ?? Date()`. For m = 1440 that is `bySettingHour: 24`.

3. I ran the exact call under Foundation (Swift 6.2, macOS 26) in four zones: `date(bySettingHour: 24, minute: 0, second: 0, of: Date())` returned **nil** in Europe/Dublin, America/New_York, Asia/Tokyo and UTC, while `bySettingHour: 23, minute: 55` returned the correct instant. So the `?? Date()` fallback on `ScheduleRangeSlider.swift:41` fires and substitutes the current instant.

4. 1440 is reachable by an ordinary drag, and the UI advertises it. I re-ran the file's own `x(for:)`/`minute(forX:)` at an iPhone-16 slider width of 329pt: `x(for: 1440)` = 305.0 = `width - labelInset` (exactly the right end of the track, since the track is `.padding(.horizontal, labelInset)`, `:69`), and `minute(forX:)` returns 1440 for **every** finger x ≥ 305 (I checked 305, 310, 329, 340 — DragGesture locations are not clamped to the view). The hour axis prints a literal `"24:00"` at that same x (`ScheduleRangeSlider.swift:158-160`), so the affordance invites exactly this drag. The end handle rendered at 23:55 is centred at x = 304.0 spanning 290–318, so 1440 is inside the handle's own footprint — barely a nudge away.

5. Only the end handle can reach it, via `ScheduleRangeSlider.swift:136` `end = dateAtMinute(max(m, minutes(of: start) + minGap))` — `max(1440, …)` = 1440. (The start handle is bounded by `minutes(of: end) - minGap` ≤ 1420, `:134`.) The gesture is live whenever `locked == false`, i.e. `!model.insideInterval` (`:129`, `ScheduleCard.swift:26`).

6. The wrong value is persisted, not just displayed: `Model.swift:50-52` `end.didSet` writes it into the `group.screentimeshield` app group.

7. The risk confirmation does not catch it. `ContentView.swift:129-131` feeds `model.start`/`model.end` (not `blockedInterval`) to `ScheduleMath.freeMinutes`, whose `max(0, windowEnd - windowStart)` (`UnplugCore/Sources/UnplugCore/ScheduleMath.swift:30`) clamps the *negative* length to 0 → 1440 "free" minutes. And `windowContains(now:start:end:)` (`ScheduleMath.swift:16-24`) cannot be true at that moment, because `end` was just set to *now* and the wrapping branch is `now >= start || now < end` — `now < now` is false. I ran both: `activeNow = false`, `free = 1440`, `risky = false`. So `start()` goes straight to `performArm()` (`ContentView.swift:73`).

8. Nothing normalises the value afterwards. Grep for `dateAtMinute`/`bySettingHour`/`totalMinutes` across all Swift shows the only other writers of `start`/`end` are the two hardcoded defaults (hours 9/17, always valid) and `AccessController.swift:195-196`. There is no `.onEnded` fixup on the gesture, no ordering assert in `Model.blockedInterval` (`Model.swift:36-38`), and `Schedule.components(from:)` (`Schedule.swift:69-71`) passes hour/minute straight through.

Mitigations I looked for and did not find: an end-of-drag normalisation; a 1439 ceiling in `dateAtMinute`; a start<end validation before arming; a disabled control (the mode Picker and the slider are only locked once `insideInterval`, which is *after* the bad schedule is registered); `primaryDisabled` (`ContentView.swift:43-48`) checks auth/apps/expiry only. `disarmIfArmedInactive()` (`:90-92`, wired at `:234`) does fire on the drag, but it only disarms — the corrupted `end` survives and the very next Start tap arms it.

**Correction to the original claim**

Mechanism is as claimed. Three small corrections to the write-ups, none of which change the verdict:

(a) F3-MAP-01's "any finger position at or past that x clamps to 1440" is right, but the reachability is stronger than either agent stated: 1440 is returned for every x ≥ 305 on a 329pt slider, and the end handle sitting at 23:55 is centred at 304.0 with a 28pt footprint (290–318) — so the last ~13pt of the handle's own hit area already maps to 1440. This is not an edge-of-screen stunt; a user dragging "to the end" hits it essentially every time.

(b) The confirmation bypass is mode-specific. It only happens in "Block these hours" (`blockOutsideWindow == false`), where `freeMinutes` returns 1440. In allow-only mode the same reversed window gives `freeMinutes` = 0 → `free <= 30` → the confirm *is* shown. So the dangerous arm-without-warning path requires block mode — which is also the mode where `blockedInterval` = (start, end) is handed to the system reversed, i.e. exactly the case that matters. Both agents used block mode in their traces, so their traces stand.

(c) F3-TIME-01's sub-claim (c) — "the fill disappears entirely" — holds only in block mode (`fillBar(from: startX, to: endX)`, width `max(0, x1-x0)` = 0, `:75`/`:101`). In inverted mode the two flanking bars (`:72-73`) overlap instead, so the track looks nearly fully filled rather than empty. Cosmetic difference only.

One genuinely weaker sub-claim: F3-TIME-01's "same-minute variant … yields end == start" requires the drag to land in the same minute-of-day as `start`, which is a one-minute-per-day coincidence. Reachable, but it is not the load-bearing case; the load-bearing case is `now < start` → reversed window.

**Failure trace (re-derived from source by the verifier)**

Device Europe/Dublin, wall clock 19:53. Mode "Block these hours" (`blockOutsideWindow == false`). Window 20:00–22:00 (start = 1200, end = 1320). Apps selected, not currently blocking (`insideInterval == false`), so `locked == false` and the slider gesture is live (ScheduleRangeSlider.swift:129).

1. User presses the right-hand handle and drags to the right end of the track, under the axis tick labelled "24:00" (ScheduleRangeSlider.swift:158-160), meaning "block until midnight".
2. `handle(...).onChanged` (`:130-137`): `minute(forX: ~310, width: 329)` → raw 1466 → snapped 1465 → `min(1440, 1465)` = **1440** (`:48-51`).
3. `case .end`: `end = dateAtMinute(max(1440, 1200 + 15))` = `dateAtMinute(1440)` (`:136`).
4. `dateAtMinute(1440)` (`:39-41`): `m = min(1440, 1440)` = 1440 → `Calendar.current.date(bySettingHour: 24, minute: 0, second: 0, of: Date())` → **nil** (verified by running it) → `?? Date()` → **2026-07-25 19:53:xx**.
5. `Model.end.didSet` (Model.swift:50-52) writes 19:53 into `UserDefaults(suiteName: "group.screentimeshield")` key `"end"`. Persisted, survives relaunch (Model.swift:48).
6. UI after re-render: `minutes(of: end)` = 1193 (`:34-37`), so `endX` = 24 + 281×1193/1440 = 256.8 — the end handle jumps to the **left** of the start handle at 258.2. The pill above it reads "7:53 PM" (`:118`, `:54-56`). `fillBar(from: 258.2, to: 256.8)` renders `max(0, -1.4)` = 0 width (`:101`), so the highlighted window vanishes: the card shows an empty track with two overlapping handles.
7. `.onChange(of: model.end)` (ContentView.swift:234) → `disarmIfArmedInactive()` → not armed, no-op. The corrupted `end` is untouched.
8. User taps "Start blocking" at 19:53:40. `primaryDisabled` = false (ContentView.swift:43-48: authorized, not insideInterval, hasApps). `onPrimary` → `start()` (`:50-53`, `:70-74`).
9. `isRiskyToArm()` (`:124-133`): `bi` = (start: 20:00, end: 19:53). `windowContains(now: 1193, start: 1200, end: 1193)` → `start != end`, `start > end` → wrapping branch → `1193 >= 1200` false `|| 1193 < 1193` false → **false**. `freeMinutes(windowStart: 1200, windowEnd: 1193, blockOutsideWindow: false)` → `max(0, -7)` = 0 → `1440 - 0` = **1440**. `false || 1440 <= 30` → **false**. No alert.
10. `performArm()` (`:76-80`): `model.isArmed = true`; `applySchedule()` (`:59-68`) → `Schedule.setSchedule(start: 20:00, end: 19:53, repeats: true)` → `DeviceActivitySchedule(intervalStart: DateComponents(hour:20, minute:0), intervalEnd: DateComponents(hour:19, minute:53), repeats: true)` (Schedule.swift:26-28, `components(from:)` at `:69-71`) → `startMonitoring(.daily, ...)`, errors swallowed by `catch { print }` (`:36-38`).
11. At 20:00 `intervalDidStart(for: .daily)` (DeviceActivityMonitorExtension.swift:53-63) → `model.setRestrictions()`, `model.insideInterval = true`.
12. User sees "Block active" (StatusBanner.swift:33), the CTA reads "Blocking" and is disabled (ContentView.swift:38, `:45`), the mode Picker is disabled (ScheduleCard.swift:21) and the slider gesture is nil (ScheduleRangeSlider.swift:129). Nothing can stop it. If `DeviceActivitySchedule` wraps midnight for intervalStart > intervalEnd (the repo's own documented assumption, Model.swift:34-35), `intervalDidEnd` does not fire until 19:53 the next day → ~23h53m block instead of the 4h the user configured.

Even if step 12's wrap assumption is wrong, steps 1-10 are self-contained and user-visible: the chosen end time is silently replaced by the current clock, the displayed window collapses to nothing, and the schedule registered with the system is not the one shown.

**Apple API semantics checked**

Verified by execution rather than docs, which is stronger here. I ran the exact expression from ScheduleRangeSlider.swift:41 under Apple Swift 6.2.4 / macOS 26 Foundation: `Calendar(identifier: .gregorian).date(bySettingHour: 24, minute: 0, second: 0, of: Date())` returned **nil** in Europe/Dublin, America/New_York, Asia/Tokyo and UTC, while `bySettingHour: 23, minute: 55` returned the correct instant in all four. `Calendar.current` (Europe/Dublin) also returned nil for hour 24. Hour 24 is outside the Gregorian `hour` validRange (0...23), so the `nextDate(after:matching:)` search never matches. This is the only semantic the bug's *existence* depends on, and it is confirmed.

Two semantics I could NOT confirm, both affecting only the magnitude of the consequence, not its existence:
- The project's deployment target is iOS 16.0/16.4 (project.pbxproj), so iOS 16/17 devices use the older ObjC NSCalendar rather than swift-foundation. I could not execute against that Foundation. Note the bug does not disappear under the alternative behaviour: if an older Foundation normalised hour 24 to the next day's 00:00, `end` would read 00:00, `minutes(of: end)` = 0, the end handle would render at the far LEFT edge, `fillBar` width would again be 0, and the registered `intervalEnd` would be `DateComponents(hour: 0, minute: 0)` — still not the user's intent, still a reversed interval in block mode. The specific "substitutes the current time" wording is what would need adjusting, not the finding.
- Whether `DeviceActivitySchedule` with `intervalStart > intervalEnd` genuinely wraps past midnight. Both candidates flagged this as unverified and I did not confirm it from Apple documentation either; the repo asserts it at Model.swift:34-35 and the allow-only mode depends on it. This governs whether step 12 is a ~23h53m lockout or a schedule the system rejects (in which case `Schedule.swift:36-38` swallows the error and the user is armed but unenforced — a different, also-bad outcome).

**Second opinion (agrees)**

_Worst realistic outcome:_ A user configuring an evening "block 22:00 → midnight" at, say, 20:00 drags the end handle to the tick labelled `24:00`, doesn't register that the handle jumped backwards, taps Start, and at 22:00 gets a block that (if `DeviceActivitySchedule` wraps as the repo assumes) does not release until 20:00 the *next* day — ~22 hours, with the CTA disabled the whole time and no confirmation ever shown. If the system does not wrap, the flip side is just as bad against the product promise: the block the user armed silently never activates, and the error is swallowed by `Schedule.swift:36-38`.

Agree the mechanism is real — I re-derived it independently and every cited line reads as claimed. `ScheduleRangeSlider.swift:40-41` clamps to `totalMinutes` (1440, not 1439) and then calls `bySettingHour: 24`; I ran that in six zones (Europe/Dublin, America/New_York, Asia/Tokyo, UTC, Asia/Kolkata, Australia/Lord_Howe) and it returned `nil` in all six, while `23:55` returned correctly, so `?? Date()` fires. No normalisation exists: the only writers of `model.start`/`model.end` are the two slider drags and `AccessController.swift:195-196`, and the only `onChange` hooks (`ContentView.swift:233-235`) call `disarmIfArmedInactive()`, which never touches the value. Not in `status.md` — this is news.

Three corrections to their framing, one of which makes it worse and two of which make it narrower than "lockout".

**1. They UNDERSTATED reachability.** They called 1440 "barely a nudge away" from the 23:55 handle. It's far worse than that: I swept `minute(forX:)` at 0.02pt resolution for three slider widths. At w=329 the 23:55 target is px [303.64, 304.60] — **0.96pt wide** — and *everything* from 304.62 rightwards clamps to 1440. The poison region is ~24pt wide **inside the view** (304.6 → 329), before any out-of-bounds drag tracking is needed, so the "DragGesture isn't clamped" argument isn't even load-bearing. Same at w=361 (1.06pt) and w=297 (0.86pt). Consequence: 23:55, the last representable value, is effectively unselectable, and any drag to the right end of the track lands on the bug 100% of the time. Corroborating the design gap: community `DeviceActivitySchedule` examples express "to midnight" as `hour: 23, minute: 59` precisely because hour 24 isn't representable — so the real defect is that the axis at `:158-160` advertises a value the domain cannot express, and the clamp ceiling at `:40` should be 1439/1435.

**2. They OVER-CLAIMED the confirmation bypass — it is mode-specific, and they never evaluated the other branch.** I ran both modes with start=1200, corrupted end=1193. Block-these-hours (`blockOutsideWindow == false`): `activeNow=false`, `free=1440`, `risky=false` — bypass confirmed, exactly as they said. **Allow-only (`blockOutsideWindow == true`): `blockedInterval` = (1193, 1200), `activeNow=true`, `free=max(0,-7)=0`, `risky=true`** — the alert *does* fire, reading "Blocking starts now and can't be stopped until 8:00 PM" (`ContentView.swift:141`). So in allow-only mode the failure inverts entirely: not a lockout but a **7-minute block where the user asked for all-day-except-a-window**, i.e. silent loss of protection, and the user is at least warned. Their step 5 asserts "only the end handle can reach it" but never checks `freeMinutes`' `blockOutsideWindow: true` branch.

**3. The lockout also needs `now < start`, which they state but don't weight.** If the user is configuring *after* the start time (start 20:00, now 22:30), `end = 22:30` is a perfectly valid forward window: no inversion, no zero-width fill, pill reads "10:30 PM", `free = 1440-150`, no confirm. Outcome there is a silently *shortened* block, not a lockout.

**One thing that blunts the lockout branch that they treated as a non-issue.** They correctly note the fill collapses and the handles overlap, but present that as consequence rather than as a deterrent. During the drag the end handle **detaches from the finger and teleports ~48pt to the left** (to x≈256.8 while the finger is at ≥305), the gradient fill vanishes, and the two time pills overprint 1.4pt apart. That is a loud visual cue mid-gesture, so most users will re-drag rather than tap Start. That's why I put the lockout at occasional while the silent-corruption is always.

**Wrap semantics remain unconfirmed and matter for the "23h53m" number.** Apple's docs do not state that `intervalStart > intervalEnd` wraps midnight; I could not find it (developer-forum threads on `DeviceActivitySchedule` intervals don't address it, and one notes `intervalEnd` isn't always honoured). The repo asserts it at `Model.swift:34-35` and ships allow-only mode on it, and `status.md:17` explicitly lists "wrapping-interval enforcement" as still-unverified real-device QA. So the duration figure is the repo's own untested assumption. What would settle it: register `DeviceActivitySchedule(intervalStart: DateComponents(hour:20), intervalEnd: DateComponents(hour:19, minute:53), repeats: true)` on a device and log `intervalDidStart`/`intervalDidEnd`. Steps 1-10 stand regardless.

Bottom line: CONFIRMED, important, but the honest headline is "the schedule's end time cannot be set to midnight — the advertised 24:00 tick silently writes the current clock into persisted state, and depending on mode and time-of-day that either collapses the window to nothing, arms an inverted near-24h schedule with the risk confirmation bypassed, or silently shrinks an allow-only block to minutes." Calling it simply "lockout" hides the allow-only under-block, which for an app whose promise is enforcement is arguably the more damaging of the two.

Sources: [DeviceActivitySchedule DateComponents intervals](https://developer.apple.com/forums/thread/729841), [Repeating 24 hour DeviceActivitySchedule behavior](https://developer.apple.com/forums/thread/724824), [Monitoring App Usage using the Screen Time Framework](https://crunchybagel.com/monitoring-app-usage-using-the-screen-time-api/)

**Proof path**

Not provable today for the root cause. `dateAtMinute`, `minute(forX:)`, `x(for:)` and `minutes(of:)` are all `private` members of the `ScheduleRangeSlider` SwiftUI `View` (ScheduleRangeSlider.swift:34-52), and UnplugCore does not depend on the app target, so no test can reach them. A test asserting `Calendar.current.date(bySettingHour: 24, ...) == nil` would characterise Foundation, not the app's behaviour, and would pass whether or not the bug is fixed.

What IS provable today, and worth adding regardless: the risk-check half of the trace. `ScheduleMath` is already in UnplugCore with tests at UnplugCore/Tests/UnplugCoreTests/ScheduleMathTests.swift. Add:
- `freeMinutes(windowStart: 1200, windowEnd: 1193, blockOutsideWindow: false)` currently returns 1440; it should express "reversed/invalid window", not "the whole day is free". This pins the `max(0, windowEnd - windowStart)` clamp at ScheduleMath.swift:30 that makes `isRiskyToArm()` return false for an inverted window.
- `windowContains(now: 1193, start: 1200, end: 1193)` == false — documents why `activeNow` cannot fire when `end` has just been set to `now`.

To make the root cause testable, extract the minute↔Date mapping out of the view into UnplugCore as a pure pair over minutes-of-day, e.g. `ScheduleMath.clampMinute(_:) -> Int` (ceiling 1439, not 1440) plus a `minuteOfDay(from:calendar:)`/`date(atMinuteOfDay:on:calendar:)` pair taking an injected `Calendar` and reference `Date`. Then assert: `clampMinute(1440) == 1439` (or that 1440 maps to 23:59/00:00 deliberately rather than by accident); `date(atMinuteOfDay: 1440, ...)` never returns an instant whose minute-of-day differs from the requested value; and round-trip `minuteOfDay(date(atMinuteOfDay: m)) == m` for m in 0...1440 step 5 under a fixed non-UTC calendar. That last property test would have caught this, and would also catch the sibling DST claims (F3-TIME-02/F3-TIME-04) in the same suite.

---

### `V02` · Window persisted as absolute Date but read as hour/minute in current zone -> silently shifts on DST change or travel

- **🔴 Important** · impact **lockout** · unit-testable now · hit **common across the user base, occasional per user: guaranteed twice a year for every armed user in a DST-observing region (i.e. most of the 10 shipped locales), the moment they next open the app, plus any trip across time zones. Fires for a completely ordinary user who touches nothing — not an adversarial or self-sabotage path.**
- **Feature** F3 · **Discovery IDs** F3-TIME-02

**Verifier's reasoning**

Cited lines check out. Model.swift:41-53 persists start/end as absolute Date instants in the app group and re-reads them via object(forKey:) as? Date. The instants are minted from today at ScheduleRangeSlider.swift:41 with Calendar.current.date(bySettingHour:minute:second:of: Date()), so they carry the UTC offset of the drag day. Every consumer re-derives hour/minute from that fixed instant under the current offset: ScheduleRangeSlider.minutes(of:) :34-37 (handle x :62-63, pills :118), Schedule.components(from:) Schedule.swift:69-71 feeding DeviceActivitySchedule :26-28 and :48-50, ContentView.minutesOfDay :114-117 used by isRiskyToArm :124-133, and AccessController.swift:139. No mitigation exists: grep for writers of model.start/model.end and the start/end keys returns only the two drag handlers (ScheduleRangeSlider.swift:134,136) and qaResetToFreshInstall (AccessController.swift:195-196). No NSSystemTimeZoneDidChange observer anywhere, no launch re-anchoring, extension never writes them. components(from:) emits DateComponents with timeZone nil, so after an offset change the registered values are hour 8 / hour 16 instead of the chosen 9 / 17.</reason>
<correctedMechanism>Worse than claimed in one way: re-registration needs no user action. onAppear calls loadSelection() (ContentView.swift:246), which replaces the empty FamilyActivitySelection with the saved one; that fires onChange(of: model.selectionToRestrict) (:218), validateRestriction passes on an identical reload, and control falls to applySchedule() (:228). isArmed is persisted true and re-synced at :248, so the :60 guard passes. The drifted window is pushed to the system on the first cold launch after the offset change. Weaker in another: the invert-to-1440-free-minutes variant needs the two handles last dragged in different offset regimes AND a window shorter than the delta; minGap is 15 min (ScheduleRangeSlider.swift:23), so only a 15-30 min allow-only window inverts. Also the UI-vs-enforcement divergence rests on the unconfirmed sub-claim that a registered repeating schedule is not re-derived; since launch re-registration happens anyway, the durable defect is just that the window silently moves by the offset delta, in the UI and in enforcement.</correctedMechanism>
<rederivedTrace>Europe/Dublin. 2026-07-25 UTC+1: drag start to 09:00, dateAtMinute(540) stores 2026-07-25T08:00Z; end to 17:00 stores 16:00Z. Start blocking: performArm sets isArmed, applySchedule registers .daily with intervalStart hour 9, intervalEnd hour 17, repeats true. 2026-10-25 Ireland leaves IST, offset UTC+0; nothing in the app reacts. 2026-10-26 cold launch: Model.shared loads start=2026-07-25T08:00Z, end=16:00Z; onAppear loadSelection, isArmed synced true from DeviceActivityCenter().activities. Slider: minutes(of: start) under UTC+0 is 480, so the handle draws at 08:00 and the pill reads 08:00, end 16:00 - hours the user never chose. Same launch, no user action: the loadSelection mutation fires onChange :218, insideInterval false, so saveSelection then applySchedule; components(from:) yields hour 8 and 16; stopMonitoring([.daily]) then startMonitoring 08:00-16:00 replaces the registration, and setNotificationSchedule is re-registered inverted 16:00-08:00. Persisted: start/end keys unchanged (July instants), .daily now 08:00-16:00 local. 2026-10-27 08:00: intervalDidStart, insideInterval true, shields applied - locked out during an hour left free, with the card locked (ScheduleCard.swift:21,26) so it cannot be corrected; at 16:00 the block ends, granting an hour of access they wanted blocked. Same with the full delta after any flight.</rederivedTrace>
<apiSemanticsChecked>Fetched the DeviceActivitySchedule init page on developer.apple.com - no usable body returned, so Apple wording on time-zone interpretation is unavailable. WebSearch gave only forum guidance (developer.apple.com/forums/thread/729841) that repeating schedules should carry hour/minute/second only. So sub-claim (b), that a registered repeating schedule keeps its original wall-clock hour across DST, stays unconfirmed and I discounted it. Verified Foundation-level semantics instead: Calendar.current.dateComponents([.hour,.minute], from:) resolves a fixed instant against the current zone, so the result changes when the offset changes; components(from:) emits timeZone-nil DateComponents, so the values handed to DeviceActivityCenter are 8/0 and 16/0 however the system reads them; UserDefaults round-trips Date as a plist date, an absolute instant with no zone.</apiSemanticsChecked>
<alreadyKnown>Nothing in status.md: grepped for dst, timezone, travel, daylight (no hits) and read every schedule/window line - entries cover the redesign, arm/disarm model and wrapping intervals, never time-zone re-anchoring. The only pre-existing mention is the checklist under test, qa/invariants.md:27 (invariant F3.10), which states the invariant and names the cause. That is the hypothesis, not a known-bug record, so this is news as a confirmed defect.</alreadyKnown>
<testTarget>Schedule.components(from:) is an internal static on the app target and ScreenTimeShieldTests already does @testable import Unplug (ScreenTimeShieldTests.swift:9). Test: make the instant as the slider does under a fixed zone (Gregorian Calendar, timeZone Europe/Dublin, bySettingHour 9 on a July 2026 date), round-trip through UserDefaults(suiteName: group.screentimeshield), then set NSTimeZone.default to UTC and assert Schedule.components(from: reloaded).hour == 9 - it fails with 8. Reset with NSTimeZone.resetSystemTimeZone() in tearDown. Needs extraction for the rest: ScheduleRangeSlider.minutes(of:)/dateAtMinute and ContentView.minutesOfDay are private inside views, so the wrong-handle-position and wrong-isRiskyToArm halves require lifting those into UnplugCore, ideally as a minutes-of-day Int type, which is also the fix. Enforcement shift end-to-end needs a device and a real DST rollover; the code-truth defect does not.</testTarget>
</invoke>

**Second opinion (agrees)**

_Worst realistic outcome:_ The user's block window silently slides by the UTC-offset delta without them touching the schedule, and the app then displays and enforces the moved times as if they had chosen them. Realistically: after a DST rollover they are shielded for an hour they left free and cannot stop it while it is active, and get an hour of unblocked access they had asked to be blocked at the other edge; after a long flight the whole window can land hours off (e.g. a Dublin 22:00-07:00 block enforcing 14:00-23:00 in Los Angeles), i.e. a multi-hour daytime lockout with no way out until it ends, and zero protection during the hours they actually wanted covered.

Mechanism re-derived independently and every cited line is accurate. Model.swift:41-53 stores absolute Dates; ScheduleRangeSlider.swift:41 mints them from today in the drag-day offset; ScheduleRangeSlider.swift:34-37 (:62-63, :118), Schedule.swift:69-71 (feeding :26-28, :48-50), ContentView.swift:114-117 (:126-131) and AccessController.swift:139 all re-read hour/minute under Calendar.current. No writer other than the two drags and qaResetToFreshInstall (AccessController.swift:195-196); no TimeZone/NSSystemTimeZone reference exists anywhere in the repo (grepped, zero hits); the monitor extension never writes start/end.

Their key correction is right and is the load-bearing part: loadSelection() is called from exactly two places — ContentView.swift:246 and DeviceActivityMonitorExtension.swift:61 (separate process). ScreenTimeShieldApp does NOT call it, so on every cold launch selectionToRestrict genuinely transitions empty -> saved, a real Equatable change, so onChange (ContentView.swift:218) fires and reaches applySchedule() (:228). isArmed is @AppStorage-persisted (Model.swift:31), so the :60 guard passes whether onChange lands before or after the :248 resync. Re-registration of the drifted window therefore needs no schedule edit.

Where they are wrong or incomplete:

1. Class is half-stated. They described only the fall-back direction (offset shrinks -> window slides EARLIER -> unwanted, un-stoppable block at the front edge = lockout). Spring-forward is the exact mirror: the stored instant reads an hour LATER, so the block starts an hour late and ends an hour late — i.e. an hour of restricted-app access the user explicitly asked to be blocked, on the app whose entire promise is that the block holds. Each direction happens once a year. The right class is "silent schedule drift", manifesting as lockout in autumn and under-enforcement in spring; labelling it "lockout" understates the enforcement-gap half, which for this product is at least as damaging.

2. "Needs no user action" is slightly overstated: it needs a foreground cold launch. If the user never opens the app after the offset change, the already-registered bare hour/minute schedule keeps firing at the intended wall clock and only the (unseen) UI is wrong. Realistic, but it is a launch, not zero-action.

3. They overstate permanence twice. The drift is self-healing: any handle drag re-mints from today (ScheduleRangeSlider.swift:41) and the edit disarms (ContentView.swift:233-234 -> disarmIfArmedInactive -> stop), so one drag + Start fully fixes it. And "the card locked so it cannot be corrected" (ScheduleCard.swift:21,26; primaryDisabled ContentView.swift:45) is true only for the duration of that active block, not permanently. Also, after the launch re-registration the UI and enforcement AGREE on the drifted hours, so the wrong window is visible on the slider pills — the divergence they discounted really is transient, and the residual defect is "the window moved and the app shows the moved times as if you chose them".

4. They undersold the worst case by anchoring on DST's one hour. Travel gives the same code path a multi-hour delta: a Dublin 22:00-07:00 block stores 21:00Z/06:00Z, and read in Los Angeles (UTC-7) that is 14:00-23:00 — a nine-hour daytime block the user never chose, un-stoppable while active. That, not the DST hour, is the realistic worst outcome.

alreadyKnown: agree. status.md has no dst/timezone/travel/daylight entry (grepped); the only prior mention is qa/invariants.md:27 (F3.10), which is the invariant under test, not a known-bug record.

---

### `V05` · Risk gate and slider fill use non-wrapping window math while the registered interval wraps midnight

- **🔴 Important** · impact **lockout** · unit-testable now · hit **Split, and the first verifier collapsed the two: the wrong-picture half is COMMON (every upgrader with a legacy overnight window — the app's core use case); the "23h45m block, no confirmation" lockout half is RARE (needs the collapsing end-handle drag AND arming within 30 min before the window start).**
- **Feature** F3 · **Discovery IDs** F3-MODE-01
- **Already in status.md:** Not recorded as an open bug. status.md's "## Bugs" section lists only: Family Controls authorization (done), the "selection was reset" toast (done), the arm-confirm UI stall (done), "Notifications bug — needs investigation", and "Outstanding bug mentioned in README". None match this mechanism.

Two adjacent-but-not-matching records:
- status.md line 16 asserts the **opposite** of this finding: the redesign "handles wrapping windows incl. overnight & 'block all except X' — `Model.blockedInterval`", and calls the conditional confirm "`UnplugCore/ScheduleMath`, unit-tested". So the project believes wrapping is handled end-to-end; this finding is that only `blockedInterval`/`windowContains` handle it and `freeMinutes`/`fillBar` do not. That makes it news, and news that contradicts the tracker.
- `ScreenTimeShield/ScheduleRangeSlider.swift:9-10` does self-declare the *slider's* same-day assumption ("overnight (end < start) is a known follow-up"), so the fill half is a known limitation in a source comment — but it is not in status.md, and the comment does not cover the risk gate at ContentView.swift:129-131, which is the part with the lockout consequence.
- The redesign follow-ups bullet does list "real-device QA (… wrapping-interval enforcement …)" as outstanding, which is where this would have been caught.

**Verifier's reasoning**

Every cited line says what the claim says it says, and I found no normalizing guard anywhere.

CODE TRUTH CHECKS (all pass):
- `UnplugCore/Sources/UnplugCore/ScheduleMath.swift:30` is literally `let windowLength = max(0, windowEnd - windowStart)` — non-wrapping by construction. `:31` returns `blockOutsideWindow ? windowLength : (minutesPerDay - windowLength)`. So for `windowStart > windowEnd` it returns 1440 (Block) or 0 (Allow-only). I ran the exact body: free(1320,360,false)=1440, free(1320,360,true)=0, free(540,525,false)=1440. Claim's numbers are right.
- `ScreenTimeShield/ContentView.swift:126-128` passes `bi = model.blockedInterval` into the wrap-aware `windowContains`; `:129-131` passes the *un-inverted* `model.start`/`model.end` into the non-wrap-aware `freeMinutes`. The split is exactly as described. `:132` `return activeNow || free <= 30`.
- `ScreenTimeShield/Model.swift:36-38` `blockedInterval` is wrapping-capable and the doc comment at `:34-35` explicitly says "start > end … interprets as wrapping midnight". Two different interval models for one schedule: real.
- `ScreenTimeShield/ScheduleRangeSlider.swift:101` is `.frame(width: max(0, x1 - x0), height: trackHeight)`; `:75` draws `fillBar(from: startX, to: endX)` in Block mode → zero width when `endX < startX` → nothing drawn. `:72-73` draw `[labelInset, startX)` + `[endX, w-labelInset)` in Allow-only → with `endX < startX` those two overlap and cover the entire track. Both fill claims are right.
- No normalization exists. `ContentView.onAppear:245-255` only does `loadSelection()`, `isArmed` resync and the invalidated-selection toast. `Model.swift:41-53` loads the raw persisted `Date`s. `Schedule.setSchedule` (`Schedule.swift:25-41`) hands `components(from:)` straight to `DeviceActivitySchedule` with no reorder. Grep for overnight/midnight/normaliz across the repo returns only comments, no guard.
- `minGap = 15` (`ScheduleRangeSlider.swift:23`, applied at `:134-136`) is applied in the *minute* domain before `dateAtMinute`, so it does not prevent a wrapping pair once `dateAtMinute` falls back.
- Nothing corrects the picture in text: `ScheduleCard.swift:30-40` shows no times, and `StatusBanner.swift:32` only prints "Block active"/"Block inactive" ("Times live on the slider only").

REACHABILITY (the part I tried hardest to break, and could not):
- Path (b): `dateAtMinute(1440)` → `Calendar.current.date(bySettingHour: 24, minute: 0, second: 0, of: Date())`. I ran it: **nil** (Gregorian, Europe/Dublin), so `?? Date()` at `ScheduleRangeSlider.swift:41` returns *now*. `minute(forX:)` at `:51` clamps to `totalMinutes` = 1440, and `x(for: 1440)` = `w - labelInset` (the right end of the track), so any drag to or past the right edge yields m = 1440. The end-handle branch `end = dateAtMinute(max(m, minutes(of: start) + minGap))` (`:136`) → `max(1440, …)` = 1440 → nil → `end = now`. If now < start, `start > end`.
- Path (a): `git show 8c5aca7^:ScreenTimeShield/ContentView.swift` lines 109-113 are two unconstrained `DatePicker`s on `$model.start`/`$model.end` with no ordering check, and line 39 registers `Schedule.setSchedule(start: model.start, end: model.end, …)` as-is. `git show 8c5aca7^:ScreenTimeShield/Model.swift` lines 30-40 use the **same** `group.screentimeshield` keys `"start"`/`"end"`, so a legacy overnight window survives verbatim into v1.3. status.md confirms 1.3 was never released (pulled from review 2026-06-19), so the pre-redesign UI is what is on the App Store today — the upgrade population is real, not hypothetical.

I could not refute it. The one thing I could not confirm is whether `DeviceActivitySchedule` really enforces a wrapping component pair, but the two arithmetic defects (freeMinutes value, fill geometry) are pure local math and are wrong regardless of what the system does with the interval.

**Correction to the original claim**

The mechanism is real but the claim over-attributes the missing-confirmation harm. Two corrections:

1. The legacy-upgrade path (a) does NOT breach F4.11. A legacy 22:00→06:00 Block-mode window has 960 real free minutes, so no confirmation was ever required — `freeMinutes` returning 1440 instead of 960 suppresses nothing. The trace's "given no warning … and is locked out" is wrong: the 8-hour nightly block is exactly what that user configured. And in Allow-only mode the same window gives `freeMinutes` = 0 ≤ 30, which produces an *extra* confirm (over-warning, safe), with a `confirmMessage` (ContentView.swift:141-146) that is actually correct. So path (a) is a **rendering + reported-free-time** defect only: in Block mode the slider draws no blocked region at all for a schedule that IS registered and WILL fire; in Allow-only the fill covers the whole 24h track.

2. The missing-confirmation harm (23h45m/day armed silently) is reachable ONLY via path (b), i.e. it is downstream of the separate `dateAtMinute(1440) → nil → ?? Date()` defect (invariant F3.4, ScheduleRangeSlider.swift:39-42), which the candidate itself hands to the slider lens. F4.11 is breached there in a narrow time band: it needs `end := now` to land within 30 minutes *before* `start` (e.g. default 09:00 start, user dragging at 08:45). Outside that band start > end still misreports free time badly (e.g. start 22:00, drag at 15:00 → reported 1440, real 420) but stays above the 30-minute threshold, so no confirm was due.

So the correct framing: F3.11 is unconditionally violated — `freeMinutes` reports a number that contradicts the interval that `Model.blockedInterval` hands to the system whenever the window wraps — and the F3.11 breach becomes an F4.11 breach only when composed with F3.4. Fixing F3.11 alone (`windowLength = ((windowEnd - windowStart) % 1440 + 1440) % 1440`) plus the fill (draw two segments when endX < startX) closes both the wrong picture and the wrong gate; fixing F3.4 alone closes the reachable lockout but leaves the wrong picture for upgrading users.

**Failure trace (re-derived from source by the verifier)**

I re-derived two traces from source. The second is the one that actually breaches F4.11.

TRACE A — legacy overnight window, wrong picture (no F4.11 breach; corrects the claim):
1. User on the currently shipped (pre-1.3) build sets Schedule Start 22:00 / Schedule End 06:00 via the unconstrained DatePickers (`8c5aca7^:ContentView.swift:109-113`). `Model.didSet` writes them to `group.screentimeshield` keys "start"/"end" (`8c5aca7^:Model.swift:33,40`).
2. User updates to v1.3. `Model.swift:41-53` reads both Dates back unchanged (same suite, same keys). `start` = 22:00, `end` = 06:00.
3. `ScheduleCard.swift:23-29` renders `ScheduleRangeSlider(start: 22:00, end: 06:00, inverted: false)`. `startX` = x(1320), `endX` = x(360), so `endX < startX`. Block mode takes `fillBar(from: startX, to: endX)` (`:75`) → `max(0, x1 - x0)` = 0 (`:101`) → **no blocked region is drawn**. Handle pills still read "22:00" and "06:00". `ScheduleCard` prints no caption in Block mode; `StatusBanner` prints no times.
4. `ContentView.onAppear:245-255` does not normalize. Nothing else does.
5. User taps "Start blocking" at noon. `isRiskyToArm()`: `bi` = (22:00, 06:00); `windowContains(now: 720, start: 1320, end: 360)` → wrapping branch → `720 >= 1320 || 720 < 360` → false. `freeMinutes(1320, 360, false)` → `max(0, 360-1320)` = 0 → `1440 - 0` = **1440**. `1440 <= 30` false → no confirm.
6. `performArm()` → `isArmed = true` → `applySchedule()` → `Schedule.setSchedule(22:00, 06:00, repeats: true)`.
Persisted state: `is_armed` = true, `.daily` registered for (22:00, 06:00). What the user sees: an **empty** 24h track with two pills, while an 8-hour nightly block is armed. At 22:00 `intervalDidStart` sets `inside_interval` = true, `primaryTitle` = "Blocking" and `primaryDisabled` = true (ContentView.swift:38,45). Correctness defect: the picture contradicts the enforcement. NOT a missing-confirmation defect — real free time is 960 min, so no confirm was due. (Same user in Allow-only: `freeMinutes(1320,360,true)` = 0 → confirm fires spuriously, and both flanking fills overlap to cover the whole track.)

TRACE B — F4.11 breach, near-permanent block with no confirmation:
1. Fresh install, default window 09:00–17:00 (`Model.swift:42,49`), Block mode (`block_outside_window` default false, `Model.swift:29`), apps selected, not armed. Local time 08:45.
2. User drags the END handle to the right end of the track, meaning "block until midnight". `minute(forX:)` (`:48-52`) clamps to `totalMinutes` = 1440 (and `x(for: 1440)` = `w - labelInset` is exactly the track's right end, so this is the natural gesture, not an edge case).
3. `:136` `end = dateAtMinute(max(1440, 540 + 15))` = `dateAtMinute(1440)`. `:40` `m` = 1440 → `bySettingHour: 1440/60 = 24` → **nil** (executed and verified) → `:41` `?? Date()` → `end = 08:45`.
4. `Model.end.didSet` (`:50-52`) persists 08:45. `ContentView.onChange(of: model.end)` → `disarmIfArmedInactive()` — no normalization, and it was not armed anyway.
5. Slider redraws: end pill now reads "08:45", `endX` = x(525) < `startX` = x(540) → `fillBar` width 0 → **zero fill**. minGap is not violated in the minute domain (1440 ≥ 555), so nothing objects.
6. User taps "Start blocking". `isRiskyToArm()`: `bi` = (09:00, 08:45); `windowContains(now: 525, start: 540, end: 525)` → wrapping branch → `525 >= 540 || 525 < 525` → false. `freeMinutes(540, 525, false)` → `max(0, 525-540)` = 0 → **1440** → `1440 <= 30` false → **no confirm, `performArm()` runs directly** (ContentView.swift:73).
7. `model.isArmed = true`; `Schedule.setSchedule(09:00, 08:45, repeats: true)` → `DeviceActivitySchedule(intervalStart: {9,0}, intervalEnd: {8,45}, repeats: true)`.
Persisted state: `is_armed` = true, `start` = 09:00, `end` = 08:45, `.daily` registered wrapping. What the user sees: an empty track, no warning. From 09:00 `inside_interval` = true → `primaryDisabled` (`:45`), mode picker disabled (`ScheduleCard.swift:21`), slider `locked` so its drag gesture is nil (`ScheduleRangeSlider.swift:129`). The block covers [09:00, 24:00) ∪ [00:00, 08:45) = 1425 min/day; "Stop blocking" is tappable only 08:45–09:00, every day, indefinitely. Real free time 15 min vs the 1440 the gate believed — the F4.11 confirmation that exists precisely to prevent this never appeared.

**Apple API semantics checked**

1. `Calendar.date(bySettingHour:minute:second:of:)` with hour 24 — VERIFIED BY EXECUTION, not docs. I ran `Calendar.current.date(bySettingHour: 24, minute: 0, second: 0, of: Date())` on this machine (Gregorian, Europe/Dublin): returns **nil**. Control: hour 23/minute 55 returns a valid Date. This confirms the `?? Date()` fallback fires for m = 1440. Hour 24 is out of the valid `hour` range in every common calendar, so I expect this to be locale/calendar-independent.
2. `freeMinutes` arithmetic — no API involved; I ran the exact body of ScheduleMath.swift:29-32 and reproduced 1440/0/1440.
3. `DeviceActivitySchedule` treating `intervalStart > intervalEnd` as wrapping midnight — **NOT confirmed**. I fetched developer.apple.com/documentation/deviceactivity/deviceactivityschedule and the page is JS-rendered, so no doc text was retrievable; I could not independently verify the candidate's claim that the JSON says nothing about wrapping. I therefore treat this as unverified rather than accepting it. It is not load-bearing: the two defects I confirmed (freeMinutes value, fill geometry) are pure local arithmetic and misreport regardless. It only decides which symptom the user gets — either a ~1425-minute/day enforced block (wrapping honored) or, if the components are rejected, `Schedule.swift:37-39` swallows the throw (`catch { print }`) while `performArm()` has already set `model.isArmed = true` at ContentView.swift:78, so the CTA reads "Stop blocking" with nothing registered. What would settle it: register a wrapping `DeviceActivitySchedule` on a real device and observe whether `intervalDidStart` fires at the wrap start.
4. `@AppStorage` cross-process observation — not relied on by this finding (`blockOutsideWindow` write visibility is corroborated independently by status.md line 16, which records a fixed bug caused by that very `onChange` firing).

**Second opinion (agrees)**

_Worst realistic outcome:_ Realistic worst case for the common population: an upgrader whose nightly 22:00→06:00 block still works sees an empty schedule track, touches a handle to "fix" it, and `onChange(of: model.end)` → `disarmIfArmedInactive()` → `stop()` silently tears the nightly block down while minGap clamping rewrites 22:00→06:00 into a 15-minute window — protection lost with no warning. Realistic worst case for the rare tail: a wrapping block of 1440 − (windowStart − now) minutes/day is armed with no confirmation and an empty fill; at the extreme that is 23h45m/day with a 15-minute daily escape slot, not a permanent lockout.

I agree the bug exists and re-derived it independently, but the first verifier over-claimed the consequence class ("lockout") by promoting the narrowest of the reachable cases to the headline, and they understated the broadest one.

WHAT I CONFIRMED (all cited lines verified, no guard exists)
- `UnplugCore/Sources/UnplugCore/ScheduleMath.swift:30` is literally `let windowLength = max(0, windowEnd - windowStart)`. I ran it: free(1320,360,false)=1440, free(1320,360,true)=0, free(540,525,false)=1440. F3.11 (qa/invariants.md:28, "freeMinutes correctly reports unblocked minutes for the effective mode") is unconditionally breached for any `start > end`. This half is pure local arithmetic, no API dependency — undeniable.
- The split at `ScreenTimeShield/ContentView.swift:126-131` is exactly as described: wrap-aware `windowContains` on `bi`, non-wrap-aware `freeMinutes` on the raw `model.start`/`model.end`.
- `ScreenTimeShield/ScheduleRangeSlider.swift:101` `max(0, x1 - x0)` → zero-width Block fill when `endX < startX`; `:71-76` overlapping flanking bars in Allow-only. Both right.
- Normalization: none. I grepped every writer of `model.start`/`model.end` — only `ScheduleCard.swift:24-25` bindings and `AccessController.swift:195-196` (QA reset). `Model.swift:41-53` loads raw Dates; `Schedule.swift:26-28` + `:69-70` pass components through unreordered.
- `Calendar.current.date(bySettingHour: 24, ...)` → nil, verified on this machine (Europe/Dublin). And I verified the reachability quantitatively: at w=350, `minute(forX:)` at the track's right end (x = w − 24) = 1440; 2pt left = 1430. So 23:55 lives in a ~1pt band and "drag end to midnight" reliably produces 1440 → `?? Date()` → end := now (F3.4, invariants.md:21).
- `git show 8c5aca7^:ScreenTimeShield/ContentView.swift:108-111` — two unconstrained `DatePicker`s on `$model.start`/`$model.end`, same app-group "start"/"end" keys. Legacy overnight windows are real and survive verbatim.
- Not in status.md as a known open bug. Worse: status.md:16 asserts the redesign "handles wrapping windows incl. overnight" — this finding falsifies that claim, so it is news.

WHERE THEY WENT WRONG — (1) the class
Their Trace A (legacy 22:00→06:00) does NOT produce a lockout and they half-admit it, yet "lockout" is the label they carried forward. On upgrade `ContentView.swift:248` syncs `isArmed` from the already-registered `.daily`, so enforcement is exactly what the user asked for; real free = 960 min so no confirm was due. The defect there is purely wrong-picture. They then missed the actual harm in that population: the empty track is what makes the user touch the slider, and `ScheduleRangeSlider.swift:134/136` minGap-clamps a legacy overnight pair (with end=06:00, start clamps to ≤05:45; with start=22:00, end clamps to ≥22:15) while `ContentView.swift:233-234` → `disarmIfArmedInactive()` → `stop()` tears the nightly block down. So for the common population the consequence is LOSS OF PROTECTION, not lockout — the opposite failure direction from the one they labelled.

WHERE THEY WENT WRONG — (2) the frequency of the lockout tail
Their Trace B is correct as written (I re-derived every step, including that `activeNow` cannot save it: because the bug sets `end := now`, the user is always sitting exactly at the boundary of the free gap `[end, start)`, so `windowContains` is always false at the moment of the tap — there is genuinely no mitigation there). But the magnitude is a function of `windowStart − now`, and they only presented the 15-minute instance:
- The wrap requires now < minutesOfDay(start) at drag time (drag it in the evening and you get end = now > start — a shorter-than-intended block, correctly drawn, harmless).
- The F4.11 breach (missing confirmation that was actually due) requires `windowStart − now ≤ 30`, i.e. the collapsing drag AND the arm both inside the half hour before the window start. Do the same drag at 02:00 with a 09:00 start and real free = 420 min, so no confirmation was due — you get a 17h block instead of the intended 15h with an empty track, which is a real correctness defect but not an F4.11 breach and not a lockout.
- They also omitted a visibility factor that cuts the arming probability in the 08:45 case specifically: 525 and 540 minutes are ~3pt apart on the track, so the two 28pt handles and both time pills ("09:00" / "08:45") collapse on top of each other with zero fill. That state looks obviously broken; an ordinary user re-drags rather than taps Start. Their "what the user sees: an empty track, no warning" undersells how visibly wrong it is.
- "indefinitely" is also soft: `intervalDidEnd` sets `inside_interval = false` (DeviceActivityMonitorExtension.swift:74-78), so `primaryDisabled` (ContentView.swift:45) releases daily for 15 minutes and "Stop blocking" works. Escapable once a day, not permanent.

WHAT NEITHER OF US CAN SETTLE
The lockout reading needs `DeviceActivitySchedule` to accept and wrap a 23h45m `intervalStart > intervalEnd` repeating pair. Apple's docs do not state wrapping semantics at all (I searched; only same-day and 00:00–23:59 examples exist, plus forum reports that intervalEnd "is not always triggered"). If instead the system rejects it, `Schedule.swift:37-39` swallows the throw after `model.isArmed = true` (ContentView.swift:78-79) and the outcome flips to phantom-armed / no protection. So the F3.11 and fill defects are CONFIRMED unconditionally; the specific "near-permanent block" consequence is UNCERTAIN and would be settled by one device test of a (09:00, 08:45) repeating schedule.

CORRECTED FRAMING: this is a wrapping-window truth defect in the schedule control — `freeMinutes` and `fillBar` cannot express `start > end` while `blockedInterval` and the registered `DeviceActivitySchedule` can. Its common consequence is a schedule drawn as empty for legacy overnight users, which leads them to silently disarm their own nightly block; its rare consequence is an over-long wrapping block armed without the F4.11 confirmation. Fix is the same either way (normalize/wrap-aware `freeMinutes` + wrap-aware fill + kill the `dateAtMinute(1440)` fallback), so the report is actionable as filed — just do not sell it to the author as "ordinary user gets locked out for a day".

**Proof path**

`ScheduleMath.freeMinutes` is pure and already lives in UnplugCore, and invariant F3.11 anchors the obligation on it (ScheduleMath.swift:29-32), so a test in `UnplugCore/Tests/UnplugCoreTests/ScheduleMathTests.swift` proves the core defect today with no extraction and no simulator:
- `freeMinutes(windowStart: 1320, windowEnd: 360, blockOutsideWindow: false)` should be 960 (block 22:00→06:00 leaves 16h free) — returns **1440** today.
- `freeMinutes(windowStart: 1320, windowEnd: 360, blockOutsideWindow: true)` should be 480 — returns **0** today.
- `freeMinutes(windowStart: 540, windowEnd: 525, blockOutsideWindow: false)` should be 15 — returns **1440** today, i.e. the exact value that makes `ContentView.isRiskyToArm()` skip the confirm.
Existing tests only cover same-day windows (ScheduleMathTests.swift:31,36), which is why this slipped; `windowContains` already has wrapping coverage at :19-24, so the asymmetry is visible in the test file itself.

Not provable today, would need extraction: the fill geometry lives inside `ScheduleRangeSlider.body`/`fillBar` (ScheduleRangeSlider.swift:71-76, 98-104). Proving "a wrapping window draws two flanking segments, not zero width" needs a pure helper, e.g. `fillSegments(startMinute:endMinute:inverted:width:) -> [(CGFloat, CGFloat)]`, hoisted out of the view (ideally into UnplugCore alongside ScheduleMath). Likewise the `dateAtMinute` nil fallback needs a pure `minuteToHourMinute`/clamp helper to be asserted.

Not provable by unit test at all: whether DeviceActivity actually enforces the wrapping pair as 1425 minutes (device-only), but that only affects which of two bad outcomes the user gets, not whether the invariant is broken.

---

### `V09` · Removing every selected app while armed leaves .daily registered, so the block activates and locks with nothing shielded

- **🔴 Important** · impact **lockout** · needs device · hit **rare via the mechanism as written (deliberate deselect-all while armed and pre-window); occasional via the token-invalidation variant of the same missing guard (see note)**
- **Feature** F4 · **Discovery IDs** F4-STATE-03
- **Already in status.md:** Not recorded. `status.md` has two adjacent entries that do NOT cover this mechanism: (a) under "Bugs" — "`Schedule` still swallows `startMonitoring` errors (`catch { print }`)" (a failed registration, not a successful registration with an empty selection); (b) under Features → "Redesign follow-ups" — "real-device QA (… active-block removal guard …)", which is the `insideInterval == true` removal path at ContentView.swift:221, whereas this bug is the `insideInterval == false` removal path that has no guard at all. `qa/invariants.md` has no invariant asserting "an active block enforces a non-empty token set"; the candidate's "Invariant NEW" label is fair.

**Verifier's reasoning**

Every cited line says what the claim says it says, and I found no guard anywhere that prevents the state.

Code truth checks:
- `ScreenTimeShield/ContentView.swift:60` — `guard model.isArmed, !isExpired, !model.isEmpty() else { return }`. Exact. An empty selection makes `applySchedule()` a no-op, and it is the ONLY place `.daily` is re-registered from an edit.
- `ScreenTimeShield/ContentView.swift:233-235` — `disarmIfArmedInactive()` is wired only to `model.start`, `model.end`, `model.blockOutsideWindow`. The selection handler (`:218-229`) never calls it. Confirmed.
- Reachability of the empty selection while armed: `ScreenTimeShield/AppCard.swift:68` binds the system picker directly to `$model.selectionToRestrict`, so deselect-all commits straight into the model; `:45-59` proves the empty state is a designed, reachable UI state. `Model.saveSelection()` (`Model.swift:83-90`) encodes and persists the empty selection unconditionally, so `loadSelection()` in the extension reads it back empty.
- `ScreenTimeShield/Model.swift:95-97` — all three shield facets are set to `nil` when the corresponding token set is empty, i.e. identical to the `clearRestrictions()` teardown at `:100-104`. Confirmed.
- `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:47-64` — `intervalDidStart` has no emptiness check. The only early return is `guard enforcementAllowed` (`:56`), which is true for a trial/paid user (`AccessController.swift:118` writes `accessState != .expired`). Then `loadSelection()` → `setRestrictions()` → `model.insideInterval = true` unconditionally. Confirmed.
- The lockout consequences are real: `ContentView.swift:44-45` (`if model.insideInterval { return true }` in `primaryDisabled`), `:51` (`onPrimary` early-returns), `ScheduleCard.swift:21` (`.disabled(model.insideInterval)`), `ScheduleRangeSlider.swift:129` (`.gesture(locked ? nil : DragGesture(...))`, with `locked: model.insideInterval` passed at `ScheduleCard.swift:26`), `StatusBanner.swift:33` ("Block active"). So from window start to window end the user sees an active block, cannot stop it, cannot change the window — and nothing is shielded.

Guards I actively looked for and did not find:
- `grep -rn "setRestrictions()\|clearRestrictions()"` over all four targets: only `DeviceActivityMonitorExtension.swift:62/76`, `ContentView.swift:85` (stop), `AccessController.swift:189` (QA reset). No empty-selection disarm anywhere.
- `ScreenTimeShieldApp.swift:95-104` (scenePhase) only calls `refreshAccess()`; it does not touch selection or arm state.
- `ContentView.swift:245-255` (`onAppear`) resyncs `isArmed` FROM `DeviceActivityCenter().activities.contains(.daily)` — which is still true — so the launch-time resync reinforces the bad state rather than fixing it.
- `Model.selectionIsInvalidated()` (`Model.swift:106-108`) is true here (`hasSelection` stayed true via `saveSelection()`), so a cold launch shows the persistent "App selection was reset, please re-select apps" toast — a hint, not a disarm.

Not in `status.md`. Two adjacent-but-different entries exist (the swallowed `startMonitoring` error, and the "active-block removal guard" device-QA follow-up), neither of which is this mechanism. No invariant covers it directly; it is closest in spirit to F4.4 (an active block whose enforced set is empty) and F4.3 (locked UI).

**Correction to the original claim**

Two parts of the claim need correcting; the core defect stands.

1. The "bypass recipe" framing is overstated and should be dropped. The user must clear the selection while the block is INACTIVE, and while armed-inactive the primary CTA is already enabled and reads "Stop blocking" (`ContentView.swift:39`, `:46` — `if model.isArmed { return false }`). Nothing locked is escaped, so this is not a bypass of an active block (F4.13 is intact). The real defect is the inverse: a legitimate user is trapped in a "Block active" UI that enforces nothing.

2. "Adding apps back during that window does not help either: nothing in the main app calls setRestrictions()" is unsupported and probably wrong. `openPicker()` (`ContentView.swift:95-98`) only guards on `isExpired`, so the picker IS reachable mid-block. Re-adding apps then runs `ContentView.swift:218-229`: `validateRestriction()` (`Model.swift:74-81`) passes trivially because the saved selection is empty (empty == empty ∩ anything), so no revert; `saveSelection()` persists the new set; and `applySchedule()` at `:228` now clears the `!isEmpty()` guard and calls `Schedule.setSchedule(...)` (`Schedule.swift:25-41`), re-registering `.daily` mid-interval. Since the interval contains "now", `intervalDidStart` is expected to fire — the very mechanism `performRestrictHour()` (`ContentView.swift:105-110`, `intervalStart = components(from: Date())`) depends on for the whole quick-hour feature — which then calls `setRestrictions()` with the new selection. So a recovery path very likely exists; it is just undiscoverable, and identical to the re-registration that candidates F4-STATE-02 / F4-XPROC-01 claim is itself hazardous.

Corrected consequence: from window start until the user happens to reopen the picker and re-add apps, the app shows "Block active", locks the CTA / mode picker / slider, and shields nothing. Because `.daily` is registered with `repeats: true` and `is_armed` stays true, this recurs every day. Minor detail: the app card during that window shows the tappable "Choose apps & websites" empty state under a "Restricted" header (`AppCard.swift:27`, `:45-59`), not "an empty list".

**Failure trace (re-derived from source by the verifier)**

Preconditions: trial or paid access (`enforcement_allowed = true`), Screen Time approved, window 09:00–17:00 in Block mode, 4 apps selected, armed via Start → `is_armed = true`, `.daily` registered with the then-non-empty event.

1. 08:00, block inactive. `insideInterval == false`, CTA reads "Stop blocking" and is enabled.
2. User taps the app card (`openPicker`, ContentView.swift:95-98) and deselects all four apps in the system picker, which writes through the binding at AppCard.swift:68 into `model.selectionToRestrict`.
3. `.onChange(of: model.selectionToRestrict)` (ContentView.swift:218) → `model.insideInterval` is false so the removal guard at `:221` is skipped → `model.saveSelection()` (Model.swift:83-90) persists an EMPTY `FamilyActivitySelection` into the app group and leaves `has_selection = true` → `applySchedule()` (`:228`) returns immediately at the `!model.isEmpty()` guard (ContentView.swift:60).
4. Persisted state after step 3: `is_armed = true`, `.daily` still registered (nothing called `Schedule.stopMonitoring`), saved selection empty.
5. User backgrounds the app.
6. 09:00 — the system calls `DeviceActivityMonitorExtension.intervalDidStart(for: .daily)`. `activity.rawValue == "daily"` (`:53`), `enforcementAllowed` is true (`:56`), so: `model.loadSelection()` (empty) → `model.setRestrictions()` sets `shield.applications`, `shield.applicationCategories`, `shield.webDomains` all to `nil` (Model.swift:95-97) → `model.insideInterval = true` (`:63`).
7. Persisted state: `is_armed = true`, `inside_interval = true`, `.daily` registered, `ManagedSettingsStore` shields all nil.
8. User opens the app at 09:30. `onAppear` → `loadSelection()` (empty), `isArmed = activities.contains(.daily)` = true, `selectionIsInvalidated()` true → persistent "App selection was reset, please re-select apps" toast. `StatusBanner` reads "Block active" (StatusBanner.swift:33), primary CTA reads "Blocking" with the lock and is disabled (ContentView.swift:38, :45; PinnedActions applies `.disabled`), mode picker disabled (ScheduleCard.swift:21), slider drag gesture is nil (ScheduleRangeSlider.swift:129). Every app on the phone opens normally — no shield.
9. 17:00 — `intervalDidEnd(for: .daily)` clears shields and sets `inside_interval = false`; the UI unlocks. `is_armed` is still true and `.daily` still repeats, so step 6 recurs the next day.

**Apple API semantics checked**

1. `ManagedSettingsStore.shield.applications/applicationCategories/webDomains = nil` means "nothing shielded" — no external doc needed: the app itself uses exactly these three nil assignments as its teardown in `Model.clearRestrictions()` (Model.swift:100-104), called from `stop()` (ContentView.swift:85) and `intervalDidEnd` (extension `:76`). So the no-enforcement half of the trace rests on the app's own semantics.

2. `intervalDidStart` firing at the registered interval start regardless of the event payload — this is the app's core, shipped mechanism; the empty selection changes only what `setRestrictions()` writes, not whether the callback lands. No new assumption.

3. Whether re-registering `.daily` mid-interval fires `intervalDidStart` again (the recovery path in correctedMechanism) — I could NOT confirm this from Apple documentation. WebSearch surfaced only Apple Developer Forums threads on `intervalDidStart` reliability (e.g. developer.apple.com/forums/thread/727970, /thread/819224), nothing authoritative on start-while-inside-interval. The app's own `.hourly` quick-block depends on it (`performRestrictHour`, ContentView.swift:105-110, registers `intervalStart = now`), which is strong circumstantial evidence but not proof. This uncertainty affects only the size of the window (whole 8 hours vs. until the user re-adds apps), not the existence of the defect.

4. `@AppStorage` cross-process observation — not load-bearing here: `inside_interval` is read fresh from the app-group `UserDefaults` on every `get`, and the trace has the user cold-launching or foregrounding after the extension's write.

**Second opinion (**DISAGREES** with the first verifier)**

_Worst realistic outcome:_ For the rest of the window the app shows "Block active", locks the Stop button, the mode picker and the slider — while nothing on the phone is shielded. A user who trusts the banner is unprotected. It is recoverable at any point by re-selecting apps in the picker (one tap, and the app card is already showing the empty "Choose apps & websites" state), which re-registers .daily and does apply the shields; and it clears itself at window end. Nobody is locked out of any app, and no block that was legitimately locked gets bypassed.

The state is real and the code reads as claimed — I re-verified every anchor: ContentView.swift:60 (`guard model.isArmed, !isExpired, !model.isEmpty() else { return }`), :218-231 (selection handler: no disarm), :233-235 (disarmIfArmedInactive wired only to start/end/blockOutsideWindow), Model.swift:95-97 (all three shield facets nil on empty), DeviceActivityMonitorExtension.swift:52-64 (no emptiness check; only `guard enforcementAllowed`), AppCard.swift:68 (picker bound straight to $model.selectionToRestrict). So `is_armed = true` + `.daily` registered + empty saved selection + `inside_interval = true` + zero shields is reachable. Fix is one guard. That part I would defend.

But the first verifier's consequence analysis is wrong in three places, and their class is wrong.

1. "Adding apps back during that window does not help either" (candidate's mechanism, endorsed by the verifier as "no guard found") is FALSE — there is a working recovery path, and it is the most obvious tap in the UI. `openPicker()` (ContentView.swift:95-98) is gated only on `isExpired`, not on `insideInterval`, and AppCard's empty-state button (AppCard.swift:45-59) is not disabled while a block is active. Re-selecting apps mid-block hits `.onChange(of: model.selectionToRestrict)` (:218): `model.validateRestriction()` (Model.swift:74-81) returns TRUE here because the saved selection is empty (`empty == empty.intersection(new)` for all three token sets), so the removal guard does not fire → `saveSelection()` → `applySchedule()`, which now passes `!model.isEmpty()` and calls `Schedule.setSchedule(...)`. That does `center.stopMonitoring([.daily])` then `startMonitoring` (Schedule.swift:32-40) — stop-then-start is precisely the sequence developers report is required for `intervalDidStart` to be re-delivered, and a schedule whose previous start (09:00) is later than its previous end (yesterday 17:00) is treated by the system as ongoing, so `intervalDidStart` fires and the extension applies the new, non-empty selection. This app already depends on that same semantic for `.hourly` (`performRestrictHour`, ContentView.swift:105-110, registers intervalStart = the current hour:minute and expects immediate enforcement). So the "eight hours you cannot fix" framing is over-claimed; worst case the user has to notice the empty app card.

2. "Worst case it is also a bypass recipe" is vacuous. The mechanism requires the user to empty the selection *before* the window opens — the exact moment at which `primaryDisabled` is false and the CTA reads "Stop blocking" (ContentView.swift:37-46), i.e. when disarming is explicitly sanctioned by design. Deselecting all is a strictly worse route to a permission the user already has. No enforcement integrity is lost relative to the intended design; nothing that was locked becomes unlocked. Removal *during* an active block is still correctly refused (validateRestriction + revert + "Cannot remove apps from block" toast, :219-224).

3. "Lockout" is the wrong class. A lockout means the user is trapped in enforcement they cannot escape. Here enforcement is zero — every app on the phone opens normally. What is locked is only Unplug's own controls, which has no effect on the user's device usage; the residual harm is (a) a false "Block active" banner (StatusBanner.swift:33) and (b) the window/mode being uneditable until the interval ends. The correct class is silent non-enforcement / false-active state (the pass's F4.4 shape), not lockout.

Also a small correction to the verifier's own supporting detail: the "App selection was reset, please re-select apps" toast is not persistent across launches — ContentView.swift:249-253 sets `model.hasSelection = false` immediately after showing it, precisely so it surfaces once (status.md:7 records that fix). And it is a *recovery prompt*, telling the user exactly the action that repairs the state.

Where the severity is actually earned: the same missing guard also covers the case where the empty selection arrives with no user action at all — invalidated FamilyActivitySelection tokens decoding empty, which this repo confirms happens in the field (status.md:7, "`has_selection` persisted true while invalidated tokens decoded empty"; status.md:6 mentions the same symptom). In that variant the user is genuinely deceived: they armed a block, did nothing, and get "Block active" with nothing shielded. Same code path, same one-line fix, so I would not split it out — but the maintainer should know that the deceptive variant, not the deselect-all variant, is what makes this worth fixing.

Not in status.md as this mechanism (the two adjacent entries the verifier names are indeed different: the swallowed `startMonitoring` error at status.md:8, and the active-block removal guard).

**Proof path**

Not provable today. The entire decision — "a selection edit that empties the set while armed-inactive must disarm" — lives in SwiftUI view code (`ContentView.applySchedule()` / `disarmIfArmedInactive()` / the `.onChange` handlers at ContentView.swift:218-244), and the state it mutates lives in `Model`, which imports FamilyControls + ManagedSettings and touches a live `ManagedSettingsStore`. `UnplugCore` contains only pure math (`ScheduleMath`, `AccessControl`); nothing arm-related. SKTestSession is irrelevant (no StoreKit involved).

Extraction needed: a pure arm-state reducer in UnplugCore, e.g. `enum ArmEvent { case selectionChanged(isEmpty: Bool), windowEdited, startTapped, stopTapped }` and `ArmState.next(_ event:, isArmed: Bool, insideInterval: Bool) -> (isArmed: Bool, registerDaily: Bool, stopDaily: Bool)`, with ContentView reduced to calling it. Then the test asserts `next(.selectionChanged(isEmpty: true), isArmed: true, insideInterval: false) == (isArmed: false, registerDaily: false, stopDaily: true)` — i.e. emptying the selection while armed-inactive disarms and unregisters, symmetrically with the existing window-edit case which already returns disarm. A second pure assertion worth having, on the extension side: `shouldApplyRestrictions(selectionIsEmpty: true, enforcementAllowed: true) == false`, so `insideInterval` is never latched true for an empty enforced set.

---

### `V11` · App never observes the extension's inside_interval write, so lock-while-active UI does not engage in a foregrounded app

- **🔴 Important** · impact **lockout** · needs device · hit **common**
- **Feature** F4 · **Discovery IDs** F4-CONC-01, F4-XPROC-03 (2 agents found this independently)
- **Already in status.md:** Not recorded. The closest entries in status.md are two undocumented placeholders — "Notifications bug — needs investigation and documenting" and "Outstanding bug mentioned in README — needs documenting" (README.md:21) — neither of which names this mechanism. status.md's redesign follow-ups do list an adjacent unverified item: "confirm the 'schedule edit disarms while armed' behavior on device, or switch to a confirm-on-activate alternative", and "Verify the main-screen layout in block-active state on a real device". The `is_armed`/`inside_interval` cross-process observation gap itself is news.

**Verifier's reasoning**

Every cited line says what the claims say it says, and I found no guard that closes the gap.

Code truth:
- `ScreenTimeShield/Model.swift:25` — `@AppStorage("inside_interval", store: UserDefaults(suiteName: "group.screentimeshield")) var insideInterval: Bool = false` on `class Model: ObservableObject`. It is NOT `@Published` (contrast `selectionToRestrict`/`start`/`end` at `Model.swift:40-53`, which are).
- Only writer is the other process: `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:63` (`model.insideInterval = true` after `setRestrictions()`) and `:77` (`false` after `clearRestrictions()`). Note the extension's own computed `insideInterval` at `:30-38` is dead code — the writes go through `Model`'s AppStorage setter, same app-group key either way.
- No invalidation channel exists in the app process. `grep` over all Swift sources for `didChangeNotification|NotificationCenter|Timer|TimelineView|\.observe|objectWillChange` returns nothing for `Model`/UserDefaults — the only `objectWillChange.send()` calls are in `ScreenTimeShield/AccessController.swift` (:43, :159-204). `StatusBanner.swift:29-30` is an `onAppear`/`onChange` pair on a `@State isPulsing` (an animation), which cannot re-evaluate any body. So the only routine refresh is a background→foreground trip: `ScreenTimeShieldApp.swift:95-104` → `AccessController.refreshAccess()` (`AccessController.swift:92-97`) always assigns `@Published fcAuthorized`/`accessState` → ContentView (which holds `access` as `@StateObject`, `ContentView.swift:19`) re-renders.
- Structural confirmation that AppStorage cannot publish from a class: the iOS SDK `SwiftUI.swiftinterface` (line 7534-7545) declares `AppStorage` with only `wrappedValue`, `projectedValue`, an internal `UserDefaultLocation`, and `_makeProperty(in:container:fieldOffset:inputs:)`. There is no `static subscript(_enclosingInstance:...)` (the mechanism `@Published` uses to reach `objectWillChange`), and `_makeProperty` only runs when the wrapper is installed in a *View's* dynamic-property buffer. A wrapper held by a class is never installed, so it has no graph attribute to invalidate and no way to send `objectWillChange`.
- Consumers that therefore render the pre-boundary value: `StatusBanner.swift:26,33,41`; `ScheduleCard.swift:21` (`.disabled(model.insideInterval)` on the mode Picker), `:26-27` (`locked:`/`now:`), `:30` (lock caption); `ScheduleRangeSlider.swift:129` — verified: `.gesture(locked ? nil : DragGesture(...))`, so `locked == false` means the drag gesture literally exists; `AppCard.swift:27`; `ContentView.swift:32` (`isQuickRestrictDisabled`), `:37-48` (`primaryTitle`/`primaryDisabled`), passed as plain params into `PinnedActions` (`:198-205`, `PinnedActions.swift:11-16,35`); `onPrimary` early-returns at `ContentView.swift:51`.

Guards I searched for and did not find: no KVO/Darwin-notification bridge, no polling, no `insideInterval` re-derivation from `DeviceActivityCenter` (the `onAppear` sync at `ContentView.swift:248` re-derives `isArmed` only, and only on appear), no `scenePhase` handler in `ContentView`.

status.md does not record this (see alreadyKnown). Reachability is ordinary, not adversarial: a user who taps "Start blocking" for a window that begins minutes later, or who sits in the app waiting for a block to end.

**Correction to the original claim**

Three corrections, none of which change the verdict:

1. The two candidates contradict each other on the same-process half and F4-XPROC-03 is the wrong one. XPROC-03 says "@AppStorage declared in an ObservableObject *does* drive objectWillChange for same-process writes (confirmed)". That is not confirmed and looks false: the SDK's `SwiftUI.swiftinterface` (7534-7545) shows `AppStorage` has no `_enclosingInstance` subscript and only `_makeProperty` for invalidation, so a class-held wrapper has neither channel. F4-CONC-01's gap (b) is the better reading. This matters because it means the in-app writes to `notifications_enabled` (SettingsView.swift:19), `block_outside_window` (ScheduleCard.swift:16) and `is_armed` also publish nothing — so `.onChange(of: model.blockOutsideWindow)`/`.onChange(of: model.notificationsEnabled)` (ContentView.swift:235-244) only run when something else re-renders ContentView. Either way, the cross-process gap alone is sufficient for the reported failure, so the finding stands on the half both candidates agree on.

2. The staleness is not "for the whole foreground session" as XPROC-03 states. Any ContentView `@State` mutation (gear → `showSettings`, app-card tap → `isShowingRestrict`, `armRequest`, toast flags) or any `@Published` Model write re-evaluates the body and snaps the correct locked/unlocked state in. So the window is "until the next unrelated invalidation" (which F4-CONC-01 words correctly). It self-heals, silently and unpredictably — which is why the persisted-config divergence in step 6/7 outlives it.

3. The worst consequence is a composition, not the dead button: because `isQuickRestrictDisabled` (ContentView.swift:31-33) is also stale, "Restrict for next hour" stays tappable *during* an active daily block — precisely what that `model.insideInterval` term exists to prevent. Registering `.hourly` then means its `intervalDidEnd` wipes the shared unnamed `ManagedSettingsStore` and clears `inside_interval` an hour later, mid-daily-block (Extension:74-78) — i.e. this bug re-opens the F4-HOSTILE-01 bypass from inside a live block. I class the finding itself as lockout because that bypass needs the separate hourly/daily collision defect to land.

**Failure trace (re-derived from source by the verifier)**

Setup: apps selected, `is_armed = true`, `.daily` registered for 09:00–17:00, `inside_interval = false`.

1. 08:58 user opens Unplug and keeps it foregrounded. ContentView's last body pass captured `insideInterval == false`.
2. 09:00 the monitor extension process runs `intervalDidStart(.daily)` → `enforcementAllowed` passes → `loadSelection()` + `setRestrictions()` (shields live, restricted apps really are blocked) + `insideInterval = true` + `synchronize()` (Extension:56-63; Model.swift:92-98).
3. App process: nothing fires. `UserDefaults.didChangeNotification` is documented as not posted for out-of-process changes, and even if it were, the AppStorage wrapper lives on a class so it has no installed graph attribute and cannot send `objectWillChange` (SwiftUI.swiftinterface:7534-7545). ContentView/StatusBanner/ScheduleCard/AppCard bodies are not re-evaluated.
4. On screen: grey dot + "Block inactive" (StatusBanner:26,33), "Will be restricted" (AppCard:27), no lock caption, mode Picker enabled (ScheduleCard:21), slider handles still carrying live drag gestures (ScheduleRangeSlider:129), enabled "Stop blocking" (ContentView:39,46), enabled "Restrict for next hour" (ContentView:32).
5. User taps "Stop blocking" → `onPrimary()` re-reads the getter, gets fresh `true`, returns silently (ContentView:50-51). Enabled button, no effect, no feedback.
6. User taps the mode Picker → writes `block_outside_window` into the app group with no publish. Persisted config now says the block is the complement of the window (`Model.blockedInterval`, Model.swift:36-38) while the registered `.daily` and the running shields are still 09:00–17:00. Segmented control does not visibly move.
7. User drags a slider handle → `model.start` is `@Published`, so this one DOES persist (Model.swift:43-45) and DOES re-render ContentView; `.onChange(of: model.start)` → `disarmIfArmedInactive()` reads the now-fresh `insideInterval == true` and correctly refuses to `stop()`. Net: the schedule window was edited mid-block (the thing `locked:` exists to prevent) and the UI only *then* snaps into its locked presentation.

Mirror case (interval end), fully self-contained: user keeps the app open through 17:00. Extension runs `intervalDidEnd(.daily)` → `clearRestrictions()` + `inside_interval = false` (Extension:74-77); apps work again. The app still shows "Block active", the lock caption, a gestureless slider, a disabled mode Picker and a greyed, non-interactive "Blocking" CTA with a lock glyph (PinnedActions:22-35). Because every unlocked control depends on `insideInterval` and every path that would re-render depends on touching one of those controls, the user cannot re-arm or edit. It is escapable only incidentally — any ContentView `@State` change (tapping the gear → `showSettings = true`, or the still-enabled "Add" on the app card) or a background→foreground trip re-renders and fixes it.

**Apple API semantics checked**

1. `UserDefaults.didChangeNotification` cross-process: Apple's documentation states the notification "isn't posted when changes are made outside the current process" and explicitly points to KVO as the way to be notified "regardless of whether changes are made within or outside the current process". Confirms the claim's premise.
2. `@AppStorage`'s observation is didChangeNotification-based: corroborated by pointfreeco/swift-composable-architecture issue #3439 / discussion #3459, which diagnose exactly this failure for app-group AppStorage read in an extension and switched to KVO to fix it.
3. `@AppStorage` in a class cannot publish: checked the SDK source of truth rather than blogs — `/Applications/Xcode.app/.../iPhoneOS.sdk/.../SwiftUI.swiftmodule/arm64e-apple-ios.swiftinterface:7534-7545`. `AppStorage` exposes only `wrappedValue`, `projectedValue`, an internal `UserDefaultLocation<Value>`, and `_makeProperty(in:container:fieldOffset:inputs:)`; there is no enclosing-instance subscript. `UserDefaultLocation` (:7640-7653) has `get()`, `set(_:transaction:)`, `update() -> (Value, Bool)`, `wasRead` — all internal to the graph mechanism.
NOT settled (and it is the only thing that changes the outcome, exactly as both candidates flag): whether `UserDefaultLocation.get()` on an uninstalled wrapper reads through to the app-group defaults or serves a cached value. `get()` with no attached attribute reads the store, and app-group `UserDefaults` instances are invalidated by cfprefsd on external writes (the extension also calls `synchronize()`), so the fresh-read / dead-button outcome is the likely one. If it caches, `onPrimary()`/`disarmIfArmedInactive()` would instead see `false` during an active block and `stop()` would tear the live block down — a genuine bypass. A device check must resolve which.

**Second opinion (**DISAGREES** with the first verifier)**

_Worst realistic outcome:_ The app tells the user "Block inactive / Start blocking" while their block is actually live — most often immediately after they tap "Restrict for next hour", which never changes the screen at all. During that stale window the still-enabled "Restrict for next hour" lets them register an `.hourly` on top of a live `.daily`; when the hour ends, `intervalDidEnd("hourly")` runs `clearRestrictions()` (DeviceActivityMonitorExtension.swift:74-77) and nothing re-applies until the next day's 09:00 `intervalDidStart`, so the rest of that day's "unstoppable" block silently evaporates. If AppStorage caches reads (nobody has ruled this out), the worst case is worse: the enabled "Stop blocking" actually runs `stop()` mid-block — a straight bypass.

VERDICT STANDS — mechanism re-derived and every cited line checks out. Not in status.md (its only insideInterval-adjacent entries are the layout QA item at status.md:31 and the redesign follow-ups at :17). What they got wrong is the consequence framing.

CONFIRMED INDEPENDENTLY
- `Model.swift:25` — `@AppStorage("inside_interval", store: …)` on `class Model: ObservableObject`, not `@Published` (contrast `:39-53`).
- Only writer is the other process: `DeviceActivityMonitorExtension.swift:63` / `:77` (their note that the extension's own computed `insideInterval` at `:30-38` is dead code is right — the writes go through `Model`'s AppStorage setter).
- Zero invalidation channel. My grep for `scenePhase|Timer|TimelineView|didChangeNotification|NotificationCenter|objectWillChange|addObserver|onReceive|willEnterForeground|@AppStorage` returns nothing on `Model`; `RestrictedAppList.swift` and `TrialChip.swift` have no `onAppear`/`task`/`Date()`/animation at all.
- Their swiftinterface argument holds: iPhoneOS26.2 SDK `SwiftUI.swiftinterface:7534-7545` declares `AppStorage` with only `wrappedValue`, `projectedValue`, `location`, `_makeProperty(in:container:fieldOffset:inputs:)` — no `static subscript(_enclosingInstance:…)`, so a class-held wrapper cannot reach `objectWillChange`.

OVER-CLAIMED
1. "lockout" is the wrong class. The end-boundary stuck-locked state is escapable by any tap that mutates a ContentView `@State`: the gear is always present and never disabled (`ContentView.swift:156` → `showSettings`), and `AppCard`'s "Add" button (`AppCard.swift:37-38` → `onTap` → `isShowingRestrict`) is NOT gated on `insideInterval` — I checked the whole file. Plus every background→foreground trip (`ScreenTimeShieldApp.swift:95-101` → `refreshAccess()` → `AccessController.swift:94,96` unconditionally reassign `@Published fcAuthorized`/`accessState`, and `@Published` publishes even on an equal value). They concede this in their last line and then class it lockout anyway. Correct class: state-display divergence plus loss of the F4.5 edit-lock — not a lockout.
2. Trace step 6 "Segmented control does not visibly move… so the user taps it again and again" is almost certainly wrong. `ScheduleCard.swift:16-20` is `Picker(selection: $model.blockOutsideWindow).pickerStyle(.segmented)`; the UIKit-backed control moves its own selection on tap and the write succeeds, and nothing reverts it. The invented "taps it again and again" beat should go. The real residue of step 6 is smaller than they imply: `block_outside_window` is persisted flipped while the registered `.daily` keeps the old interval, so the *next* day enforces a window the UI no longer shows — mild, and `disarmIfArmedInactive()` (`ContentView.swift:90`) would have been a no-op regardless.
3. Trace step 7 understates the self-correction. Because `model.start` IS `@Published`, the first effective drag change re-renders and locks everything, so the mid-block schedule edit is bounded to a single drag batch and no `stop()` occurs (`:90` reads fresh `true`). The "hole" in `locked:` is real but small.
4. They assert as fact that the tap-time read is fresh ("`onPrimary()` re-reads the getter, gets fresh `true`"). They did not verify that. The swiftinterface only rules out *publishing*; `UserDefaultLocation` (`SwiftUI.swiftinterface:7640-7653`) exposes `wasRead` and `update() -> (Value, Bool)` alongside `get()`, and nothing there proves `get()` reads through to cfprefsd rather than a cache. Both source candidates flagged this fork explicitly as the severity-determining unknown; the first verifier silently resolved it in the direction that LOWERS severity. If reads are cached, `onPrimary` (`ContentView.swift:50-51`) falls through to `stop()` → `stopMonitoring([.daily, .notificationSchedule])` + `clearRestrictions()` — a real bypass. Settled by one device check: foreground across an interval start, tap the primary CTA, see whether shields survive.

MISSED / UNDERSTATED
5. They missed the highest-frequency trigger entirely. `performRestrictHour()` (`ContentView.swift:105-109`) registers `.hourly` starting *now* and sets neither `isArmed` nor `insideInterval`. The user has literally just tapped a button, so they are certainly foregrounded when `intervalDidStart("hourly")` fires — meaning EVERY quick-restrict tap leaves the screen reading "Block inactive"/"Start blocking" with an unlocked slider for the rest of the session, with zero acknowledgement of the action. Their framing ("a user who taps Start blocking for a window that begins minutes later, or who sits in the app waiting for a block to end") makes this sound like a timing coincidence; it is the app's own most-immediate action. That is why I put frequency at common, not occasional.
6. They missed that the stale-unlocked state re-opens `isQuickRestrictDisabled` (`ContentView.swift:31-32`, which is gated on `model.insideInterval` precisely to stop stacking during an active block). Registering `.hourly` mid-`.daily` is safe at the start (`Schedule.swift:29-36` stops only `[activityName]`, so `.daily` is untouched — good, and worth stating explicitly since it is the guard that prevents an immediate bypass), but the `.hourly` END clears the shared shields mid-`.daily`-block. In fairness that escape is also reachable without this bug (tap quick-restrict a few minutes before the daily window opens), so it is a separate defect — but it means "the stale UI is merely cosmetic" is false.

Minor citation drift in their write-up, not load-bearing: the gear is `ContentView.swift:156` not 141-149; the extension does NOT `synchronize()` on the `insideInterval` write (the AppStorage setter doesn't, and `Model.swift:92-98` is `setRestrictions`, not a synchronize).

**Proof path**

Not provable today. `UnplugCore` contains only `ScheduleMath` and `AccessControl` (pure); `Model` lives in the app target and imports SwiftUI/FamilyControls, and the defect is the absence of a SwiftUI invalidation edge — not a value computation — so `SKTestSession` is irrelevant and no assertion over existing pure code can reach it.

What would make it testable: move the flag out of `@AppStorage` into a small observable store in `UnplugCore`, e.g. `BlockStateStore` wrapping the app-group `UserDefaults` with KVO (`observe(forKeyPath: "inside_interval", options: [.new])`) and exposing a publisher/`@Published var insideInterval`, with `Model` forwarding it to `objectWillChange`. Then a pure test can assert: (a) an external write performed through a *second* `UserDefaults(suiteName:)` handle delivers a KVO callback and emits on the publisher (this is the regression the current code fails), and (b) `insideInterval` reads through to the store rather than a cached value. Two further assertions become unit-testable once the gating predicates are lifted out of the view: `isQuickRestrictDisabled` and `primaryDisabled`/`primaryTitle` as pure functions of `(fcAuthorized, insideInterval, isArmed, isExpired, hasApps)`.

Device check that settles the rest: keep the app foregrounded across an interval start and an interval end and observe (1) whether the banner/slider/Picker/CTA change state at all, (2) what "Stop blocking" does when tapped during the stale window — silent no-op (fresh read) vs. actually stopping the block (cached read).

---

### `V15` · No Transaction.updates listener: out-of-band transactions never observed, never finished

- **🔴 Important** · impact **lockout** · unit-testable now · hit **rare — requires an out-of-band transaction (Ask to Buy approval, same-Apple-ID purchase on a second device, an externally-completed interrupted purchase) to land while this app is in an uninterrupted foreground session. Offer-code redemption and interrupted-purchase-on-relaunch both self-heal via the existing scenePhase/.task refreshes, so they do not hit it. Not an ordinary-evening bug for an ordinary paying user.**
- **Feature** F9 · **Discovery IDs** F9-SK-01
- **Already in status.md:** Not in status.md as a bug. The nearest entries are status.md:2 (IAP created in ASC, local StoreKit config wired) and status.md:30 ("Manual QA the trial -> paywall -> purchase flow"), which is an untaken QA task, not a record of this mechanism. qa/invariants.md:68 states invariant F9.7 and cites Store.swift:42 as its evidence, i.e. the invariant was believed satisfied.

**Verifier's reasoning**

The code truth holds at every cited line. `ScreenTimeShield/Store.swift:12-82` — the class has no `init`, and a repo-wide grep for `Transaction.updates` / `Transaction.unfinished` / any `updateListener` returns zero hits; the only `finish()` in the entire repo is `ScreenTimeShield/Store.swift:41`, inside the `.success(.verified)` arm of the foreground buy path (guarded at `Store.swift:40`), and `.pending` falls into `case .userCancelled, .pending: return false` at `Store.swift:44-45`. I actively searched for a mitigation and found none: the only entitlement-recovery paths are `AccessController.refreshAccess()` (`ScreenTimeShield/AccessController.swift:93-99`, which calls `storeKit.refreshPurchasedState()` — a `currentEntitlements` re-query that never finishes anything), reachable only from `ScreenTimeShield/ScreenTimeShieldApp.swift:101-102` (scenePhase `.active`) and `ScreenTimeShield/ContentView.swift:256-262` (`.task` at launch). `PaywallView`'s own `.task` (`ScreenTimeShield/PaywallView.swift:117-119`) calls `loadProduct()` only — no refresh, no timer, no `willEnterForegroundNotification` observer anywhere in the target. `PaywallView.swift:120-122` does auto-dismiss on `accessState == .fullAccess`, but nothing ever moves `accessState` while the paywall is up and the app stays foregrounded, so that guard cannot fire. `AccessController.swift:118` writes `enforcement_allowed = accessState != .expired`, so an expired-trial user whose out-of-band purchase has not yet been re-queried still has the extensions gated off. The repo's own `ScreenTimeShieldTests/StoreTests.swift:68-74` is exactly as described (out-of-band `session.buyProduct` + explicit `refreshPurchasedState()`, no finish) and incidentally proves the recovery half of the mechanism. This is not recorded in status.md; invariant F9.7 (qa/invariants.md:68) is the invariant violated, and its own citation `Store.swift:42` is one line stale (finish is at :41) — the candidate cites :41 correctly.

**Correction to the original claim**

The listener absence and the permanent-unfinished state are real, but two consequence claims should be narrowed. (1) "Never observed" is only true *live*: `Transaction.currentEntitlements` includes unfinished transactions (StoreTests.swift:68-74 asserts exactly that for a transaction created out-of-band and never finished), so the entitlement IS recovered on the next `.active` scenePhase or next cold launch — the user-visible defect is a delay plus zero feedback, not permanent denial of a paid entitlement. (2) The permanent-unfinished part has no independent user-visible symptom for a non-consumable that is already in `currentEntitlements`: Apple re-emits it on `Transaction.updates` at each launch to a listener that does not exist, so the harm is the F9.7 invariant violation and "content never marked delivered", not a repeated charge or repeated prompt. Also worth splitting: the "no message on .pending" half of the trace is F9-SK-02's defect (`Store.swift:44` collapsing `.pending` into `false`); F9-SK-01's unique content is the missing `Transaction.updates` Task, which additionally means an offer-code redemption or another-device purchase is invisible until the next foreground refresh.

**Failure trace (re-derived from source by the verifier)**

Trial expired (`AccessController.recomputeAccessState`, AccessController.swift:112-118, has written `enforcement_allowed = false`). Child device, Ask to Buy on. User taps "Unlock forever" -> PaywallView.buy() (PaywallView.swift:132-142) -> AccessController.purchase() (AccessController.swift:101-105) -> Store.purchase() (Store.swift:33-49) -> `product.purchase()` returns `.pending` -> Store.swift:44-45 returns false -> `recomputeAccessState()` re-runs with `hasFullAccess == false`, so `accessState` stays `.expired` and `enforcement_allowed` stays false -> back in buy(), `ok == false` so no `dismiss()`, and `errorMessage` is untouched (only the `catch` at PaywallView.swift:139-141 assigns it) -> `purchasing` flips false via the `defer`; the paywall is pixel-identical to before the tap. Parent approves 90 s later while the child is still on the paywall in the foreground. StoreKit emits the approved transaction on `Transaction.updates`; no Task in this target iterates it (zero grep hits), so nothing runs: `isPurchased` stays false, `accessState` stays `.expired`, `PaywallView.swift:120-122`'s auto-dismiss never fires, `enforcement_allowed` stays false in the app group, and the extensions keep enforcement gated. The user sees no change. Only when they background and re-foreground (ScreenTimeShieldApp.swift:101-102 -> refreshAccess -> refreshPurchasedState, Store.swift:58-67) does `currentEntitlements` yield the verified transaction, `isPurchased` become true, `accessState` become `.fullAccess`, and the paywall dismiss. At no point on any path does `finish()` run for that transaction (Store.swift:41 is only reachable from `product.purchase()` returning `.success(.verified)`), so it remains in `Transaction.unfinished` for the life of the install and is re-emitted on `Transaction.updates` at every launch to nobody.

**Apple API semantics checked**

Apple docs (confirmed via search of developer.apple.com content; the doc pages themselves would not render through WebFetch): `Transaction.updates` "receives transactions that occur outside of the app, such as Ask to Buy transactions, offer code redemptions, and purchases customers make in the App Store", and "if your app has unfinished transactions, the listener receives them immediately after the app launches. Without the Task to listen for these transactions, your app may miss them" — unfinished transactions re-deliver on every launch until `transaction.finish()`. `Product.PurchaseResult.pending` delivers the eventual transaction through the transaction updates, i.e. via `Transaction.updates`, which is the exact channel this app does not listen on. `Transaction.currentEntitlements` includes the latest transaction for each entitled non-consumable regardless of finish state — corroborated in-repo by ScreenTimeShieldTests/StoreTests.swift:68-74, where a `session.buyProduct` transaction that is never finished is nonetheless found by `refreshPurchasedState()`. I could not find an Apple statement that a permanently unfinished *non-consumable* produces any additional user-visible symptom, so I do not credit any beyond re-emission plus "content not marked delivered".

**Second opinion (**DISAGREES** with the first verifier)**

_Worst realistic outcome:_ A user who has genuinely paid sees no acknowledgement: the paywall stays up unchanged, and if they dismiss it with the X (PaywallView.swift:36-43) and tap Start blocking, ContentView.swift:71/101 re-presents the paywall because accessState is still .expired — so they can be looped through the paywall while already entitled, and enforcement_allowed stays false (AccessController.swift:118) so no block is applied. It self-heals at the next transition into scenePhase .active, the next cold launch, or a Restore Purchase tap, so the realistic exposure is seconds to a few minutes of "I paid and it says my trial is over", plus the risk that the user re-taps buy in the meantime. No permanent loss of paid access on any path.

Verdict agrees (mechanism is real: no `Transaction.updates` listener anywhere — `Store.swift` has no `init`, zero grep hits for `Transaction.updates`/`Transaction.unfinished`/`updateListener`, and the sole `.finish()` is `Store.swift:41` behind the `.verified` guard at `:40`; not in status.md; F9.6 and F9.7 both genuinely violated). But I disagree with their consequence analysis on three counts.

(1) FACTUALLY WRONG CLAIM: they assert "nothing ever moves `accessState` while the paywall is up and the app stays foregrounded, so that guard cannot fire." `PaywallView.swift:104-111` is a Restore Purchase button → `restore()` at `:144-153` → `AccessController.restore()` at `AccessController.swift:107-110` → `storeKit.restore()` (`Store.swift:52-55`: `AppStore.sync()` + `refreshPurchasedState()`) → `recomputeAccessState()`. That sets `accessState = .fullAccess` and re-enables `enforcement_allowed` (`AccessController.swift:118`) with the app foregrounded and the paywall up, and `PaywallView.swift:120-122` then dismisses. An in-foreground, in-UI recovery path exists — and it is the exact button Apple requires apps to expose for this situation.

(2) UNDERSTATED RECOVERY: "only when they background and re-foreground" is wrong about `ScreenTimeShieldApp.swift:95-103`. `onChange(of: scenePhase)` fires on any change *to* `.active`, so `.active → .inactive → .active` (Control Center, a notification pull, an app-switcher peek, lock/unlock) triggers `refreshAccess()` without a real background trip. `ContentView.swift:256-262` also recovers on every cold launch. The stuck window is "an uninterrupted foreground stare at the paywall", not "until the user thinks to background the app".

(3) WRONG IMPACT CLASS: "lockout" is not supportable. Apple's `Transaction.currentEntitlements` docs state the sequence emits "A transaction for each non-consumable In-App Purchase" — finish state is irrelevant to entitlement, so the never-finished transaction causes no access loss whatsoever; the first `refreshPurchasedState()` after approval grants access permanently. And `Transaction.finish()` docs describe only content-delivery acknowledgement; the documented cost of never finishing is re-emission on `updates`/`unfinished`, i.e. to a listener that does not exist here. So the never-finish half is a real F9.7 spec violation with no user-visible consequence I could establish for a non-consumable — hygiene, not harm. The correct class is "paid-purchase acknowledgement delay / F9.6 violation", not lockout. The genuinely permanent-denial scenario (`.success(.unverified)` charged-but-never-granted, `Store.swift:40` + `:61`) belongs to F9-SK-02, and the verifier partly borrowed SK-02's consequence ("paywall pixel-identical, no message", which is the `.pending`→`false` feedback gap) to inflate this one. V15's unique, non-overlapping content is only the missing `updates` listener.

Verified against Apple docs (developer.apple.com JSON API): `Transaction.updates` does emit Ask-to-Buy/offer-code/other-device transactions and delivers unfinished ones once immediately after launch ("Without the Task to listen for these transactions, your app may miss them"); `PurchaseResult.pending` — "If a pending purchase succeeds, StoreKit delivers the resulting Transaction in the transaction updates". So the mechanism's premise holds. Fix is still worth doing (a `Transaction.updates` task in `Store.init` that finishes and refreshes), but it should be filed as a purchase-recognition/UX + StoreKit-hygiene bug, not as a lockout.

**Proof path**

`Store` (ScreenTimeShield/Store.swift) is a plain @MainActor ObservableObject, not a view, so SKTestSession in ScreenTimeShieldTests can prove both halves today, alongside the existing StoreTests.swift. (a) No live observation: `try await session.buyProduct(productIdentifier: Store.lifetimeProductID)`, construct `Store()`, wait/yield without calling `refreshPurchasedState()`, assert `store.isPurchased == true` — fails today, passes once a `Transaction.updates` Task exists in `init`. (b) Never finished: after `session.setAskToBuyEnabled(true)` (or plain `buyProduct`) plus `await store.refreshPurchasedState()`, assert `await Array(Transaction.unfinished) .isEmpty` (or that no unfinished transaction has `productID == Store.lifetimeProductID`) — fails today. The Ask-to-Buy path specifically: `session.askToBuyEnabled = true`, call `store.purchase()` (returns false), then `try session.approveAskToBuyTransaction(identifier:)`, then assert `store.isPurchased` without any manual refresh. Note these live in the app test target and inherit StoreTests' `requireStoreKitTestEnvironment()` skip guard, and the "paywall shows no message / does not dismiss" half is view-level and would need a ViewInspector-style or manual check.

---

### `V18` · Grandfathered access is unpersisted derived state: one failed AppTransaction fetch demotes a legacy user to expired

- **🔴 Important** · impact **lockout** · unit-testable now · hit **occasional**
- **Feature** F9 · **Discovery IDs** F9-SK-04, F9-DATE-01, F9-INTEG-03 (3 agents found this independently)
- **Already in status.md:** Not recorded. The closest entries in status.md are generic: line 3 "[ ] P1: Triage remaning todos, grandfather logic and anything critical" (an untriaged catch-all, no mechanism), line 27 "[~] Revisit the grandfathering logic" (about switching from `cutoverBuild`/`originalAppVersion` to `cutoverDate` vs `originalPurchaseDate` — a different defect, already fixed), line 28 (the cutover-date constant), and line 39 "[ ] Manual QA the trial → paywall → purchase flow". Nothing in status.md mentions the unpersisted entitlement verdict, the fail-closed catch/`.unverified` handling, or `trial_start` being stamped for full-access users. Related-but-distinct known item: line 34's claim that the QA scaffolding is "inert/unreachable in production", which candidate F9-INTEG-04 disputes on a different mechanism (`qa_force_full_access` persistence).

**Verifier's reasoning**

Every cited line says what the three write-ups claim, and I found no guard anywhere that prevents the demotion.

Code truth, verified line by line:
- `ScreenTimeShield/Store.swift:17` — `@Published private(set) var isGrandfathered = false`. `grep -rn "isGrandfathered" --include="*.swift"` returns only Store.swift:17/20/74, AccessControl.swift:74, and tests. There is no app-group key for it (`ScreenTimeShield/AppGroupStore.swift:12-20` holds only `trial_start`, `times_stopped`, `last_stop_logged`, `enforcement_allowed`, `qa_force_full_access`). So the verdict is genuinely process-local and `false` at every cold launch.
- `ScreenTimeShield/Store.swift:70-81` — the only writer. `guard case .verified(let appTransaction) = result else { return }` (:73) and `catch { print(...) }` (:77-80). The comment "leave prior value untouched" (:78) is accurate within a process and false across a launch, exactly as claimed.
- `ScreenTimeShield/AccessController.swift:84-90` — `startTrialIfNeeded()` has no `hasFullAccess`/`accessState` check, so it stamps `trial_start` for grandfathered and purchased users. Reachable from `ContentView.swift:61`, `:77`, `:106`.
- `ScreenTimeShield/AccessController.swift:93-99` → `recomputeAccessState()` (:112-120): both refreshes then one recompute, so a thrown/unverified AppTransaction yields `hasFullAccess == false` (`:69`, `Store.swift:20`) → `AccessEvaluator.accessState` returns `.expired` for an 8-day-old `trial_start` (`UnplugCore/Sources/UnplugCore/AccessControl.swift:55-57`) → `kv.setBool(false, forKey: "enforcement_allowed")` (`AccessController.swift:118`).
- `AccessController.swift:118` is the ONLY writer of that key (verified by grep). Nothing else can restore it, so the `false` persists in `group.screentimeshield` until the next *successful* foreground refresh.
- `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:42-44` reads it and `:56-59` returns before `setRestrictions()`. The default-true fallback at `:43` only helps when the key is *absent*, not when it is explicitly `false`.

Refutation attempts that failed:
- No `#if DEBUG`, no retry, no `AppTransaction.refresh()` anywhere (grep: zero hits).
- `applySchedule()`'s `!isExpired` guard (`ContentView.swift:60`) blocks re-registration, not the already-registered `.daily`, and does not affect the gate write.
- `refreshAccess()` is reliably invoked on cold launch (`ContentView.swift:256-262`) and every foreground (`ScreenTimeShieldApp.swift:101-102`), so the recompute is not skipped in production (the two skips are `XCTestConfigurationFilePath` and `UNPLUG_SKIP_FC`, neither present in a shipped build).
- `accessState` defaults to `.trial` (`AccessController.swift:30`), so there is no pre-refresh window that writes a false gate — the demotion strictly needs the AppTransaction fetch to fail, which is the only API-dependent link, and that link holds (see apiSemanticsChecked).

status.md contains no record of this mechanism.

**Correction to the original claim**

Three corrections, none of which weaken the finding:

1. WRONG PRIMARY TRIGGER. All three write-ups lead with "offline / Airplane Mode cold launch". That is the weakest trigger: Apple's own guidance is that you should "always check the AppTransaction.shared property, and rely on StoreKit to always provide the most up to date version available, INCLUDING PROVIDING A CACHED VALUE IF THERE IS NO NETWORK ACCESS". So a device that has a cached app transaction plausibly survives Airplane Mode, and a QA attempt that only tests Airplane Mode may fail to reproduce and get the bug wrongly closed. The reliably reachable triggers are: (a) the `.unverified` result at Store.swift:73 — no network failure required, and Apple staff explicitly warn to "account for false positives — legitimate users may be reported as unverified" (developer.apple.com/forums/thread/773604); (b) App Store server errors (developers report iOS 17 401/"Invalid Status Code" throws and a macOS 15.4 regression turning valid transactions unverified, threads 738772 / 780767); (c) the first launch after a download/update where no app transaction is cached yet; (d) the user dismissing the Apple-ID sign-in prompt that the call presents — the repo's own comments at ContentView.swift:257-258 and ScreenTimeShieldApp.swift:97-99 record the author observing that prompt.

2. THE PRECONDITION IS NEAR-UNIVERSAL FOR THE UPGRADE COHORT, NOT OPT-IN. All three traces require the grandfathered user to tap "Start blocking" to get stamped with `trial_start`. That understates it: no tap is needed. `ContentView.onAppear` calls `model.loadSelection()` (ContentView.swift:246), which mutates `model.selectionToRestrict` from empty to the saved value, firing `.onChange(of: model.selectionToRestrict)` (:218) → `applySchedule()` (:228) → `access.startTrialIfNeeded()` (:61). onAppear also sets `model.isArmed = DeviceActivityCenter().activities.contains(.daily)` (:248), which is true for anyone already using the pre-IAP build. So every previously-armed grandfathered user gets a 7-day clock stamped on the very first launch of 1.3 with zero user intent, and is a ticking bomb from day 8 onward.

3. RECOVERY / BLAST RADIUS PRECISION. F9-DATE-01's "no user action can recover it except relaunching while online" is right about the app UI (the next successful `refreshAccess()` on any foreground restores `.fullAccess` and rewrites the gate to true), but the persisted `false` means any block window that starts before that next successful foreground is permanently unenforced. Note also that a currently-ACTIVE block is not broken by the demotion (nothing calls `clearRestrictions()` on expiry), so this is not an escape from a live shield — it is a failure of future `intervalDidStart` calls to arm one.

Finally, F9-SK-04's own ruled-out section is correct that `isPurchased` (Store.swift:66) has the same fail-to-false shape but is materially safer: `Transaction.currentEntitlements` is an `AsyncSequence` with no error channel served from locally signed transactions. Grandfathering is the single-point-of-failure branch because there is no on-device entitlement to fall back on.

**Failure trace (re-derived from source by the verifier)**

Pre-cutover user (first downloaded 2026-03, paid $0.99) with a 22:00–07:00 daily block already armed on the shipping pre-IAP build.

1. They auto-update to the IAP build. First launch: `ContentView.onAppear` → `model.loadSelection()` (ContentView.swift:246) mutates `selectionToRestrict` empty→saved; `model.isArmed = DeviceActivityCenter().activities.contains(.daily)` = true (:248). The selection mutation fires `.onChange` (:218) → `applySchedule()` (:228): `model.isArmed` true, `isExpired` false (accessState still the `.trial` default at AccessController.swift:30), `!model.isEmpty()` true → `access.startTrialIfNeeded()` (:61) → `trialStartDate == nil` → `kv.setDate(now, forKey: "trial_start")` (AccessController.swift:85-86) → `recomputeAccessState()` with hasFullAccess still false but trial_start = now → `.trial`, `enforcement_allowed = true`.
2. Moments later `.task` (:256-262) → `refreshAccess()` → `AppTransaction.shared` verifies → `Grandfather.isGrandfathered(2026-03 < 2026-06-25)` = true (Store.swift:74-76) → `isGrandfathered = true` → `recomputeAccessState()` → `.fullAccess`, gate stays true. No TrialChip (ContentView.swift:186). Everything looks correct — and `trial_start` is now a live 7-day fuse in the app group.
3. Day 9. They foreground the app. `ScreenTimeShieldApp.swift:101-102` → `refreshAccess()`. `refreshPurchasedState()` finds no `com.halfspud.ScreenTimeShield.lifetime` entitlement (they never bought the IAP) → `isPurchased = false` (Store.swift:66). `refreshGrandfatheredState()` either throws (App Store 5xx/401, uncached transaction, dismissed Apple-ID prompt) → catch at Store.swift:77-80, or returns `.unverified` → bare `return` at Store.swift:73. Either way `isGrandfathered` is still its fresh-process `false`.
4. `recomputeAccessState()` (AccessController.swift:112-120): `hasFullAccess` false; `accessState(now: day9, trialStart: day1, hasFullAccess: false, trialLength: 7d)` → `now - trialStart >= 7d` → `.expired` (AccessControl.swift:57). Persisted: `enforcement_allowed = false` (AccessController.swift:118). Also registers the daily "Your blocks are off" notification at their block-start time (:126-143).
5. UI immediately: `TrialChip` appears reading "Trial ended · Unlock Unplug" (ContentView.swift:186-188); `openPicker()` silently no-ops (`guard !isExpired`, :96); `isQuickRestrictDisabled` true (:32); but `primaryTitle` is "Stop blocking" and `primaryDisabled` false because `model.isArmed` is still true (:39, :46) — the screen simultaneously claims a block is set up and that the trial ended.
6. 22:00 that night. The still-registered `.daily` schedule fires; the system launches CustomDeviceActivityMonitor; `intervalDidStart(for: .daily)` reads `enforcement_allowed` = false (DeviceActivityMonitorExtension.swift:43) and returns at :56-59. `setRestrictions()` is never called, `inside_interval` stays false. Instagram/TikTok open unshielded all night; `StatusBanner` reads "Block inactive".
7. Recovery is only on the next foreground where the AppTransaction fetch succeeds. Every block window between the failure and that foreground is silently lost.

**Apple API semantics checked**

1. `AppTransaction.shared` signature — read directly from the installed SDK, `/Applications/Xcode.app/.../iPhoneOS.sdk/System/Library/Frameworks/StoreKit.framework/Modules/StoreKit.swiftmodule/arm64e-apple-ios.swiftinterface:1000`: `public static var shared: StoreKit.VerificationResult<StoreKit.AppTransaction> { get async throws }`. So the `catch` branch at Store.swift:77 is a real, declared failure path, and `.unverified` is a real case of the returned `VerificationResult`. Same file confirms `public let originalPurchaseDate: Foundation.Date` (non-optional), so the `nil` branch of `Grandfather.isGrandfathered` (AccessControl.swift:75) is unreachable from this call site — the failure mode is the throw/unverified, as F9-DATE-01 correctly states.

2. Is the failure branch reachable in production, not just on simulators? DECISIVE EVIDENCE FROM APPLE'S OWN TEST FRAMEWORK: `StoreKitTest.framework/Modules/StoreKitTest.swiftmodule/arm64-apple-ios.swiftinterface` declares `SKTestFailures.AppTransaction { case generic(StoreKit.StoreKitError) }` (:80-88), `StoreKitAppTransactionAPI: FailableStoreKitAPI` (:151-152), the `.appTransaction` accessor (:209-210) and `SKTestSession.setSimulatedError(_:forAPI:)` (:240). Apple ships a first-class error-injection API for exactly this call, i.e. treats an AppTransaction failure as a production case developers must handle. Corroborated by Apple staff on developer.apple.com/forums/thread/773604 on the `.unverified` case: handle it by alerting the user, "account for false positives — legitimate users may be reported as unverified", and "be very cautious about blocking users based on any of this stuff." That is essentially Apple warning against exactly what Store.swift:73 does. Real-world throws/unverified regressions also reported in threads 738772 and 780767.

3. COUNTER-EVIDENCE I DELIBERATELY WENT LOOKING FOR, and which corrects the claims: Apple's guidance is to "rely on StoreKit to always provide the most up to date version available, including providing a cached value if there is no network access." I could NOT confirm that a device with a cached app transaction throws in Airplane Mode. I could not fetch the rendered `AppTransaction.shared` doc page (Apple's docs are JS-rendered; WebFetch returned title only), so the exact sentence the three candidates quote ("throws ... if the user isn't authenticated with the App Store ... may require network connectivity") is unverified by me. This does not refute the finding — the `.unverified` branch and server-error throws need no network story at all — but it does move the primary reproduction path off "offline".

4. `Transaction.currentEntitlements` — an `AsyncSequence` with no throwing/error channel, served from locally signed transactions, so I could NOT evidence a transient-empty result for a genuine IAP purchaser. This is why the grandfathered branch, not the purchased branch, is the single point of failure.

**Second opinion (agrees)**

_Worst realistic outcome:_ A pre-cutover paying customer launches Unplug, is told "Trial ended · Unlock Unplug", taps Restore Purchase and is told "No previous purchase found.", can no longer edit their app selection, and that night's 22:00 block does not apply any shields — with the paywall and the enforcement gap persisting on every subsequent night until a launch in which AppTransaction verifies (indefinitely, if the cause is a signed-out App Store account or a persistent StoreKit/ASD error).

I agree with the verdict and the severity; every line they cite reads as claimed and I found no guard. Four corrections/additions, two of which make the consequence worse than they stated and one of which trims their framing.

MISSED — the in-app recovery affordance is a dead end for exactly this cohort. `AccessController.restore()` (ScreenTimeShield/AccessController.swift:107-110) calls `storeKit.restore()` (ScreenTimeShield/Store.swift:52-55 → `AppStore.sync()` + `refreshPurchasedState()`) and then `recomputeAccessState()`. It never calls `refreshGrandfatheredState`. So a demoted grandfathered user who does the one thing the UI invites them to do gets `hasFullAccess == false` and `PaywallView.restore()` sets `errorMessage = "No previous purchase found."` (ScreenTimeShield/PaywallView.swift:145-152). The app affirmatively tells a customer who paid $0.99 that they have no purchase, which makes "pay again / demand a refund / 1-star" the most likely resolution rather than "relaunch later". The first verifier's step 7 ("recovery is only on the next foreground where the fetch succeeds") is right but understates this: the visible recovery button cannot recover grandfathering even with a perfect connection.

UNDERSTATED — recovery does not save the window it happens in. They wrote "every block window between the failure and that foreground is silently lost". It is worse: even the window during which the successful refresh happens is lost in full. `setRestrictions()` has exactly two callers (grep: CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:62 and nothing in the app), so once `intervalDidStart` has returned at :56-59 nothing re-applies shields for that occurrence — `recomputeAccessState()` (AccessController.swift:112-120) only publishes state and writes the gate. Same shape as F9-DATE-04.

MISSED — a second-order durable loss. While demoted, `primaryDisabled` is false and `primaryTitle` is "Stop blocking" (ContentView.swift:37-48) because `model.isArmed` is still true. A confused user tapping it runs `stop()` (:82-86), which unregisters `.daily`. After access is restored they must notice and re-arm manually; nothing re-registers on `accessState` change. So a false verdict can induce the user to destroy their own schedule.

OVER-CLAIMED (their inherited framing, not their own words) — this is not an active-block bypass. The parent candidate F9-SK-04 calls it "a direct hit on the 'cannot be bypassed' promise (deliberately going offline is a bypass)". `recomputeAccessState()` never calls `clearRestrictions()` (grep: only ContentView.swift:85, AccessController.swift:189, extension :76), so a block that has already started stays shielded through the demotion — a user cannot escape a live block this way. Nor does it give a determined user anything new: `stop()` is already enabled for an armed-but-inactive block by design. The correct framing is "a future scheduled window silently does not happen", not "an active block can be broken".

FREQUENCY — occasional, not common, and the airplane-mode variant in both write-ups is the weakest trigger. Apple's docs for `AppTransaction.shared` (fetched via developer.apple.com/tutorials/data/documentation/storekit/apptransaction/shared.json) say "StoreKit automatically keeps the app transaction up-to-date", and forum guidance is that StoreKit serves a cached value when there is no network. So a warm-cache offline launch probably does NOT throw. The realistic triggers are: signed out of / re-auth-pending on the App Store account (the docs' explicit throw case), first launch after a device restore or reinstall where app-group `trial_start` survived but the StoreKit cache did not, an `.unverified` result hitting the bare `return` at Store.swift:73, and the production `ASDErrorDomain` failures developers report as "ramping up" (developer.apple.com/forums/thread/780767 — mostly macOS 15.4, some iOS). The exposed population is large (per F9-DATE-05 the cutover has already passed, so the grandfathered cohort is the whole existing paid install base) but the per-user trigger rate is low. No user intent is required, so this is not adversarial-only; it just is not an ordinary evening.

Two small confirmations of their work: the demotion prerequisite really is satisfied without any user action for an already-armed pre-cutover user — `loadSelection()` (Model.swift:59-64) mutates `selectionToRestrict` empty→saved during `onAppear`, which fires `.onChange` (ContentView.swift:218-229) → `applySchedule()` → `startTrialIfNeeded()`; and the "Your blocks are off" notification does fire (notification auth is requested at ScreenTimeShieldApp.swift:30, and `kv.date(forKey: "start")` is persisted by Model.swift:43-45), so the failure is not literally silent — the user is just told the wrong reason. status.md has no record of this mechanism; the only adjacent entry is the vague P1 at status.md:3 ("Triage remaining todos, grandfather logic and anything critical"), which is not this bug.

**Proof path**

Provable TODAY in the ScreenTimeShield app test target (simulator, no device), because the logic lives in `Store`/`AccessController`, not in a SwiftUI view — and because Apple ships error injection for this exact API.

Test (async, @MainActor, host app, `StoreKit.storekit` config attached, `UNPLUG_SKIP_FC=1` in the test scheme so `AccessController.init` never touches `AuthorizationCenter` — the `skipFC ||` at AccessController.swift:36 short-circuits):

1. Seed `UserDefaults(suiteName: "group.screentimeshield")`: `trial_start` = `Date(timeIntervalSinceNow: -8*86400)`, `enforcement_allowed` = true, `qa_force_full_access` = false.
2. Baseline: with an SKTestSession whose app transaction predates `PricingConfig.cutoverDate`, `await AccessController.shared.refreshAccess()`; assert `accessState == .fullAccess` and `enforcement_allowed == true`. (This is what makes the regression meaningful — it pins that the user IS grandfathered.)
3. Inject the failure: `try await session.setSimulatedError(.generic(.unknown), forAPI: .appTransaction)` (`SKTestSession.setSimulatedError(_:forAPI:)`, StoreKitTest.swiftinterface:240; `SKTestFailures.AppTransaction.generic` at :80-88; `.appTransaction` at :209-210).
4. Instantiate a FRESH `Store` (or a fresh AccessController) to model the cold launch — this is the crux: the in-memory verdict must start `false`, per Store.swift:17.
5. `await refreshAccess()`; ASSERT THE BUG: `accessState == .expired` and `defaults.bool(forKey: "enforcement_allowed") == false`. The desired post-fix behaviour is the opposite: an unavailable/unverified AppTransaction must be treated as "unknown", not "not grandfathered", so the gate must remain `true`.
6. Second, cheaper regression, pure and separable: assert `startTrialIfNeeded()` does NOT stamp `trial_start` when `hasFullAccess` is true (AccessController.swift:84-90 currently has no such check).

Blockers to be aware of: `AccessController.shared` is a singleton whose `kv` is a private non-injectable `AppGroupStore`, so the test must write the real app-group defaults and clean up after itself (`qaResetToFreshInstall()` at AccessController.swift:186-205 does exactly that wipe and can serve as tearDown); and `isGrandfathered` is `private(set)`, so assert through `hasFullAccess`/`accessState` rather than the flag. Neither blocks the test. A device is needed only to *watch* the shields fail to appear at 22:00 (step 6 of the trace); the persisted-gate defect itself does not need one.

---

### `V20` · Enforcement gate only recomputed while foregrounded -> never reopen the app and the trial never expires

- **🔴 Important** · impact **revenue** · needs device · hit **occasional for ordinary users (leak runs from trial end until the user's next foreground visit — days to weeks for a set-and-forget user); indefinite only for someone who deliberately never opens the app, i.e. the "free forever" version is closer to adversarial-but-trivial than to always**
- **Feature** F9 · **Discovery IDs** F9-DATE-03, F9-INTEG-02 (2 agents found this independently)

**Verifier's reasoning**

Every cited line says what both write-ups claim, and I found no guard.

Gate writers: `kv.setBool(accessState != .expired, forKey: AppGroupKeys.enforcementAllowed)` is the sole writer of `enforcement_allowed` (ScreenTimeShield/AccessController.swift:118), inside `private func recomputeAccessState()` (:112-120). A repo-wide grep for `recomputeAccessState` returns exactly six callers, all main-app: `startTrialIfNeeded` (:88), `refreshAccess` (:98), `purchase` (:103), `restore` (:109), and the QA hooks (:158, :164, :170, :176, :203). `refreshAccess` itself has exactly two non-QA entry points: `scenePhase == .active` (ScreenTimeShield/ScreenTimeShieldApp.swift:101-103) and `ContentView`'s `.task` (ScreenTimeShield/ContentView.swift:256-262). Both require a foreground launch. Grep for `BGTask|BackgroundTasks|Timer(` over all .swift: zero hits. So there is genuinely no clock-, timer-, or background-driven recompute.

Extension side: `enforcementAllowed` reads the cached key with `?? true` (CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:42-44); `intervalDidStart` guards on it (:56) and on pass calls `model.loadSelection()` / `model.setRestrictions()` / `insideInterval = true` (:60-63). `setRestrictions()` writes `store.shield.applications/applicationCategories/webDomains` (ScreenTimeShield/Model.swift:92-98) — real enforcement, no further entitlement check. The extension imports only DeviceActivity/UserNotifications/ManagedSettings/SwiftUI and never computes expiry.

No teardown on expiry: `recomputeAccessState` does not call `Schedule.stopMonitoring`. The only `stopMonitoring` calls are `ContentView.swift:84` (user taps Stop), `:242` (refocus toggle, notificationSchedule only), `Schedule.swift:34/53` (stop-then-start inside a re-register), and `AccessController.swift:188` (QA reset, unreachable — QA section commented out in SettingsView). `applySchedule` guards `!isExpired` (ContentView.swift:60), which only prevents *re-registering*; it never unregisters. The `.daily` activity is registered with `repeats: true` (ContentView.swift:63 → Schedule.swift:25-29) and the app itself treats registration as persistent across launches (`model.isArmed = DeviceActivityCenter().activities.contains(.daily)`, ContentView.swift:248).

Mitigations I searched for and did not find: no `onChange(of: access.accessState)`; the shield-action extension only ever answers `.close` and never routes into the app (CustomShieldAction/ShieldActionExtension.swift:14-56); `eventDidReachThreshold` (refocus notifications) is not gated, so it cannot flip the gate either; the trial-ended reminder is registered only from `updateTrialEndedNotification()` (:126-143), reachable only from the same missing recompute, so the honest user gets no nudge either.

So invariant F9.2 is violated: a user whose true `AccessEvaluator.accessState(now:trialStart:hasFullAccess:trialLength:)` is `.expired` keeps getting shields newly applied every day, because the "authoritative" cached gate is a stale `true` and nothing recomputes it while the app is not foregrounded.

Not in status.md — the pricing section (status.md:26-30) tracks only "manual QA the trial → paywall → purchase flow"; no entry describes a stale enforcement gate or a missing background/extension-side expiry evaluation.

**Correction to the original claim**

The mechanism is real; three details in the write-ups need correcting, none of which weakens it:

1. "Free forever" is really "free until the next time the app is foregrounded." Any foreground launch (including tapping "Open App" on a refocus notification, which an expired user still receives because `eventDidReachThreshold` is ungated) runs `refreshAccess()` and flips the gate false. The leak is therefore unbounded only for a user who literally never launches the app again — which is exactly the app's set-and-forget design, so it is a real and potentially permanent leak, but not a one-tap exploit.

2. As a deliberate exploit it is self-limiting in a way F9-DATE-03 does not mention: to keep the stale `true`, the user can never open the app, so they can never change apps, change the window, or stop the block. The realistic victim of this is the honest set-and-forget user (silent revenue leak + expiry never communicated at the moment it happens), not a motivated freeloader.

3. F9-DATE-03's claim that "`trial_start` and `PricingConfig.trialLength` are both available to the extension" is wrong on the second half: `CustomDeviceActivityMonitor` does not link UnplugCore (only ScreenTimeShield and CustomShieldConfiguration list it in `packageProductDependencies`, ScreenTimeShield.xcodeproj/project.pbxproj:369-371, 425-427), and the extension file imports no UnplugCore. `trial_start` and `qa_force_full_access` are readable from the app group, but the fix requires either adding the package to that target or duplicating the constant. It also cannot see StoreKit entitlement, so an extension-side expiry check must be conservative: only downgrade to "not allowed" when `trial_start` is old AND no cached full-access marker exists — which means the fix also needs the entitlement verdict mirrored into the app group (the same missing piece as F9-INTEG-03).

Additional consequence neither write-up separates out: because the trial-ended local notification is registered from the same `recomputeAccessState()` call, this single gap simultaneously causes the over-entitlement (blocks keep working) and the silence (no reminder). They cannot diverge.

**Failure trace (re-derived from source by the verifier)**

Day 0, 21:50 — user grants Screen Time auth, picks Instagram + TikTok, sets 22:00–07:00, taps "Start blocking". `performArm()` (ContentView.swift:76-80) → `startTrialIfNeeded()` writes `trial_start = day0` and calls `recomputeAccessState()` → `hasFullAccess == false`, `now - trial_start < 7d` → `.trial` → `enforcement_allowed = true` persisted in group.screentimeshield (AccessController.swift:113-118). `model.isArmed = true`; `applySchedule()` → `Schedule.setSchedule(..., repeats: true)` registers `.daily` (Schedule.swift:25-40).

Day 0..Day 7 — enforcement works nightly. User never needs the app again: the schedule repeats, the shield's only buttons close it (ShieldActionExtension.swift:20/22), so nothing pulls them back into the app.

Day 8, 22:00 — device in use, system launches CustomDeviceActivityMonitor and calls `intervalDidStart(.daily)`. `activity.rawValue == "daily"` (DeviceActivityMonitorExtension.swift:53). `enforcementAllowed` reads the day-0 `true` (:43). Guard at :56 passes. `Model.shared.loadSelection()` decodes `ScreenTimeSeletion`; `setRestrictions()` sets `store.shield.applications = {Instagram, TikTok}` (Model.swift:95-97); `insideInterval = true` (:63). Day 9, 07:00 `intervalDidEnd` clears. Repeats indefinitely.

Persisted state from day 8 onward: `trial_start = day0` (8+ days old, i.e. `.expired` if anyone evaluated it), `enforcement_allowed = true` (stale), `is_armed = true`, `.daily` still registered.

What the user sees: their blocks work exactly as during the trial, every night, forever — no paywall, no "Your blocks are off" notification (that request is only added from `updateTrialEndedNotification()`, reachable only via `recomputeAccessState()`). The instant they next foreground the app, `ContentView.task`/`scenePhase .active` → `refreshAccess()` → `.expired` → `enforcement_allowed = false`, and from the following interval the blocks stop.

**Apple API semantics checked**

The claim needs two Apple behaviours. (a) The system launches the DeviceActivityMonitor app extension for a registered schedule's interval callbacks independently of the containing app running — I could not fetch developer.apple.com/documentation/deviceactivity/deviceactivitymonitor or .../deviceactivitycenter/startmonitoring(_:during:events:) (both returned title-only, JS-rendered shells), but this is not a novel assumption: it is the operating premise of the entire product (the app's shields are only ever applied from the extension, DeviceActivityMonitorExtension.swift:60-63) and the code itself assumes registrations outlive the process (`DeviceActivityCenter().activities.contains(.daily)` used as the source of truth for `isArmed` across cold launches, ContentView.swift:248). If this semantic did not hold, Unplug would not function at all. (b) `scenePhase == .active` only occurs on foreground — standard SwiftUI, `.background`/`.inactive` cover non-foreground states, so a system background launch does not trigger `refreshAccess()`. Forum searches surfaced only the opposite failure mode (extensions sometimes *not* being woken, e.g. developer.apple.com/forums/thread/819224), which would shorten the leak, not create a guard. Nothing I could not confirm changes the verdict: the defect is the absence of app-side/extension-side re-evaluation, which is pure code truth and does not depend on any Apple semantic.

**Second opinion (agrees)**

_Worst realistic outcome:_ A user whose 7-day trial has lapsed keeps getting fully working shields applied every night, for free, for as long as they never foreground Unplug — with no paywall and no trial-ended notification. The moment they do foreground it once, the gate flips and the free ride ends permanently. No block is ever weakened by this bug; the loss is monetization only.

I re-derived the whole mechanism independently and it holds; agreeing with the verdict, but the first verifier over-claimed the consequence in three places.

Verified from source (all cited lines are accurate, no stale numbers): `kv.setBool(accessState != .expired, forKey: AppGroupKeys.enforcementAllowed)` at /Users/stevendiviney/code/ScreenTimeShield/ScreenTimeShield/AccessController.swift:118 is the only write of `enforcement_allowed` anywhere in the repo (my own grep for `enforcement_allowed|enforcementAllowed` returns exactly 6 hits: extension read at CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:42-43 and :56, the key constant at ScreenTimeShield/AppGroupStore.swift:17, a comment, and the single writer). `recomputeAccessState()` is only reachable from main-app entry points; grep for `BGTaskScheduler|import BackgroundTasks|performFetch|Timer(` and for `UNUserNotificationCenterDelegate|didReceive response` across all Swift files returns zero — so there is genuinely no timer, background task, or notification-response hook that could recompute it, and no `UIBackgroundModes` plist. `applySchedule()` guards `!isExpired` (ContentView.swift:60) but nothing unregisters `.daily`; the only `stopMonitoring` calls are user-driven (ContentView.swift:84, :242) or inside a re-register (Schedule.swift:34/53). Invariant F9.2 (qa/invariants.md:63) is exactly what breaks. Not in status.md (pricing section, status.md:26-30, only tracks "manual QA the trial → paywall → purchase flow").

Corrections to their consequence framing:

1. They state "the honest user gets no nudge either" and that nothing pulls the user back into the app. That understates a real, default-on path back in. `eventDidReachThreshold` is NOT gated by `enforcementAllowed` (DeviceActivityMonitorExtension.swift:88-107) and `notificationsEnabled` defaults to `true` (`@AppStorage("notifications_enabled") … = true`, ScreenTimeShield/Model.swift:26), with `notificationSchedule` registered on every arm (ContentView.swift:63-66). So an expired-but-still-enforced user keeps receiving "You've been using a restricted app for N minutes, tap here to regain focus" whenever they use a restricted app outside blocked hours, and tapping that notification launches the app → `scenePhase == .active` → `refreshAccess()` → gate flips false. The app therefore nags itself out of the exploit for any ordinary user. Their specific claim about the *trial-ended* reminder (AccessController.swift:126-143 unreachable without a foreground recompute) is correct; the general claim "nothing pulls them back into the app" is not.

2. "The lifetime unlock is bypassable by a client-side action any normal user can take" is over-stated. The precondition is not an action, it is permanent abstention: every single thing a user might want to do — change apps, move the window, switch Block/Allow-only, stop the block, look at the times-stopped stat, tap a refocus notification — requires foregrounding, and one foreground ends the leak for good from the next interval. Realistic characterization: an unbounded leak for a deliberate freeloader, a bounded (days-to-weeks) leak for the set-and-forget cohort the app is actually pitched at. That cohort matters, which is why I keep severity important, not because "any normal user" can farm this.

3. Direction of harm deserves stating explicitly, and they didn't: this bug can only ever *over*-enforce. It never lets a block fail, so it does not touch the product promise — unlike its sibling F9-INTEG-01/F9.11 (armed-but-unenforced), which is the same code region but the opposite direction. "Revenue" is the right and only class here; there is no user-facing breakage, no data loss, and no App Store risk. Reviewers should not merge the two findings' severities.

Two smaller notes. (a) Flipping the gate does not clear shields already applied for the current window — `intervalDidEnd` does that (DeviceActivityMonitorExtension.swift:66-77) — so the night the user finally opens the app, the in-flight block still runs to its natural end; the cliff is the following interval. (b) The obvious fix (have the extension evaluate expiry itself from `trial_start`, already in the app group) needs the monitor target to link UnplugCore or duplicate `trialLength`: per ScreenTimeShield.xcodeproj/project.pbxproj only the main app and CustomShieldConfiguration have `UnplugCore in Frameworks` (lines 173, 198); CustomDeviceActivityMonitor does not. Cheap, but not zero.

Apple semantics: nothing here needs an unconfirmed behaviour — persistence of a `repeats: true` registration without the host app running is the premise of the shipped, working app (and the app re-derives `isArmed` from `DeviceActivityCenter().activities`, ContentView.swift:248). Real-world DeviceActivity flakiness (developer.apple.com/forums/thread/721945, /thread/819224 report intervalDidStart silently ceasing) can only shorten the leak by breaking enforcement, which would itself drive the user back into the app — again cutting against "forever".

Sources: [Apple Developer Forums — intervalDidStart not repeating](https://developer.apple.com/forums/thread/721945), [intervalDidStart never called on iOS 26.3.1](https://developer.apple.com/forums/thread/819224)

**Proof path**

Not provable today. The pure layer is already correct and already tested: `AccessEvaluator.accessState` returns `.expired` for a >7-day-old `trialStart` (UnplugCore/Sources/UnplugCore/AccessControl.swift:51-58, covered by UnplugCore/Tests/UnplugCoreTests/AccessControlTests.swift). The defect is the *absence* of any call to that logic outside the main app's foreground path, and no pure function represents the extension's decision — `DeviceActivityMonitorExtension.enforcementAllowed` is a raw `UserDefaults.bool` read (:42-44), and the writer `recomputeAccessState()` is `private` on a `@MainActor` class whose `refreshAccess()` reaches StoreKit and UNUserNotificationCenter. SKTestSession does not help: no StoreKit call is involved in the failing path.

Extraction needed to make it testable: move the gate decision into UnplugCore as a pure function the *extension* calls, e.g. `EnforcementGate.shouldEnforce(now: Date, trialStart: Date?, hasFullAccess: Bool, trialLength: TimeInterval) -> Bool`, add UnplugCore to the CustomDeviceActivityMonitor target, mirror the entitlement verdict into the app group (a `full_access_cached` key) so `hasFullAccess` is answerable without StoreKit, and have `intervalDidStart` call it with `Date()` and the app-group values instead of reading a cached boolean. A test would then assert: trialStart = now-8d, hasFullAccess = false → `shouldEnforce == false` (today's code applies shields); trialStart = now-8d, hasFullAccess = true → `true` (protects F9.3/F9.4); trialStart = nil → `true`. Absent that extraction, verification requires a device: arm a block, background the app, advance the device clock past day 7, and observe `intervalDidStart` still shielding.

---

### `V21` · Buying the unlock mid-window does not restore enforcement for the window already in progress

- **🔴 Important** · impact **revenue** · needs device · hit **common among users who convert after trial expiry (the app's own designed conversion path routes them into the window); occasional across all users. Not adversarial — the user is actively trying to make their block work.**
- **Feature** F9 · **Discovery IDs** F9-DATE-04
- **Already in status.md:** Not recorded. `status.md` has no entry for this mechanism. The nearest lines are `status.md:30` ("Manual QA the trial → paywall → purchase flow" — unchecked, but that is a QA task, not a logged bug) and the two undocumented placeholders at `status.md:12-13` ("Notifications bug — needs investigation", "Outstanding bug mentioned in README"), neither of which describes purchase-time re-arming. Note also that the extension comment at `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:55` asserts a "gate-and-drain" that does not exist in code — the drain half is unimplemented, which is the precondition this candidate depends on.

**Verifier's reasoning**

Every cited line says what the claim says it says, and I found no guard that heals the state.

- `ScreenTimeShield/AccessController.swift:101-105` — `purchase()` is exactly `let ok = try await storeKit.purchase(); recomputeAccessState(); return ok`. `restore()` (`:107-110`) is the same shape. `recomputeAccessState()` (`:112-120`) only recomputes `accessState`, writes `enforcement_allowed = (accessState != .expired)` (`:118`), and updates the trial-ended notification. It never touches `Model.setRestrictions()`, `Schedule.setSchedule`, or `DeviceActivityCenter`.
- `ScreenTimeShield/PaywallView.swift:132-142` — `buy()` calls `access.purchase()` and on success just `dismiss()`; `onChange(of: access.accessState)` (`:120-122`) also only dismisses. `restore()` (`:144-153`) likewise.
- `ScreenTimeShield/ContentView.swift` has no `onChange(of: access.accessState)` anywhere (verified by reading the whole file, `:212-284`). `applySchedule()` (`:59-68`) is called only from `performArm()` (`:79`) and the `model.selectionToRestrict` onChange (`:228`). `.onAppear` (`:245-255`) only does `loadSelection()`, syncs `isArmed` from `DeviceActivityCenter().activities.contains(.daily)`, and the invalidated-selection toast — it never re-applies a schedule or restrictions. `.task` (`:256-262`) and `ScreenTimeShieldApp.swift`'s scenePhase handler only call `refreshAccess()`, which ends in the same `recomputeAccessState()`.
- Grepping the whole tree for `setRestrictions` shows exactly one caller: `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:62`, inside `intervalDidStart` behind `guard enforcementAllowed` (`:56-59`). The main app never applies shields; it only ever calls `clearRestrictions()` (`ContentView.swift:85`, `AccessController.swift:189`).
- The claim's precondition (stale `.daily` survives expiry) also holds: the only `stopMonitoring` call sites are `stop()` (`ContentView.swift:84`, user-initiated), the notifications toggle (`:242`), inside `Schedule.setSchedule`/`setNotificationSchedule`, and `qaResetToFreshInstall`. There is no drain-on-expiry anywhere, despite the extension comment at `DeviceActivityMonitorExtension.swift:55` claiming "The app also stops scheduling on expiry (gate-and-drain)". So an expired user keeps `.daily` registered and `onAppear` sets `isArmed = true` from it.

I could not find any path that re-arms after entitlement is restored. The trace is reachable by a real (paying) user.

**Correction to the original claim**

Two refinements to the claim as written, neither of which rescues it:

1. "with the UI showing the block as armed" is half right. The status banner honestly reads "Block inactive" (`StatusBanner.swift:33`, keyed off `inside_interval`, which the extension never set because it returns before `:63`); it is the primary CTA that reads "Stop blocking" (`ContentView.swift:39`, keyed off `is_armed`). The UI is therefore internally contradictory — "armed but not blocking" during a window that should be blocking — rather than uniformly claiming enforcement.

2. There is an undiscoverable manual workaround the claim does not mention: after purchase, `primaryDisabled` is false (`ContentView.swift:43-48`: `insideInterval` false, `isArmed` true), so the user can tap "Stop blocking" then "Start blocking" → `isRiskyToArm()` returns true because 22:30 is inside the window (`:124-133`) → confirm alert → `performArm()` → `applySchedule()` re-registers `.daily`, which is the same mechanism the "block for an hour" path relies on. That makes this a missing self-heal rather than an unrecoverable state, but nothing in the UI hints at it and the app takes no such action itself.

3. The *duration* of the gap is the one part I would not defend verbatim. "Until 22:00 the following day" holds only if `intervalDidStart` is never re-delivered within an interval occurrence. The fix is the same either way: `purchase()`/`restore()` (or an `onChange(of: access.accessState)` in `ContentView`) should re-register the schedule / apply restrictions when the window currently contains `now`.

**Failure trace (re-derived from source by the verifier)**

Preconditions: user armed a 22:00→07:00 daily block during the trial, so `.daily` is registered with `DeviceActivityCenter` and `is_armed = true`. Trial expires; the user foregrounds the app at some point after expiry → `ScreenTimeShieldApp` scenePhase `.active` → `refreshAccess()` → `recomputeAccessState()` → `accessState = .expired`, app group `enforcement_allowed = false` (`AccessController.swift:113-118`). Nothing removes `.daily`.

1. 22:00, phone in use. System delivers `intervalDidStart(.daily)` → `DeviceActivityMonitorExtension.swift:53-59` → `activity.rawValue == "daily"` → `guard enforcementAllowed` is false → `return`. No `setRestrictions()`, and `insideInterval` is left `false` (it is only set at `:63`, after the guard).
2. 22:30 the user notices Instagram opens normally, launches Unplug, taps the trial chip (`ContentView.swift:186-188`), pays for the lifetime unlock.
3. `PaywallView.buy()` → `access.purchase()` → `Store.purchase()` sets `isPurchased = true` → `hasFullAccess` true (`Store.swift:20`) → `recomputeAccessState()` → `AccessEvaluator.accessState` returns `.fullAccess` (`AccessControl.swift:53-58`) → `enforcement_allowed = true`. Paywall dismisses (`PaywallView.swift:138` / `:121`).
4. Persisted state after payment: `enforcement_allowed = true`, `is_armed = true`, `inside_interval = false`, `.daily` still registered for 22:00–07:00, `ManagedSettingsStore` shield **empty** — nobody called `setRestrictions()`.
5. What the user sees on the main screen: `StatusBanner` reads "Block inactive" (`StatusBanner.swift:33`, driven by `insideInterval == false`) while the primary CTA reads "Stop blocking" (`ContentView.swift:39`, driven by `isArmed == true`). Restricted apps remain fully usable.
6. 07:00 → `intervalDidEnd(.daily)` (`:68-79`) clears restrictions and sets `insideInterval = false` (a no-op). 22:00 the next day → `intervalDidStart` fires with the gate now true → shields finally applied.

So the paid-for window is unenforced from purchase until the next occurrence of the schedule.

**Apple API semantics checked**

Only one Apple semantic is load-bearing, and it is load-bearing for the *duration* of the gap, not for its existence: whether `DeviceActivityMonitor.intervalDidStart(for:)` can be re-delivered later within the same interval occurrence. I attempted to fetch developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidstart(for:) and the page returned no usable prose (Apple's JS-rendered docs), so I could not independently confirm or refute one-shot delivery. That leaves the "unblocked until 22:00 tomorrow" figure UNCERTAIN — if the system re-fires on next device use after an idle period, the gap could be shorter.

The core defect does not depend on it: `Model.setRestrictions()` has exactly one caller in the entire tree (`DeviceActivityMonitorExtension.swift:62`), and no purchase/restore/foreground/appear path in the app calls it or re-registers the schedule. So even under the most favourable re-delivery semantics, a device in continuous use after purchase gets no enforcement, and a device already in use at the interval start (the realistic case — the user noticed apps weren't blocked) has already consumed its callback.

Also verified from source, not from names: `Store.hasFullAccess = isPurchased || isGrandfathered` (`Store.swift:20`), and `AccessEvaluator.accessState` returns `.fullAccess` whenever `hasFullAccess` (`UnplugCore/Sources/UnplugCore/AccessControl.swift:53-58`) — so the post-purchase state transition itself is correct; only the enforcement side effect is missing.

**Second opinion (agrees)**

_Worst realistic outcome:_ A user who has just paid for the lifetime unlock gets no blocking at all for the remainder of the current block window — typically the rest of the evening, and up to ~16-23h in Allow-only mode where the blocked interval is the complement of the allow window (`ScreenTimeShield/Model.swift:36-38`) — while the main screen's CTA reads "Stop blocking" as if it were armed. Enforcement returns by itself only at the next occurrence of the schedule. Recovery requires the user to guess an undocumented toggle (Stop → Start).

Mechanism verified independently, and I could not find a guard. `purchase()`/`restore()` end at `recomputeAccessState()`, which writes only `accessState` + `enforcement_allowed` + the reminder (`ScreenTimeShield/AccessController.swift:101-120`). A repo-wide grep for `setRestrictions|startMonitoring|stopMonitoring` gives exactly: `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:62` (behind `guard enforcementAllowed`, `:56`), `ScreenTimeShield/Schedule.swift:34/36/53/55/65`, `ScreenTimeShield/ContentView.swift:84/242`, `ScreenTimeShield/AccessController.swift:188` (QA only). Nothing on the entitlement-change path. `applySchedule()` (`ContentView.swift:59-68`) is reachable only from `performArm()` (`:79`) and the selection `onChange` (`:228`); `.onAppear` (`:245-255`) only syncs `isArmed` from `DeviceActivityCenter().activities`; scenePhase (`ScreenTimeShieldApp.swift:95-104`) and `.task` (`ContentView.swift:256-262`) only call `refreshAccess()`. Not in `status.md` — `status.md:27,30` cover grandfathering rework and "manual QA the trial → paywall → purchase flow", not this. So: news, and CONFIRMED.

Three corrections to their write-up.

(1) "revenue" is the wrong class and it understates the bug. The money was collected — no revenue is lost. What fails is the core product promise (unskippable blocking) for a *paying* customer, immediately after payment, i.e. an enforcement/correctness defect with revenue exposure only indirectly via refunds and 1-star reviews. Labelled "revenue" this reads like a conversion nicety and risks being deprioritised behind the enforcement bugs it actually belongs with. It is also the same root cause as the no-drain candidate (nothing reconciles enforcement state when entitlement changes) and should be fixed with it: on `accessState` becoming non-expired, if `isArmed` and now ∈ `blockedInterval`, re-register `.daily` (which does fire `intervalDidStart` mid-window — the app already depends on that for its risky-arm path, `ContentView.swift:124-133,144-146`).

(2) They understate frequency. `updateTrialEndedNotification()` (`AccessController.swift:126-142`) deliberately schedules the daily "Your blocks are off" reminder at the persisted `"start"` time — which in the default mode *is* the block start (`Model.swift:36-38`). The app's own conversion funnel therefore delivers the buyer into the app at, or inside, the blocked window. Mid-window purchase is the modal case for post-expiry converters, not an edge case. (In Allow-only mode `"start"` is the allow-window start, i.e. outside the block, so that path escapes — separately tracked as F9-DATE-07.)

(3) They over-claim the duration as a flat "until 22:00 the following day". It is bounded by the remainder of the window, and several things can shorten it: the user tapping Stop then Start (enabled — `primaryDisabled` is false because `insideInterval == false`, `ContentView.swift:43-48`), re-opening the app picker (the `selectionToRestrict` onChange calls `applySchedule()`, `:218-229`), "Block for an hour" (which becomes enabled post-purchase since `isQuickRestrictDisabled` drops `isExpired`, `:31-33`) giving an immediate 1h block, and possibly iOS itself — there are developer reports of `intervalDidStart` being delivered more than once for repeating schedules, which would heal it opportunistically. None of these is a guard (all require user action or luck, and the UI gives no hint that a re-arm is needed), so the finding stands; but "the paid-for window is unenforced from purchase until the next occurrence" should be stated as the worst case, and "with the UI showing the block as armed" should be softened: `StatusBanner` honestly says "Block inactive" (`StatusBanner.swift:33`); the misleading parts are the "Stop blocking" CTA and the total absence of any explanation.

Residual uncertainty (same as the candidate's self-reported medium): the duration depends on iOS not re-delivering `intervalDidStart` for an occurrence that already began. Apple's docs only say an activity starts when the device is first used within the interval, which is consistent with once-per-occurrence but is not an explicit guarantee, and forum reports of duplicate delivery cut the other way. This affects how long the gap lasts, not whether it exists — the gap from purchase until *something* re-registers is unavoidable either way, so it does not move the verdict. A device test (expire trial while armed, let the window start, buy mid-window, watch for shields) would settle the duration.

**Proof path**

Not provable today. The defect is an *absence* of a call in `AccessController.purchase()`/`restore()` and in `ContentView`, and the only code that can apply shields is `Model.setRestrictions()` (ManagedSettings) driven by the DeviceActivity extension — both device-only. `SKTestSession` could prove the half that already works (`purchase()` → `accessState == .fullAccess` and `enforcement_allowed == true`), but not the missing half.

To make it testable, extract a pure decision into `UnplugCore`, e.g. `EnforcementReconciler.shouldReapplyNow(accessState:isArmed:insideInterval:nowMinutes:windowStart:windowEnd:) -> Bool`, alongside the existing `ScheduleMath.windowContains`. Then a pure test asserts `true` for (`.fullAccess`, armed, `insideInterval == false`, now inside window) and `false` for the armed/outside-window and `.expired` cases, and the app calls it from `recomputeAccessState()` / an `onChange(of: access.accessState)`. Device QA is still needed to confirm that re-registering `.daily` mid-window actually re-fires `intervalDidStart` and lands the shield.

---

### `V22` · cutoverDate (2026-06-25) is already in the past while the IAP build is unshipped -> post-cutover paying users not grandfathered

- **🔴 Important** · impact **revenue** · unit-testable now · hit **Conditional: zero users today (1.3 is unshipped, so nothing can fire). Once 1.3 ships unchanged it is "always" — deterministic for 100% of the affected cohort on ordinary use, no adversarial action needed. Cohort is bounded and probably small: every $0.99 download between 2026-06-25 and the actual release (app is still paid and pre-marketing, `status.md:3` "Need to move to marketing"), growing one day per day of slip.**
- **Feature** F9 · **Discovery IDs** F9-DATE-05
- **Already in status.md:** Partially flagged, not recorded as an open bug. `status.md:28` is the matching entry: "**Cutover date set** — `PricingConfig.cutoverDate` = **2026-06-25** (target release, ~1 week out). Users who downloaded before this are grandfathered. **Adjust if the release date slips.** (Tests use their own boundary constant and stay green.)" — but it is checked `[x]` (done), and `status.md:33` (the v1.3 release-sequencing item that documents the slip) never links back to it. `status.md:3` "P1: Triage remaning todos, grandfather logic and anything critical" is the only open item in the neighbourhood. So the hazard was anticipated; that it has now actually fired is news.

**Verifier's reasoning**

Every cited line says what the claim says.

- `UnplugCore/Sources/UnplugCore/AccessControl.swift:27` — `public static let cutoverDate = Date(timeIntervalSince1970: 1_782_345_600)`. I converted it independently: 2026-06-25 00:00:00 UTC. Today is 2026-07-25, so the constant is a month in the past. The doc comment two lines above (`:26`) explicitly says "Keep in sync with the actual App Store release; adjust if the release date slips."
- `AccessControl.swift:74-77` — `isGrandfathered` is `guard let originalPurchaseDate else { return false }; return originalPurchaseDate < cutoverDate`. Strict `<`, nil → false. No leniency, no fallback.
- `ScreenTimeShield/Store.swift:20` — `hasFullAccess { isPurchased || isGrandfathered }`; `:69-80` `refreshGrandfatheredState` feeds `AppTransaction.shared.originalPurchaseDate` into `Grandfather.isGrandfathered`. `:57-67` `refreshPurchasedState` only counts `productID == "com.halfspud.ScreenTimeShield.lifetime"` — so the $0.99 *app* purchase grants nothing. I searched for any other path granting access to prior owners (grep for `originalAppVersion`, `originalPurchaseDate`, `isGrandfathered`, `hasFullAccess`): the only other override is `qaForceFullAccess` (`AccessController.swift:145-148`), reachable only from the QA menu that `status.md:29` says is commented out in `SettingsView`. So grandfathering is the sole escape hatch and it is closed for the affected cohort.

I looked hard for a mitigation and found none that prevents the outcome:
- `enforcement_allowed` defaults to **true** in the monitor extension (`CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:42-44`) — but the app *writes* `false` on expiry (`AccessController.swift:118`), so the default never rescues an expired user.
- The trial clock only starts on an explicit arm (`AccessController.swift:84-90` called from `ContentView.swift:61,77,106`), which merely *delays* expiry for an updating user until their next Start tap; it does not prevent it.
- The existing unit tests cannot catch the drift: `UnplugCore/Tests/UnplugCoreTests/AccessControlTests.swift:87` uses its own constant `1_781_740_800` (2026-06-18) labelled "matches PricingConfig.cutoverDate placeholder" — already stale relative to the real constant. Nothing in the repo asserts anything about the production value.

Release-slip premise is supported from inside the repo, not assumed: last product commit is `1ea682e` 2026-06-19 (the only later commit is the QA-pass commit itself); `status.md:2` says the lifetime IAP is still "Ready to Submit" and "must be submitted with an app build to go live"; `status.md:33` says 1.3 was pulled from review on 2026-06-19 and its release is gated on the US→Ireland move; `MARKETING_VERSION` is still 1.3. So the IAP build has not shipped, while the cutover it is pinned to has already passed. The one thing I cannot verify from here is App Store Connect itself — if 1.3 had somehow been released on 2026-06-25 the constant would be right — but every artifact in the repo says otherwise, and the code as it stands cannot ship correctly without moving the date.

This is a stale-constant defect with a real user-visible consequence, not a boundary-arithmetic nit, and the claim frames it that way correctly.

**Correction to the original claim**

Two refinements to the claim's framing, neither of which changes the verdict:

(a) The loss is not immediate on update. An updating pre-cutover-but-post-2026-06-25 buyer gets a fresh 7-day trial that only starts on their next explicit arm (`startTrialIfNeeded` from `ContentView.swift:61,77,106`). An existing user whose daily schedule is already registered with `DeviceActivityCenter` and who never taps Start again keeps `trial_start == nil` and therefore stays `.trial` indefinitely — enforcement continues. So the harm lands on first re-arm, which is inevitable but not instant. This makes the bug quieter (and harder to spot in QA), not smaller.

(b) The blast radius is defined by the *gap*, not by a fixed window: every day the release slips adds another day of paid downloads that will be treated as post-IAP. The fix is not just "bump the date once" — the constant needs to be set (or verified) at submission time, and there is currently no test or check that would fail if it is not: `AccessControlTests.swift:87` deliberately uses its own boundary constant.

**Failure trace (re-derived from source by the verifier)**

1. Live App Store build today is the pre-IAP paid build (1.2, $0.99, no trial, no paywall). A user pays $0.99 on 2026-07-01. StoreKit records `AppTransaction.originalPurchaseDate = 2026-07-01`.
2. Whenever 1.3 (first IAP build) ships, they auto-update. Fresh app-group keys: `trial_start` = nil, no lifetime entitlement.
3. Launch → `ContentView.task`/`scenePhase` → `AccessController.refreshAccess()` (`AccessController.swift:92-97`) → `Store.refreshPurchasedState()` finds no `…lifetime` entitlement → `isPurchased = false`; `Store.refreshGrandfatheredState(cutoverDate: PricingConfig.cutoverDate)` → `Grandfather.isGrandfathered(2026-07-01, 2026-06-25)` → `2026-07-01 < 2026-06-25` is **false** → `isGrandfathered = false` → `hasFullAccess = false`.
4. `recomputeAccessState()` → `AccessEvaluator.accessState(trialStart: nil, hasFullAccess: false)` → `.trial`; writes `enforcement_allowed = true`. UI shows `TrialChip` "7 days left in trial · Unlock".
5. They tap "Start blocking" → `performArm()` (`ContentView.swift:76-80`) → `startTrialIfNeeded()` persists `trial_start = now`.
6. 7 days later, first foreground → `refreshAccess()` → `recomputeAccessState()` → `now - trialStart >= trialLength` → `.expired`; `kv.setBool(false, "enforcement_allowed")` (`AccessController.swift:118`); `updateTrialEndedNotification()` schedules the daily "Your blocks are off" reminder.
7. Persisted state: `enforcement_allowed = false`. Next `intervalDidStart` in the monitor extension hits `guard enforcementAllowed else { return }` (`DeviceActivityMonitorExtension.swift:56-59`) → **no restrictions applied**. In-app, `isExpired` disables the quick-restrict CTA and routes Start to the paywall (`ContentView.swift:31-33,71,101`).
8. What the user sees: the app they paid $0.99 for stops blocking anything, the chip reads "Trial ended · Unlock Unplug", and every CTA routes to a $4.99 purchase.

**Apple API semantics checked**

Checked `AppTransaction.originalPurchaseDate` against Apple's developer documentation: it is a non-optional `Date` representing when the customer originally obtained the app, and it does not change on app update or re-download (which is exactly why the code moved off `originalAppVersion` — see `AccessControl.swift:21-23` and `status.md:27`). That matches the claim; the claim does not depend on any unusual or unconfirmed API behaviour. `Transaction.currentEntitlements` semantics (only the IAP product id appears, not the paid-app purchase) also match how `Store.refreshPurchasedState` is written. The only unverifiable input is external, not API: the actual App Store release state of 1.3, which I could only corroborate from git history and `status.md`.

**Second opinion (agrees)**

_Worst realistic outcome:_ If 1.3 ships without moving the constant: every customer who paid $0.99 between 2026-06-25 and the real release date is silently put into a 7-day trial, and after it lapses their block simply stops firing (`enforcement_allowed=false` → `guard enforcementAllowed else { return }` in the monitor extension). The chip reads "Trial ended · Unlock Unplug" and every CTA asks for $4.99. There is no recovery path in the app — "Restore Purchases" cannot help them. Refunds, 1-star reviews, and App Store exposure for putting previously-paid functionality behind a new paywall.

I re-derived it independently and every line they cite is accurate: `AccessControl.swift:27` is 1_782_345_600 = 2026-06-25 00:00 UTC (confirmed by conversion; today is 2026-07-25); `Grandfather.isGrandfathered` (`:74-77`) is strict `<` with nil→false; `Store.swift:20,57-67,69-80` are as described; the monitor guard is at `DeviceActivityMonitorExtension.swift:56-59` with the `?? true` default at `:42-44`; the stale test constant at `AccessControlTests.swift:87` is 2026-06-18. I found no guard, no fallback, no restore path. Verdict CONFIRMED, severity important — a one-line fix whose absence breaks the grandfathering intent outright.

Five corrections/additions to their work:

1. UNDERSTATED — this is already tracked, verbatim, in `status.md`. `status.md:28` reads: "**Cutover date set** — `PricingConfig.cutoverDate` = **2026-06-25** (target release, ~1 week out) … **Adjust if the release date slips.**", its parent grandfathering item is `[~]` (in progress), and `status.md:3` is "P1: Triage remaining todos, grandfather logic and anything critical". The first verifier never mentioned status.md as prior art. This is not news to the author — the correct framing is "the tracked release-gate step is now a month overdue and the slip has already happened once without it being touched", which is itself the argument against treating it as self-correcting.

2. WRONG CLASS — "revenue" is backwards. The error direction over-charges: Unplug would collect $4.99 from users who were meant to be permanently free. No revenue is lost. The real damage is entitlement/trust: paid customers lose the enforcement they bought, plus refunds, 1-star reviews, and App Store review exposure (removing previously-purchased functionality behind a new paywall). Class it as an entitlement regression, not revenue.

3. OVER-CLAIMED TIMING (their step 7) — `recomputeAccessState()` is app-only, so `enforcement_allowed=false` is written only when the user next foregrounds the app after day 7. A user who auto-updates and never reopens the app never has the gate flipped (extension default is `true`), and an in-progress block is not torn down mid-interval — restrictions persist until `intervalDidEnd`. So it is "blocks silently stop at the next interval boundary after they open the app", not "the app stops blocking" immediately.

4. RIGHT CONCLUSION, WRONG REASON (their step 5) — they treat the Start tap as an optional user choice that merely delays expiry. It's near-certain, and for a worse reason: `is_armed` (`Model.swift:32`) is a key new in 1.3, so an upgrading 1.2 user defaults to `isArmed = false` and the UI shows "Start blocking" even though their 1.2-registered DeviceActivity schedule is still live and enforcing. The UI misrepresents the armed state, which all but guarantees the tap that starts the trial clock.

5. MISSED — no recovery path, which makes it stickier than they said. `AccessController.restore()` (`:107-110`) → `Store.restore()` (`Store.swift:52-55`) calls only `refreshPurchasedState()`; it never calls `refreshGrandfatheredState`. Tapping "Restore Purchases" on the paywall returns nothing to a wrongly-ungrandfathered user (and could not help regardless — the cutover is a client-side constant). Their only exits are paying $4.99 or waiting for a build with a corrected constant.

One thing I also could not settle, same as them: App Store Connect itself. Every artifact in the repo (last product commit `1ea682e` 2026-06-19, IAP "Ready to Submit" at `status.md:2`, 1.3 pulled from review at `status.md:33`, MARKETING_VERSION still 1.3) says 1.3 is unshipped. If 1.3 had in fact been released on 2026-06-25 the constant would be correct and this would be REFUTED — checking the release date in ASC is the single thing that settles it.

**Proof path**

Pure and testable today in `UnplugCore` — no simulator, no view extraction. Target: `PricingConfig.cutoverDate` + `Grandfather.isGrandfathered`.

Assert the release-safety invariant against the *production* constant rather than a private copy:
- `XCTAssertTrue(Grandfather.isGrandfathered(originalPurchaseDate: Date(), cutoverDate: PricingConfig.cutoverDate))` — "anyone who obtains the app right now, while the IAP build is unshipped, must be grandfathered." This fails today.
- Equivalently/additionally `XCTAssertGreaterThan(PricingConfig.cutoverDate, Date())`, i.e. the cutover must be in the future for as long as the IAP has not gone live.

Note the existing tests deliberately dodge this: `AccessControlTests.swift:87` defines its own `cutover = Date(timeIntervalSince1970: 1_781_740_800)` (2026-06-18) commented "matches PricingConfig.cutoverDate placeholder" — it no longer matches, and none of the four Grandfather tests touch `PricingConfig`, which is exactly why `swift test` stays green while the shipped constant rots.

---

### `V23` · Expired trial fully restored by moving the device clock backward

- **🔴 Important** · impact **revenue** · unit-testable now · hit **adversarial-only (but the adversary here is the ordinary user in a moment of weakness, which is this product's *primary* threat model — not an exotic attacker). No honest-clock user ever hits the backward path. A rare accidental variant exists (see note item 4).**
- **Feature** F9 · **Discovery IDs** F9-INTEG-01
- **Already in status.md:** No matching entry. `grep -i` over status.md for clock/backdate/tamper returns nothing; the only related open item is line 30, "Manual QA the trial → paywall → purchase flow", which is about verifying the happy path, not this bypass. The QA scaffolding does include `qaExpireTrial()` (AccessController.swift:162-166) which fakes expiry by back-dating `trial_start`, i.e. the author has thought about clock-relative trial state but only in the forward direction.

**Verifier's reasoning**

Every cited line says what the claim says it says, and I found no guard anywhere.

- `UnplugCore/Sources/UnplugCore/AccessControl.swift:57` is literally `return now.timeIntervalSince(trialStart) < trialLength ? .trial : .expired` — a signed comparison with no lower bound, so a negative elapsed interval (now < trialStart) yields `.trial`.
- `UnplugCore/Sources/UnplugCore/AccessControl.swift:66-68` is `let remaining = trialLength - now.timeIntervalSince(trialStart)`, unbounded above → "18 days left" in a 7-day trial.
- `ScreenTimeShield/AccessController.swift:113` passes `now: Date()` (the user-settable wall clock; no monotonic source anywhere — `grep -rn "systemUptime|monotonic|lastSeen|highWater"` over all .swift returns only a doc comment at AccessControl.swift:22), and `:118` unconditionally rewrites `enforcement_allowed = (accessState != .expired)`, i.e. it can flip back to `true`.
- `ScreenTimeShield/AccessController.swift:55-58` + `AppGroupStore.swift:13,26-32` store `trial_start` as a plain absolute `Date` in `group.screentimeshield`.
- Ratchet search: I enumerated every writer/reader of `trial_start` (`grep -rn "trialStart|trial_start|trialStartDate"`). Writers are only `startTrialIfNeeded()` (AccessController.swift:85-86, guarded by `== nil`) and the three QA setters (:157, :163, :169). Nothing clamps, sanity-checks, or high-water-marks the value; nothing rejects a future `trial_start`; no persisted "max now seen".
- Reachability of the restore path: `ScreenTimeShieldApp.swift:101-102` calls `refreshAccess()` on every scenePhase `.active` → `recomputeAccessState()`. Nothing in `refreshAccess()` (AccessController.swift:93-99) or `Store` (Store.swift:58-81) is clock-anchored in a way that would veto it — `Grandfather.isGrandfathered` compares two clock-independent values, so it neither helps nor hurts.
- Post-restore the whole product is live: `ContentView.swift:28` derives `isExpired` from `accessState`, so `start()` (:71), `openPicker()` (:96) and `restrictForNextHour()` (:101) stop routing to the paywall, and `DeviceActivityMonitorExtension.swift:42-44,56` reads the freshly-`true` `enforcement_allowed` and applies shields. `Schedule.swift:26-28,69-70` builds schedules from `hour`/`minute` DateComponents with `repeats: true`, so a date-only rollback doesn't disturb the daily interval.
- Existing tests only feed forward-moving `now` (`AccessControlTests.swift:18-70`); no case has `now < trialStart`.

Line-number nit that does not affect the mechanism: the claim cites `Schedule.swift:76`, but that file is only 72 lines; the correct anchors are Schedule.swift:26-28 and :69-70.

**Correction to the original claim**

The mechanism is exactly as claimed; two consequence details need correcting.

(a) "Free forever with a one-minute change" overstates the persistence of the *UI* restore. `trial_start` is never rewritten, so the restored `.trial` verdict only holds while the device clock stays within 7 days of the original `trial_start`. The moment the user re-enables "Set Automatically" (or moves the clock forward), the next foreground `refreshAccess()` recomputes `.expired` and re-writes `enforcement_allowed = false`. So the honest framing is "trial fully restored for as long as the clock stays backdated" — and the cost of a permanently wrong clock (iMessage/App Store/TLS) is real friction, not zero.

(b) There is, however, a cheaper composite that *is* permanent and worth reporting alongside: because `enforcement_allowed` is only ever written from the foreground path (AccessController.swift:118, reachable only via ScreenTimeShieldApp.swift:101-102 / ContentView's `.task` / purchase / QA), a user can backdate the clock once, foreground the app to latch `enforcement_allowed = true`, then set the clock back to correct and simply never foreground Unplug again. The `.daily` schedule stays registered (`repeats: true`, and nothing in `recomputeAccessState` calls `Schedule.stopMonitoring` — the "gate-and-drain" comment at DeviceActivityMonitorExtension.swift:54-55 is not implemented), so the extension keeps applying shields indefinitely with a correct clock. That is the paid feature (enforcement) for free, permanently, at zero ongoing cost — it composes this bug with F9-INTEG-02.

Also worth noting for the fix: a trustworthy anchor is already in the app. `Store.refreshGrandfatheredState` fetches `AppTransaction.shared` and reads `originalPurchaseDate` (Store.swift:70-76); `AppTransaction` also carries a server-signed `signedDate`. Trial timing simply never consults either.

**Failure trace (re-derived from source by the verifier)**

1. Fresh install. User picks apps, sets 09:00-17:00, taps "Start blocking" → `ContentView.performArm()` (ContentView.swift:76-79) → `access.startTrialIfNeeded()` → `trial_start = 2026-07-01` (AccessController.swift:85-86) → `recomputeAccessState()` writes `enforcement_allowed = true` (:118); `applySchedule()` registers `.daily` with `repeats: true` (Schedule.swift:25-40).
2. Day 8 (2026-07-09). User foregrounds → scenePhase `.active` → `refreshAccess()` (ScreenTimeShieldApp.swift:101-102) → `accessState(now: 07-09, trialStart: 07-01, hasFullAccess: false, 7d)` → `604800*8/7 > trialLength` → `.expired`; persisted `enforcement_allowed = false`; trial-ended daily notification registered (AccessController.swift:126-143). UI: TrialChip reads "Trial ended · Unlock Unplug" (TrialChip.swift:19-20); tapping the app card no-ops (ContentView.swift:96); "Start blocking" opens the paywall (:71). Extension's `intervalDidStart` returns early at DeviceActivityMonitorExtension.swift:56 — no shields.
3. User opens Settings → General → Date & Time, turns off "Set Automatically", sets the date to 2026-06-20.
4. User reopens Unplug. scenePhase `.active` → `refreshAccess()` → `recomputeAccessState()` with `now = 2026-06-20`. `now.timeIntervalSince(trialStart)` = −950400 s, which is `< 604800`, so AccessControl.swift:57 returns `.trial`.
5. Persisted state after step 4: `trial_start` unchanged (2026-07-01, i.e. in the future), `enforcement_allowed = true`, trial-ended notification removed (AccessController.swift:128 runs before the `.expired` guard at :130).
6. What the user sees: `accessState == .trial` → `isExpired == false`, so the paywall stops gating every CTA; TrialChip shows `trialDaysRemaining` = ceil((604800 + 950400)/86400) = 18 → "18 days left in trial · Unlock". At 09:00 the system launches the monitor extension; `enforcementAllowed` is `true`, the guard at DeviceActivityMonitorExtension.swift:56 passes, `model.setRestrictions()` shields the apps. Identical behaviour to a paid user, with no purchase.
7. Repeat step 3 whenever needed; nothing in the code can ever detect it, because no monotonic or server-signed value is consulted for trial timing.

**Apple API semantics checked**

The claim needs only one semantic: Foundation `Date()` reflects the user-settable system time-of-day clock, with no monotonic anchor. That is the documented division of labour in Swift's clock APIs — `ContinuousClock`/`SuspendingClock` (and `mach_absolute_time`) are the monotonic sources, while `Date` is calendar/wall-clock absolute time (developer.apple.com/documentation/swift/continuousclock, swift-evolution SE-0329, which motivates the new clocks precisely because wall-clock time can jump). Apple's docs do not spell out "the user can move Date() backwards", but the code depends on nothing more than the well-established behaviour of Settings → General → Date & Time with "Set Automatically" off, which sets the same clock `Date()` reads; iOS has no per-app or Screen-Time restriction that blocks manual date changes (only MDM can lock it). No DeviceActivity/ManagedSettings/StoreKit semantic is load-bearing for the access decision — `AccessEvaluator` is pure UnplugCore logic. The only enforcement-side semantic I leaned on is that `DeviceActivitySchedule` is built from hour/minute `DateComponents` (Schedule.swift:69-70), so a date-only rollback leaves the daily interval intact; if iOS did invalidate schedules on a large clock jump, the user would merely have to tap "Start blocking" again — which the restored `.trial` state permits (ContentView.swift:71).

**Second opinion (agrees)**

_Worst realistic outcome:_ A user who wants their block gone spends ~60 seconds in Settings → Date & Time and their "unskippable" daily block silently stops applying — permanently, on a correct clock, with the app still showing "Stop blocking". The mirror trip restores a fully expired trial, so the paid product is free indefinitely.

I re-derived everything from source and the first verifier's code reading is correct on every anchor — I confirm CONFIRMED. Their Schedule.swift:76 nit is right (the file is 72 lines; the real anchors are :26-28 and :69-70). Independent checks that back them: AccessControl.swift:57 is a bare signed compare with no lower bound; :66-68 has no upper clamp; AccessController.swift:113 passes raw `Date()` and :118 rewrites the gate unconditionally; `grep -rniE "systemUptime|monotonic|mach_absolute|boottime|lastSeen|highWater"` over all .swift hits only the doc comment at AccessControl.swift:22; the only writer of `enforcement_allowed` anywhere in the repo is AccessController.swift:118 (extension only reads, :42-44/:56); "18 days" arithmetic checks out (−950400 elapsed → 1555200 remaining → ceil = 18); and no StoreKit failure can veto the recompute, since `refreshPurchasedState()` cannot throw and `refreshGrandfatheredState` swallows (Store.swift:77-80). Not in status.md — the pricing section (status.md:25-30) tracks only implementation and manual QA, so this is news.

They understated it in two ways, and mis-classed it.

(1) The exploit does NOT require living on a backdated clock. Because `enforcement_allowed` is a *persisted* app-group bool whose sole writer (AccessController.swift:118) is reachable only from `refreshAccess()` (ScreenTimeShieldApp.swift:101-102, ContentView.swift:261), purchase/restore, and QA, the round trip is: backdate → foreground once → `enforcement_allowed = true` persisted → turn "Set Automatically" back on → done. The `repeats: true` `.daily` activity is never torn down on expiry (the only `.daily` stopMonitoring is user-driven at ContentView.swift:84; :242 stops the notification schedule only), so enforcement continues indefinitely with a *correct* clock. This matters because their trace ("repeat step 3 whenever needed") implies persistently wrong device time, which on iOS costs the user TLS/cert failures, App Store, calendar and alarms — a legitimate blunter they would have had to weigh. It isn't needed. The clock only has to be wrong for the seconds the app is in the foreground.

(2) "Revenue" is not the whole consequence, and the research notes' dismissal of the other direction is wrong. qa/candidates.md:1205 says "Clock moved forward — no exploit found. It only shortens the trial ... which is self-harm", and :1209 says "Escaping an active block via the entitlement gate — not possible." Both reason only about an *already-running* block. Run the same one-line defect forward and you get an enforcement bypass of all *future* intervals: trial user armed 09:00–17:00 → Settings → Date & Time → +10 days → foreground Unplug → `recomputeAccessState()` → `.expired` → `enforcement_allowed = false` (AccessController.swift:118) → restore automatic time → never foreground Unplug again. At the next 09:00 the system launches the monitor and `intervalDidStart(.daily)` returns early at DeviceActivityMonitorExtension.swift:56 — no shields, every day thereafter — while the UI still reads "Stop blocking" because `isArmed` is re-derived from `DeviceActivityCenter().activities` (ContentView.swift:248). The only signal is the daily "Your blocks are off" push (AccessController.swift:126-143), which the user provoked deliberately. So this violates F9.2/F9.11, not just F9.9. (Caveat: forward direction bites trial users only — `hasFullAccess` short-circuits at AccessControl.swift:55. Its two components are separately reported as F9-DATE-02 :919 and F9-DATE-03 :940; the clock-triggered composition is not.)

(3) Sequencing caveat on the revenue framing: a strictly easier free ride already exists (F9-DATE-03 / F9-INTEG-02 — never reopen the app). So fixing F9-INTEG-01 in isolation buys almost no revenue. The dependency runs the other way: the moment periodic or extension-side recomputation is added to close F9-DATE-03, the clock trick becomes the *sole* remaining route, so it must be fixed together with a max-seen-`now` ratchet (or an `AppTransaction.originalPurchaseDate` anchor, which the app already reads at Store.swift:72-76).

(4) One thing neither the candidate nor the verifier flagged, and the only ordinary-user-harming variant of the same defect: `startTrialIfNeeded()` stamps raw `Date()` (AccessController.swift:86) with no sanity check. If the clock is *behind* at stamping (DFU-restored or dead-battery Wi-Fi-only device before time sync), `trial_start` lands in the past by months; once the clock corrects forward the user is instantly `.expired`, `enforcement_allowed = false`, blocks silently stop, and they never got a trial at all. The inverse accident (clock ahead at stamping) prints an arbitrary count in the chip ("372 days left in trial", TrialChip.swift:21), an F9.10 violation. Both rare; neither is covered by any candidate.

**Proof path**

Provable today, purely in `UnplugCore` (no simulator, no view extraction).

Target 1 — `AccessEvaluator.accessState(now:trialStart:hasFullAccess:trialLength:)` (UnplugCore/Sources/UnplugCore/AccessControl.swift:51-58). Test `testExpiredTrialIsNotRestoredByBackwardClock`: with `trialStart = day0` and `now = day0.addingTimeInterval(-11*86400)` (a backdated clock), assert the result is `.expired`. It currently returns `.trial`, so the test fails today and pins the fix.

Target 2 — `AccessEvaluator.trialDaysRemaining(now:trialStart:trialLength:)` (AccessControl.swift:60-69). Test `testTrialDaysRemainingNeverExceedsTrialLength`: with `now` 11 days before `trialStart`, assert `<= 7`. Currently returns 18.

Note on the eventual fix: an actual ratchet needs a persisted high-water mark, and the seam for that already exists in pure code — `KeyValueStore` (AccessControl.swift:41-46) can be backed by an in-memory fake, so a `now`-monotonicity guard is also unit-testable without touching the app target. The only parts not provable by unit test are the app-group persistence of `enforcement_allowed` and the extension read (AccessController.swift:118 / DeviceActivityMonitorExtension.swift:43), which are already exercised end-to-end by the shipped feature.

---

### `V04` · At short windows the start handle is fully occluded by the end handle

- **🔴 Important** · impact **ux** · reasoned from source
- **Feature** F3 · **Discovery IDs** F3-MAP-02
- **Already in status.md:** Not recorded. status.md mentions the slider only as shipped work — line 16 ("custom `ScheduleRangeSlider`", Block/Allow-only mode) and line 20 ("Rework the time picker — replaced the start/end `DatePicker`s with the `ScheduleRangeSlider`"). Grepping status.md for slider/handle/minGap/overlap/thumb turns up no open bug about handle occlusion or short windows. This is news.

**Verifier's reasoning**

Every cited line says what the claim says it says, and I found no guard.

- `ScreenTimeShield/ScheduleRangeSlider.swift:82-83` — inside a `ZStack(alignment: .leading)`, `handle(at: startX, …, edge: .start)` is added *before* `handle(at: endX, …, edge: .end)`. No `zIndex`, no `allowsHitTesting`, no `contentShape`, no widened hit region anywhere in the file (I read all 193 lines).
- `:26` `thumbSize = 28`; `:128` `.offset(x: cx - thumbSize / 2)` — each 28pt circle is centred on its value's x, so both handles are centred exactly on `x(for:)`.
- `:23` `minGap = 15`; `:32` `usable(width) = max(width - 48, 1)`; `:44-45` linear mapping — separation at the enforced minimum is `usable * 15 / 1440`.
- Width chain is real: `ContentView.swift:207` `.padding(.horizontal, Style.Spacing.md)` with `Style.swift:36` `md = 16`, plus `ScheduleCard.swift` `.padding(Style.Spacing.md)` (16). On a 393pt iPhone 16 in the fixed non-scrolling `VStack` (ContentView.swift:181-206): slider width 329, `usable` 281, 1pt = 5.12 min, so 15 min = 2.93pt. Claim's numbers reproduce exactly (I recomputed: 30min = 5.9pt, 60min = 11.7pt, 120min = 23.4pt).
- `:129-137` the clamp is as quoted: `end = dateAtMinute(max(m, minutes(of: start) + minGap))`, so a leftward drag on a mis-grabbed end handle at a 15-minute window recomputes the identical value every frame — no visible motion. `Model.swift:41-52` persists both via `didSet`, so the short-window state survives relaunch.

Guards I actively looked for and did not find: no `zIndex`/`contentShape`/`allowsHitTesting` in the file; no alternative time editor anywhere (grep for `DatePicker` across all Swift sources returns nothing — status.md:20 records the `DatePicker`s were *replaced* by this slider, so the slider is the only way to set start/end); the `locked` guard (`:129`, ScheduleCard.swift `.disabled(model.insideInterval)`) only blocks editing while a block is active, which is precisely the not-armed state the trace uses; and nothing prevents reaching a 15-minute window — the end handle's own clamp deliberately stops at start+15, so dragging end fully left lands you there.

Not a bypass and not a lockout: the block promise is untouched. It is an editing dead end in the not-armed state, with a multi-step workaround (lengthen the window, move start, re-shorten).

**Correction to the original claim**

Two corrections of degree, both narrowing the headline rather than the mechanism:

1. "Completely covered / cannot be edited at all" overstates it. SwiftUI hit-tests filled shapes against their *path*, not the bounding frame, so in the overlap the end circle claims only points inside its own disc. The start handle keeps a hittable left crescent: for start centre 0 and end centre at d = 2.93pt, the set {|p| <= 14} \ {|p - (d,0)| <= 14} is a crescent 2.93pt wide horizontally and up to 28pt tall. So the start handle is ~3pt wide, not zero — far under the 44pt HIG target and effectively unhittable for a thumb, but a deliberate, careful tap on the visible sliver can still grab it. The same applies to the time pills (`:117-126`): the pill overlays are part of each handle's gesture region and are the same width, so the exposed pill strip is also ~2.9pt.

2. "The slider looks broken (drags do nothing)" is only true for leftward drags. A rightward drag on the mis-grabbed end handle *does* move — the end pill visibly slides — which is a partial self-diagnosis for the user, though it is the opposite of the intent.

Accurate restatement: at any window shorter than ~143 minutes (28pt separation) the start handle is progressively occluded by the frontmost end handle, and at the enforced 15-minute minimum its reachable target shrinks to a ~3pt crescent; a touch aimed at the visually-left handle almost always lands on the end handle, whose leftward clamp makes the drag a no-op. Moving a short allow-only window earlier therefore requires the non-obvious workaround of first lengthening it.

**Failure trace (re-derived from source by the verifier)**

Preconditions: FC authorized, not armed (`model.insideInterval == false`, so `locked == false` and the drag gesture at `:129` is live), allow-only mode selected (`ScheduleCard.swift` Picker -> `model.blockOutsideWindow == true`, `inverted: true`).

1. User drags the end handle left. Each `onChanged` (`:131`) maps the absolute touch x to `m`; `:136` clamps `end = dateAtMinute(max(m, minutes(of: start) + minGap))`. The drag keeps being delivered to the grabbed handle, so the user lands on end = start + 15 = 09:15 with start = 09:00. `Model.end.didSet` (Model.swift:50-51) writes it to the app-group defaults; the state survives relaunch (Model.swift:41,48 read it back).
2. Layout now: width 329, `usable(329)` = 281, `startX = 24 + 281*540/1440 = 129.4`, `endX = 24 + 281*555/1440 = 132.3`. Start circle spans [115.4, 143.4], end circle spans [118.3, 146.3]. Both pills are centred on their own cx, same width.
3. User wants the allowed window an hour earlier, presses what looks like the left handle (anywhere at or right of x = 118.3 within the disc) and drags left. Hit testing walks the ZStack front-to-back: the end handle is the later sibling (`:83`), its filled `Circle` accepts, so `edge == .end`.
4. `onChanged` with the finger at, say, x = 100 -> `minute(forX:)` = 390 -> `end = dateAtMinute(max(390, 540 + 15))` = 09:15. Identical to the current value. `didSet` rewrites the same Date; the view re-renders pixel-identical.
5. Result the user sees: the handle under their finger does not move for the entire drag, the two overlapping pills stay 2.9pt apart and mutually illegible, and repeating the gesture behaves the same. The start time is stuck at 09:00 unless they happen to hit the ~3pt crescent at x in [115.4, 118.3] or first drag the end handle *right* past ~11:23 (143 min) to separate the handles by a full 28pt.

**Apple API semantics checked**

Two SwiftUI semantics the claim leans on, both verified rather than assumed (the candidate author did no lookup):

1. ZStack hit-test order — confirmed that topmost/last sibling is tested first and consumes the hit, so views behind never see the touch (hackingwithswift allowsHitTesting/contentShape tutorials, dev.to "SwiftUI hit testing & event propagation internals", SerialCoder zIndex writeup). This is what makes the later-added end handle (`:83`) win the overlap.

2. Shape hit-test region — confirmed SwiftUI ignores the transparent parts of a filled `Circle`, i.e. a shape hit-tests against its path unless `.contentShape(.rect)` is applied (hackingwithswift contentShape tutorial). This *sharpens* rather than refutes the finding: it means the start handle's residual target is a thin crescent rather than a 2.93 x 28 rectangle, but it also means the end disc cannot claim the crescent. `.contentShape` is absent from the file.

`.offset` moving a view's interactive region with its rendering: standard and uncontroversial here, and structurally safe in this code because `.gesture` (`:129`) is applied *after* `.offset` (`:128`), so the gesture sits on the already-offset view. Not doc-fetched; it does not carry the finding (the two handles are offset by the same modifier, so any offset/hit-region mismatch would shift both identically and leave the 2.93pt separation unchanged).

**Proof path**

Not provable today. The geometry that produces the defect — `usable(_:)` (ScheduleRangeSlider.swift:32), `x(for:width:)` (:44), `minute(forX:width:)` (:48) and the constants `thumbSize`/`minGap`/`labelInset` — is all `private` inside the SwiftUI `View` struct, and `UnplugCore` (Sources: AccessControl.swift, ScheduleMath.swift) contains no slider geometry. Occlusion/hit-test order itself is a UI-runtime property no unit test can assert regardless.

Extraction that would make it provable: move the mapping into `UnplugCore` as e.g. `SliderGeometry(width:labelInset:totalMinutes:)` exposing `x(forMinute:)`, `minute(forX:)` and `separation(minutes:)`. A pure test could then assert the real invariant — `separation(minGap) >= thumbSize` (or >= 44pt for HIG) at the production width of 329pt — which fails today: 2.93pt vs a 28pt handle. The complementary hit-test-order half needs a UI test or a manual simulator pass (no device required): set a 09:00-09:15 allow-only window, press the visually-left handle, drag left, assert the start pill still reads 9:00 AM.

---

### `V16` · purchase() collapses .pending and unverified into bare false; paywall shows no explanation

- **🔴 Important** · impact **ux** · unit-testable now
- **Feature** F9 · **Discovery IDs** F9-SK-02
- **Already in status.md:** Not recorded in status.md. The closest entry is status.md:30 — "Manual QA the trial → paywall → purchase flow — the purchase part is testable now via the local StoreKit Configuration file … only the Family-Controls bits need a real device" — which is an open testing task for this flow, not a record of this bug or its mechanism. Nothing in status.md mentions `.pending`, Ask to Buy, unverified transactions, or a missing `Transaction.updates` listener. Treat as news.

**Verifier's reasoning**

Every cited line says what the claim says it says, and I found no guard that rescues it.

- `ScreenTimeShield/Store.swift:40` — `guard case .verified(let transaction) = verification else { return false }` inside `case .success`. A charged-but-unverified success really does return bare `false`, and the only `finish()` call (`Store.swift:41`) is skipped by that guard.
- `ScreenTimeShield/Store.swift:44` — `case .userCancelled, .pending: return false`. `.pending` is genuinely indistinguishable from a cancel at the call site.
- `ScreenTimeShield/PaywallView.swift:132-142` — `buy()` assigns `errorMessage` only in the `catch`. On `ok == false` the function does literally nothing: `purchasing` flips back via the `defer`, `errorMessage` stays nil, no dismiss, no state change. The spinner disappears and the paywall is byte-identical to before the tap.
- `ScreenTimeShield/Store.swift:61` — `refreshPurchasedState()` has the same `.verified`-only filter, and `restore()` (`Store.swift:52-55`) routes through it, so the unverified path is not recoverable via Restore either; `PaywallView.swift:151` then asserts "No previous purchase found."
- I actively searched for the mitigation that would refute this: a `Transaction.updates` listener. There is none anywhere in the repo — `grep -rn "Transaction\." ScreenTimeShield/ CustomDeviceActivityMonitor/ CustomShieldAction/ CustomShieldConfiguration/ UnplugCore/` returns only `Transaction.currentEntitlements` (Store.swift:60) and `AppTransaction.shared` (Store.swift:72). So nothing observes an out-of-band completion.
- `AccessController.purchase()` (`AccessController.swift:101-105`) just forwards the Bool after `recomputeAccessState()`; it adds no error surface.

The one mitigation that does exist is partial, and it forces a correction to the claimed consequence (see correctedMechanism): the foreground refresh at `ScreenTimeShieldApp.swift:101-103` and `ContentView.swift:256-261` calls `refreshAccess()` -> `refreshPurchasedState()`, and `PaywallView.swift:120-122` dismisses on `accessState == .fullAccess`. So an approved Ask-to-Buy purchase is picked up on the next foreground transition. That makes the pending case a feedback/latency defect rather than the dead end the candidate describes, and it does not touch the missing-message defect at all.

Not in status.md as a known bug; the nearest entry is status.md:30 ("Manual QA the trial → paywall → purchase flow", still open), which is a testing gap, not this mechanism.

**Correction to the original claim**

The defect is real but the candidate overstates both cases; the honest version is narrower.

Case 1 (pending) is NOT a dead end. Once the parent approves, the transaction appears in `Transaction.currentEntitlements`, and the app re-reads that on every foreground (`ScreenTimeShieldApp.swift:101-103`) and on ContentView appear (`ContentView.swift:256-261`), after which `PaywallView.swift:120-122` dismisses the paywall. The genuine defects are (a) zero feedback at tap time — the user cannot tell an Ask-to-Buy request was submitted from a cancel, because `PaywallView.buy()` renders `false` as nothing; and (b) because there is no `Transaction.updates` listener anywhere in the app, an approval that lands while the app is in the foreground is never observed — the user sits on the paywall until they background and reopen. (b) is the actual F9.6 violation ("purchases that complete outside the foreground buy flow").

Case 2 (unverified) is real at the code level but is close to unreachable for a user in a healthy environment, and refusing to grant on `.unverified` is the deliberate and correct revenue-integrity posture (the candidate concedes this). It should not carry the finding's weight. What survives from case 2 is the same missing-message defect, plus the fact that the transaction is never finished (no `finish()` on that path, no `Transaction.updates` listener to pick it up later), so it stays in StoreKit's unfinished set forever.

So: one important, reachable bug (silent no-op + no out-of-band observation for Ask to Buy), not "charged user permanently locked out".

**Failure trace (re-derived from source by the verifier)**

Trace A (pending / Ask to Buy — the reachable one, re-derived from source):

1. Child device with Family Sharing "Ask to Buy" on. Trial expired, so `accessState == .expired` (AccessController.swift:108-111) and the CTA opens the paywall (ContentView.swift:263 `fullScreenCover`).
2. User taps "Unlock forever (price)" -> `Task { await buy() }` (PaywallView.swift:88-89).
3. `buy()` sets `errorMessage = nil`, `purchasing = true`, `defer { purchasing = false }` (PaywallView.swift:133-135) and awaits `access.purchase()`.
4. `AccessController.purchase()` -> `Store.purchase()` -> `try await product.purchase()` (Store.swift:37). StoreKit presents the Ask flow; the child taps Ask; the result is `.pending`.
5. `Store.swift:44-45` returns `false`. `AccessController.swift:103` calls `recomputeAccessState()` — `hasFullAccess` is still false, so `accessState` stays `.expired` and `enforcement_allowed` is rewritten to false (AccessController.swift:117-118, unchanged). Returns `false`.
6. Back in `buy()`: `if ok { dismiss() }` -> not taken. No `catch`. Persisted state: unchanged. Rendered state: spinner gone, `errorMessage` still nil, paywall pixel-identical to step 2. The user has no way to know an approval request was sent.
7. Parent approves 5 minutes later while the child still has Unplug open on the paywall. No `Transaction.updates` listener exists (verified by grep), so nothing fires. `isPurchased` stays false, `accessState` stays `.expired`, and `PaywallView.swift:120-122` never sees `.fullAccess`. The paywall stays up indefinitely.
8. Only when the child backgrounds and reopens the app does `scenePhase == .active` fire `refreshAccess()` (ScreenTimeShieldApp.swift:101-103) -> `refreshPurchasedState()` reads the now-verified entitlement (Store.swift:60-66) -> `isPurchased = true` -> `accessState == .fullAccess` -> paywall dismisses. A paid-for purchase is therefore reflected only after an unrelated app-switch, which is exactly what F9.6 forbids.

Trace B (unverified success — same code path, effectively unreachable in a healthy environment): `product.purchase()` returns `.success(.unverified(...))`; `Store.swift:40` returns false without `finish()`; `buy()` shows nothing; `Transaction.currentEntitlements` yields the same unverified result which `Store.swift:61` skips, so `isPurchased` stays false; tapping Restore runs `AppStore.sync()` then the same filtered refresh and lands on "No previous purchase found." (PaywallView.swift:151). I can derive this trace from source, but I cannot name a normal user action that produces `.unverified`, so I do not rest the finding on it.

**Apple API semantics checked**

Apple's own doc pages (developer.apple.com/documentation/storekit/product/purchaseresult and .../transaction/currententitlements) would not render through WebFetch — title only, no body — so I could not quote Apple directly and fell back to corroborating sources.

Confirmed via secondary sources (swiftwithmajid.com "Mastering StoreKit 2", wwdcbysundell.com "Working with in-app purchases in StoreKit 2", Apple Developer Forums thread 695483): `Product.PurchaseResult` has exactly the three cases the code switches over; `.pending` is the Ask to Buy / deferred-approval state; and the approval "arrives asynchronously via `Transaction.updates`", with the explicit warning that if you ignore the pending case "the purchase silently disappears". That is precisely the shape of this bug, and this app has no `Transaction.updates` listener at all.

NOT confirmed, and it is the one thing that would sharpen my correction: whether `Transaction.currentEntitlements` includes an approved-after-pending transaction that was never `finish()`ed. My correction (the pending case self-heals on the next foreground) assumes it does — which is what `currentEntitlements` is for, and finish-state is not documented as a filter — but I could not read it off Apple's page. If `currentEntitlements` were to exclude unfinished transactions, the pending case would be a permanent lockout and the severity would rise from ux to revenue. An SKTestSession test (askToBuyEnabled -> approve -> `refreshPurchasedState()`) settles it in one run without a device.

Also relied on: `VerificationResult.unverified` means the JWS signature could not be validated while the purchase itself completed, and `currentEntitlements` emits `VerificationResult`s (hence the `.verified`-only filter at Store.swift:61 is a deliberate choice, not an oversight). Consistent with the candidate's own reading.

Not checked and not needed: whether iOS itself shows an "Ask Sent"-style system confirmation after the child taps Ask. If it does, it softens the "zero feedback" wording but not the mechanism — the app's own state still never reflects the pending request, and defect (b) (no in-foreground observation of approval) is untouched either way.

**Proof path**

Provable today at the `Store` level in `ScreenTimeShieldTests/StoreTests.swift`, which already drives `SKTestSession` against the bundled `StoreKit.storekit` config (setUp at StoreTests.swift:18-29).

Test: set `session.askToBuyEnabled = true`, `await store.loadProduct()`, then assert `try await store.purchase() == false` while `store.isPurchased == false` — i.e. pending is collapsed into the same Bool as `.userCancelled`, so no caller can distinguish them. Then approve the pending transaction via `SKTestSession.approveAskToBuyTransaction(identifier:)` and assert that `store.isPurchased` is STILL false until an explicit `await store.refreshPurchasedState()` is called — that pins the absence of a `Transaction.updates` listener, which is the F9.6 violation. A companion test can assert `Transaction.unfinished` is non-empty after the approved-but-never-finished purchase (F9.7).

Not provable today: the "paywall shows no message" half. `errorMessage` is `@State` private to `PaywallView` (PaywallView.swift:19) and `buy()` is a private view method (PaywallView.swift:132), so proving it would need the buy-result-to-message mapping extracted into a pure helper in `UnplugCore` (e.g. a `PurchaseOutcome` enum returned by `Store.purchase()` in place of `Bool`, mapped to display text by a testable function). That extraction is also the natural fix.

---

### `V19` · Nothing tears down the registered .daily schedule on expiry -> app sits 'armed but unenforced'

- **🔴 Important** · impact **ux** · needs device
- **Feature** F9 · **Discovery IDs** F9-DATE-02
- **Already in status.md:** Not recorded in status.md. Grepped for expiry/armed/drain/gate: the only adjacent open item is line 30, "Manual QA the trial → paywall → purchase flow" (unchecked, and it scopes the *purchase* path, not expiry teardown). Line 16's redesign entry documents the "explicit arm/disarm model" and the "schedule edit disarms while inactive" fix, but says nothing about disarming on expiry. Line 29 confirms the QA menu (and hence `qaResetToFreshInstall`, the only other code that stops all activities) is hidden in production, which strengthens rather than mitigates the finding.

**Verifier's reasoning**

Every cited line says what the claim says it says, and I found no guard anywhere that tears the schedule down at expiry.

Verified citations:
- `ScreenTimeShield/AccessController.swift:112-120` — `recomputeAccessState()` does exactly two things plus a notification update: publishes `accessState` and writes `kv.setBool(accessState != .expired, forKey: AppGroupKeys.enforcementAllowed)`. No `Schedule.stopMonitoring`, no `model.isArmed = false`.
- Exhaustive grep for teardown (`grep -rn "stopMonitoring|isArmed|is_armed" --include=*.swift`) returns only: `ScreenTimeShield/Schedule.swift:34,53,63-65` (internal stop-before-start inside `setSchedule`/`setNotificationSchedule`), `ScreenTimeShield/ContentView.swift:84` (user-tapped `stop()`), `ScreenTimeShield/ContentView.swift:242` (notifications toggle, `.notificationSchedule` only), and `ScreenTimeShield/AccessController.swift:188,201` (`qaResetToFreshInstall`, unreachable in production per status.md line 29). So the only production teardown of `.daily` is a user tap.
- `ScreenTimeShield/ContentView.swift:60` — `guard model.isArmed, !isExpired, !model.isEmpty() else { return }` gates re-registration only; it cannot unregister.
- `ScreenTimeShield/ContentView.swift:248` — `model.isArmed = DeviceActivityCenter().activities.contains(.daily)` re-derives armed=true on every launch from the still-registered activity, so the armed UI is durable, not just in-memory.
- `ScreenTimeShield/Model.swift:32` — `@AppStorage("is_armed", store: UserDefaults(suiteName: "group.screentimeshield"))`, persisted as claimed.
- `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:42-44, 53-59` — gate read and hard `return` before `setRestrictions()`; the comment at `:54-55` ("The app also stops scheduling on expiry (gate-and-drain)") asserts behaviour that does not exist.
- UI consequence re-derived: `ContentView.swift:39` → `primaryTitle == "Stop blocking"`, `ContentView.swift:46` → `primaryDisabled == false`. `StatusBanner.swift:32` keys off `insideInterval` only, and `insideInterval` is never set because the extension returned early — so the banner reads "Block inactive" while the CTA claims a configured block.
- No `onChange(of: access.accessState)` exists in `ContentView` and nothing in `ScreenTimeShieldApp.swift:95-104` does teardown; the only expiry-time side effect is the daily reminder at `AccessController.swift:126-143`, which requires notification permission and does not change app state.

Mitigations I looked for and rejected as insufficient to refute: `TrialChip.swift:14-27` does render "Trial ended · Unlock Unplug", but it is a footnote-sized chip and does not contradict the "Stop blocking" CTA; `disarmIfArmedInactive()` (`ContentView.swift:90-92`) only fires on a user schedule edit; there is no launch-time paywall (`showPaywall` is only set from CTA taps at `:71`, `:102`, `:187`).

Not a bypass and not revenue loss — the user gets nothing they didn't pay for. The harm is an incoherent, misleading state on the core screen of an app whose whole promise is "you are protected": the app presents as armed indefinitely while enforcing nothing.

**Correction to the original claim**

Two corrections to the claim's framing, neither of which defeats it:

1. The invariant it is filed against (F9.11) is about "expiry that lands mid-block", and that specific case is actually handled correctly: the gate is only read in `intervalDidStart` (DeviceActivityMonitorExtension.swift:56), so a block that was already applied before expiry runs to its natural `intervalDidEnd` and is cleared (:74-78) — F9.11's first branch ("continues to its natural end") is satisfied. The real defect is the *steady state after* expiry, which the candidate's own trace describes correctly: the `.daily` registration is never withdrawn and `is_armed` is never cleared, so the app is permanently armed-but-unenforced from the next window onward. The claim's mechanism is right; only the "mid-block" label is off.

2. The trace has an unstated precondition the claim's mechanism section glosses but its trace does honour: the user must foreground the app at least once after the trial lapses, because `recomputeAccessState()` is the only writer of `enforcement_allowed`. Without that foreground the gate stays `true` and enforcement actually continues (the separate F9-DATE-03 defect). So V19 and F9-DATE-03 are mutually exclusive on the same device-session: one or the other fires, never both.

Also worth flagging for the author: `applySchedule()` skipping while expired means the `.notificationSchedule` is likewise left registered, so refocus notifications (`eventDidReachThreshold`, :96-107) keep firing for an expired user — they are not gated by `enforcementAllowed` at all.

**Failure trace (re-derived from source by the verifier)**

Preconditions: trial user, Screen Time authorized, no purchase.

1. Day 1 — user picks apps and taps "Start blocking": `start()` (ContentView.swift:70-74) → not expired → `performArm()` (:76-80) → `startTrialIfNeeded()` writes `trial_start = day 1` (AccessController.swift:84-90); `model.isArmed = true` persists `is_armed = true` into `group.screentimeshield` (Model.swift:32); `applySchedule()` (:59-68) → `Schedule.setSchedule(..., repeats: true)` → `DeviceActivityCenter().startMonitoring(.daily, during: 22:00–07:00)` (Schedule.swift:24-40), plus `.notificationSchedule`.

2. Day 8 — user foregrounds the app once: `scenePhase == .active` → `refreshAccess()` (ScreenTimeShieldApp.swift:101-103) → `recomputeAccessState()` (AccessController.swift:112-120) → `AccessEvaluator.accessState` returns `.expired` (now − trialStart ≥ trialLength, UnplugCore AccessControl.swift) → `enforcement_allowed = false` in the app group. Nothing else runs. `.daily` is still registered; `is_armed` still true.

3. Same session UI: `onAppear` sets `model.isArmed = DeviceActivityCenter().activities.contains(.daily)` → true (ContentView.swift:248). Screen shows: StatusBanner "Block inactive", TrialChip "Trial ended · Unlock Unplug", primary CTA "Stop blocking" and enabled (:39, :46).

4. Day 8, 22:00 — system launches the monitor extension: `intervalDidStart(for: .daily)` → `activity.rawValue == "daily"` → `guard enforcementAllowed` reads the cached `false` (DeviceActivityMonitorExtension.swift:42-44) → prints and returns (:56-59). No `Model.setRestrictions()`, no shields, `inside_interval` stays false.

5. Day 9, 07:00 — `intervalDidEnd(for: .daily)` → `clearRestrictions()` on an empty store, `insideInterval = false`. No-op.

6. Steps 4–5 repeat every night indefinitely (repeating `DeviceActivitySchedule`, never unregistered). Persisted state: `is_armed = true`, `.daily` ∈ `DeviceActivityCenter().activities`, `enforcement_allowed = false`, `inside_interval = false`. What the user sees: restricted apps open normally at 23:00, and the app's main screen offers to "Stop blocking" a block that will never run — surviving cold launch and reboot because step 3 re-derives `isArmed` from the live registration.

**Apple API semantics checked**

Checked the one semantic the claim leans on: `DeviceActivityCenter.activities`. Apple's docs (fetched via developer.apple.com/tutorials/data/.../deviceactivitycenter/activities.json) define it as "The activities that the application's extension currently monitors" — i.e. it reflects live registrations, which is exactly how `ContentView.swift:248` uses it to resync `isArmed`, and which confirms a repeating activity keeps being reported until `stopMonitoring`. No documented auto-expiry of a repeating `DeviceActivitySchedule` exists, and the app already depends on that persistence for its normal operation, so the claim introduces no new assumption. (`stopMonitoring().json` 404s on the doc CDN; not load-bearing — the claim's point is that stopMonitoring is never called.) Nothing here turns on StoreKit 2, Calendar, or cross-process `@AppStorage` observation: the gate is read with a plain `UserDefaults.object(forKey:)` at read time in the extension (:42-44), not observed.

**Proof path**

Not provable today. The expiry-time policy lives in `AccessController.recomputeAccessState()` (private, `@MainActor`, reaches StoreKit + `UNUserNotificationCenter` + app-group defaults) and the teardown lives in `ContentView.stop()` (a SwiftUI view method calling `DeviceActivityCenter` directly, which needs the Family Controls entitlement). SKTestSession does not help — nothing here depends on a transaction; the missing piece is a DeviceActivity call.

What extraction would make it testable: (a) a pure decision function in `UnplugCore`, e.g. `AccessTransition.shouldDisarm(previous: AccessState, next: AccessState, isArmed: Bool) -> Bool`, asserting `(.trial, .expired, true) == true` and `(.expired, .fullAccess, true) == false`; and (b) a `ScheduleControlling` protocol (`startDaily`/`stopMonitoring(_:)`) injected into `AccessController` so a fake can assert that a `.trial → .expired` recompute with `is_armed == true` calls `stopMonitoring([.daily, .notificationSchedule])` and writes `is_armed = false`. With (b) in place the whole trace is assertable in a plain XCTest with no device.

Device is still needed for end-to-end confirmation that `DeviceActivityCenter().activities` keeps reporting `.daily` and that `intervalDidStart` is delivered to the extension nightly.

---

### `V24` · qa_force_full_access is read by release builds and can never be cleared once set

- **🟡 Nit** · impact **revenue** · reasoned from source · hit **rare — zero App Store users; only the developer's own device plus any tester of the pulled build 13 who deliberately flipped "Force full access"**
- **Feature** F9 · **Discovery IDs** F9-INTEG-04
- **Already in status.md:** Anticipated but not recorded as an open bug. `qa/invariants.md:73` (F9.12) names this exact key — "The QA overrides (`qa_force_full_access`, injected trial dates) cannot affect a production user, and a value left behind by a QA build does not silently grant access" — so the concern is pre-registered; this candidate is the demonstration that the invariant is violated. `status.md:29` records the opposite conclusion as a closed decision: "decided that hiding the QA/Debug menu entry (commented out in `SettingsView`) is sufficient; not stripping the rest of the scaffolding … `qaResetToFreshInstall`/`QAMenuView` are only reachable from the now-hidden entry. So it's all inert/unreachable in production." That holds for the methods and is wrong for the persisted value, so this finding is news against status.md, not a duplicate of it.

**Verifier's reasoning**

Every cited line says what the claim says it says, and I found no guard.

- `/Users/stevendiviney/code/ScreenTimeShield/ScreenTimeShield/AccessController.swift:69` — `var hasFullAccess: Bool { storeKit.hasFullAccess || qaForceFullAccess }`. Verbatim. No `#if DEBUG`, no sandbox/TestFlight receipt check, no `skipFC` gate (that env-var hook at `:28` guards only Family Controls, not this).
- `AccessController.swift:151-154` — `qaForceFullAccess` getter is `kv.bool(forKey: AppGroupKeys.qaForceFullAccess)`; `AppGroupStore.swift:19` = `"qa_force_full_access"`; `AppGroupStore.swift:24` binds to `UserDefaults(suiteName: "group.screentimeshield")`. Absent key reads `false`, so a clean device is unaffected — the exposure is strictly a *left-behind* `true`.
- `AccessController.swift:146-148` — comment confirms "Present in release builds (TestFlight has no DEBUG)". `QAMenuView.swift:6-7` repeats it.
- Writers: repo-wide grep for `qa_force_full_access|qaForceFullAccess|qaSetFullAccess` returns only `AccessController.swift:69/151-153/174-178` and `QAMenuView.swift:44-45`. The only clearers are `qaSetFullAccess(false)` and `qaResetToFreshInstall()` (`AccessController.swift:186-205`, whose `removePersistentDomain` is at `:191`). Both live inside `QAMenuView`, presented only by `SettingsView.swift:38-41` from `showQAMenu`, whose sole writer is the commented-out button at `SettingsView.swift:26-28` (I re-read the file; lines 25-29 are comments). No URL scheme, no other entry. So in the shipping build the key is readable and unclearable — write-once-and-stuck, exactly as claimed.
- Consequence chain verified: `recomputeAccessState()` (`AccessController.swift:112-118`) → `AccessEvaluator.accessState` returns `.fullAccess` on `hasFullAccess` before any trial math (`UnplugCore/Sources/UnplugCore/AccessControl.swift:55`) → `enforcement_allowed = true`, and `ContentView.swift:186` (`if access.accessState != .fullAccess`) suppresses the TrialChip, so no paywall entry point remains. Trial dates become irrelevant.

Reachability is real, not hypothetical: `git log -- ScreenTimeShield/SettingsView.swift` shows the live QA Section existed from `a3e4c07` until `7e88b58` hid it, and `1f7e78e` ("bump build version", CURRENT_PROJECT_VERSION 12→13, MARKETING_VERSION 1.3) falls *inside* that window — i.e. a distributable build 13 carried the live toggle. The next bump (`3bfe858`, build 14) is after the hide.

I tried three refutations and all failed: (1) no `#if DEBUG`/sandbox guard anywhere near line 69; (2) no migration or one-shot cleanup — grep for `removePersistentDomain|removeObject(forKey` across all Swift finds exactly one hit, the unreachable QA one; (3) the claim does not actually need the contested delete+reinstall behaviour, so that weak link can be discarded (see correctedMechanism).

What keeps this from being "important": no App Store user can reach the setting state. It requires a device that ran a build in the a3e4c07..7e88b58 window *and* a human deliberately flipping "Force full access". That is the developer's own device plus any external tester of build 13 — and the practical cost is a foregone $0.99 on a handful of devices, in an app slated to go free after 1.3. The flag also grants *more* enforcement (`enforcement_allowed = true`), so it is not a block bypass. The sharper real cost is a QA hazard: on any such device the paywall/trial/grandfathering paths are permanently unobservable and silently report `.fullAccess`, which can mask other regressions during this very QA pass.

**Correction to the original claim**

The claim is right; two details in its framing should be tightened.

1. The failure trace does not need app-group persistence across delete+reinstall (the part the author himself flagged as unverified). The plain **update** path is sufficient and is standard, documented iOS behaviour: everything in the app container, including app-group `UserDefaults`, is preserved across an app update. Drop step 2's reinstall hedge and the claim stands on certain ground.

2. "Every device that ever ran a QA build" overstates it. The key defaults to `false` (`AppGroupStore.bool` → `UserDefaults.bool`), so only devices where someone *explicitly toggled* "Force full access" on and never toggled it back are affected — the developer's device plus any external tester of build 13. Anyone who left the toggle off, or turned it off before updating, is clean.

3. Add the consequence the claim misses: the affected device is not just free-riding, it is permanently blind to the trial/paywall/grandfathering code paths, so device-based verification of pricing behaviour on it silently passes as `.fullAccess`. That, not the lost $0.99, is the reason to fix it.

Note also that `status.md:29`'s stated posture ("`qaResetToFreshInstall`/`QAMenuView` are only reachable from the now-hidden entry. So it's all inert/unreachable in production") is true of the *methods* but false of the *persisted value* — hiding the entry removed the only eraser along with the only writer.

**Failure trace (re-derived from source by the verifier)**

Re-derived from source, using the update path only (no reinstall assumption):

1. Tester runs a build from the `a3e4c07..7e88b58` range — concretely build 13, cut by `1f7e78e` inside that window. `SettingsView.swift` at that commit has the QA Section live (uncommented), so Settings shows "QA / Debug" → `showQAMenu = true` → `.sheet` presents `QAMenuView` (`SettingsView.swift:38-41`).
2. Tester flips `Section("Entitlement")` → "Force full access" on (`QAMenuView.swift:43-46`) → `access.qaSetFullAccess(true)` → `AccessController.swift:175` sets `qaForceFullAccess = true` → `AccessController.swift:153` → `defaults.set(true, forKey: "qa_force_full_access")` on `UserDefaults(suiteName: "group.screentimeshield")` (`AppGroupStore.swift:24`). Then `:176` recomputes: `accessState = .fullAccess`, `enforcement_allowed = true`.
3. That device updates to the shipping 1.3 build (build 14+, `3bfe858` onward, QA Section commented out at `SettingsView.swift:25-29`). The app container — and with it the app-group defaults — is preserved across the update, so `qa_force_full_access` is still `true`.
4. First foreground of the shipping build: `refreshAccess()` (`AccessController.swift:93-99`) → `storeKit.refreshPurchasedState()` sets `isPurchased = false`, `refreshGrandfatheredState` sets `isGrandfathered = false`, so `storeKit.hasFullAccess == false` (`Store.swift:20`) → but `AccessController.hasFullAccess` ORs in `qaForceFullAccess == true` (`:69`) → `true`.
5. `recomputeAccessState()` (`:112-118`): `AccessEvaluator.accessState` short-circuits at `AccessControl.swift:55` → `.fullAccess`; writes `enforcement_allowed = true`; `updateTrialEndedNotification()` returns at `:130` (not `.expired`).
6. Persisted state afterwards: `qa_force_full_access = true`, `enforcement_allowed = true`, `accessState = .fullAccess`. No code compiled into the shipping build can reach `qaSetFullAccess(false)` or `qaResetToFreshInstall()`, so this is terminal.
7. What the user sees: `ContentView.swift:186` (`if access.accessState != .fullAccess`) omits the `TrialChip` entirely, removing the only paywall entry point from the main screen; blocking works fully and forever; `trial_start` is never consulted. Indistinguishable from a paid user, with no in-app path back to the trial/paywall state.

**Apple API semantics checked**

Verified the one semantic the corrected trace relies on: app-group `UserDefaults` survives an app **update**. Apple Developer Forums thread 815779 states that user defaults live in the app's container and "everything in your app's container is preserved"; the only reported counter-case (forums thread 821222) is an *unintended container recreation* bug that would clear the flag, i.e. it cuts against the bug rather than for it. So the update path is confirmed. Sources: [forums/thread/815779](https://developer.apple.com/forums/thread/815779), [forums/thread/821222](https://developer.apple.com/forums/thread/821222).

Deliberately did NOT try to settle the delete+reinstall question the author raised — it is contested and, per correctedMechanism, unnecessary: the update path alone carries the trace, so the claim survives either answer.

No DeviceActivity / ManagedSettings / StoreKit 2 / Calendar / cross-process `@AppStorage` semantics are load-bearing here — `hasFullAccess` is a synchronous same-process read of a suite `UserDefaults`.

Unverifiable from the repo (and correctly flagged as such by the author): whether build 13 actually reached any external TestFlight tester, and whether the toggle was ever left on. That is a distribution fact; it bounds blast radius but not the code path.

**Second opinion (agrees)**

_Worst realistic outcome:_ A handful of developer/tester devices keep the $0.99 lifetime unlock for free, with the trial/paywall permanently invisible on those devices. Blocking still works (the flag sets enforcement_allowed = true), so nothing the user relies on breaks and the product promise is untouched. On the realistic population the flag grants nothing they didn't already have, because those devices are grandfathered anyway.

Verdict and severity: I agree. Every cited line is verbatim — `/Users/stevendiviney/code/ScreenTimeShield/ScreenTimeShield/AccessController.swift:69` (`var hasFullAccess: Bool { storeKit.hasFullAccess || qaForceFullAccess }`), the getter/setter at `:151-153`, `AppGroupStore.swift:19/24`, the QA-only writers at `AccessController.swift:174-178` / `QAMenuView.swift:43-46`, the commented entry at `SettingsView.swift:25-29`. My own repo-wide grep (swift + pbxproj) finds no other reader/writer, no `#if DEBUG`, no URL scheme, no migration. `1f7e78e` (2026-06-18, build 12→13) does sit between `a3e4c07` and `7e88b58` (2026-06-19), and `3bfe858` (build 13→14) is after the hide, so a build carrying the live toggle did reach App Store Connect. Absent key → `bool(forKey:)` = false, so ordinary users are untouched. Mechanism confirmed.

Two things they got wrong, both of which cut the consequence further:

(1) They missed the grandfathering mitigation, which makes the revenue delta ~zero on the population that can actually hold the flag. Any device carrying `qa_force_full_access = true` must have run a build from the `a3e4c07..7e88b58` window, i.e. had the app installed on or before 2026-06-19. `PricingConfig.cutoverDate` is 2026-06-25 (`UnplugCore/Sources/UnplugCore/AccessControl.swift:27`), so `refreshGrandfatheredState` (`ScreenTimeShield/Store.swift:70-81`) → `Grandfather.isGrandfathered` (`AccessControl.swift:74-77`) already returns true for that Apple ID, `storeKit.hasFullAccess` is true on its own (`Store.swift:20`), and it is recomputed on every foreground (`AccessController.swift:93-99`, driven from `ScreenTimeShieldApp.swift:95-102`), so it does not decay. The argument gets *stronger*, not weaker, if the release slips further and the dev pushes the cutover out per `status.md:28`. The only residual leak is a TestFlight-only tester who never App-Store-downloaded before cutover and later does a fresh App Store install (fresh, post-cutover `originalPurchaseDate`) while the app-group container survives — a genuinely narrow path worth ~$0.99.

(2) "Terminal / can never be cleared" is overstated for the devices that have it. It is only unclearable on a device whose *only* binary is the App Store one — and an App Store-only device never had the toggle to set it. Every device that can hold the flag is one the developer or a tester controls, and `status.md:29` documents the recovery itself: "Re-enable QA by uncommenting the Section in `SettingsView`." One uncommented line and a rebuild clears it via `qaSetFullAccess(false)`.

Class: "revenue" is the wrong label. Revenue at risk is $0.99 × (dev + testers of a build that was pulled from review on 2026-06-19 and never released, `status.md:33-34`), on an app already slated to go Free in all territories (`status.md:35`). This is leftover-debug-state hygiene, not a revenue bug. Not a safety bug either — the flag writes `enforcement_allowed = true` (`AccessController.swift:117`), so it only ever grants more enforcement.

Already known, partially: `status.md:29` records the decision that hiding the entry makes the QA scaffolding "inert/unreachable in production". The candidate's contribution is the narrow observation that unreachable code does not clean up values it already wrote — that specific point is news, the reachability analysis is not.

Understated adjacent risk (the sharper half of the same mechanism, and worth more triage attention than this one): `qaExpireTrial` (`AccessController.swift:163-167`) writes a backdated `trial_start`, which is equally stuck — `startTrialIfNeeded` (`:85-91`) is a no-op when non-nil, and nothing else can clear it in the shipping build. That direction yields `.expired` → `enforcement_allowed = false` → `DeviceActivityMonitorExtension.swift:56` refuses to apply shields, i.e. blocks silently stop working. Same population, but the failure mode breaks the product promise instead of giving away a dollar. If only one of these gets fixed, it should be that one.

**Proof path**

Not provable in UnplugCore today, and SKTestSession is irrelevant (no StoreKit involved). The pure layer is already fine: `AccessEvaluator.accessState(hasFullAccess: true, …) == .fullAccess` is correct behaviour, not the bug. The bug lives in the *source* of `hasFullAccess` — `AccessController.swift:69` reads the app-group key directly, and `AccessController` is a `@MainActor` singleton in the app target that constructs a real `Store()` and touches `AuthorizationCenter.shared` in `init`, with a hard-coded `AppGroupStore()`.

Extraction needed: give `AccessController` an injectable `KeyValueStore` (it already has the `kv` seam, just not injectable, and `KeyValueStore` at `AccessControl.swift:42-47` has no `bool`/`setBool` — those live only on the concrete `AppGroupStore`), or better, move the entitlement resolution into a pure function in UnplugCore, e.g. `AccessEvaluator.hasFullAccess(purchased:grandfathered:qaOverride:isReleaseBuild:)`. Then the test is one line: with `qaOverride == true` and `isReleaseBuild == true`, expect `false`.

Cheaper interim check that needs no extraction: an app-target test that writes `true` to `qa_force_full_access` in `UserDefaults(suiteName: "group.screentimeshield")` and asserts `AccessController.shared.hasFullAccess == false` — that runs in the simulator host app, no device.

---

### `V06` · Allow-only mode can hand DeviceActivity a blocked interval shorter than the 15-minute minimum

- **🟡 Nit** · impact **ux** · unit-testable now
- **Feature** F3 · **Discovery IDs** F3-MODE-02
- **Already in status.md:** Partially. status.md line 8 already records the swallowed-error half as an open note: "Note: `Schedule` still swallows `startMonitoring` errors (`catch { print }`) — likely culprit if a block ever silently fails to register; surface/validate next." The producer side — that allow-only inversion can generate a sub-15-minute interval, and that `minGap` never bounds the registered interval — is not recorded anywhere in status.md. qa/invariants.md F3.7 and F3.4 name the invariants but not this failure.

**Verifier's reasoning**

Every cited line says what the claim says. `ScheduleRangeSlider.swift:23` `minGap = 15` and the clamps at `:134-136` constrain only the *picked window* length; there is no upper bound on the window and no check anywhere on the length of the interval that is actually registered (grep for `minGap|1425|intervalTooShort` across the repo returns only those three slider lines). `Model.swift:36-38` `blockedInterval` returns `(start: end, end: start)` in allow-only mode, so the registered interval is `1440 − windowLength`. `ContentView.swift:59-68` `applySchedule()` passes it straight to `Schedule.setSchedule`, which builds the `DeviceActivitySchedule` and calls `center.startMonitoring` after `center.stopMonitoring([.daily])`, with the throw caught and only `print`ed (`Schedule.swift:26-39`). `ContentView.swift:78` sets `model.isArmed = true` before `applySchedule()`, and `Schedule`'s work is dispatched to a background queue with no result path back, so a failure cannot be observed. The risk gate does not catch it: `ScheduleMath.freeMinutes` returns the window length in allow-only mode (`UnplugCore/Sources/UnplugCore/ScheduleMath.swift:29-32`), so a 1439-minute allow window scores free = 1439 and `isRiskyToArm()` (`ContentView.swift:124-132`) returns false — no confirmation.

Reachability holds two ways and I found no guard. (1) Legacy data: the shipped pre-redesign build bound `model.start`/`model.end` to unconstrained hour/minute `DatePicker`s (`git show 8c5aca7^:ScreenTimeShield/ContentView.swift:109-113`) and persisted them under the same `"start"`/`"end"` keys in the same `group.screentimeshield` suite (`git show 8c5aca7^:ScreenTimeShield/Model.swift:30-41`). v1.3 reads them verbatim at `Model.swift:40-52`; the only writers of those properties are the slider bindings and `AccessController.swift:195-196` (QA reset) — there is no migration or clamp. (2) In-app: I ran `Calendar.current.date(bySettingHour: 24, minute: 0, second: 0, of: Date())` and it returns nil, so `dateAtMinute(1440)` (`ScheduleRangeSlider.swift:39-42`) falls back to `Date()`; dragging the end handle to the right edge of the track between 23:45 and 23:59 therefore sets `end = now`, and with `start` at 00:00 the blocked interval is under 15 minutes.

Two corrections (see correctedMechanism): the StatusBanner text is not a symptom, and the mechanism is not confined to allow-only mode. Severity: I rate this a nit *as framed*, because in the configuration described the user asked for at most a 15-minute block, so the lost enforcement is ≤15 min/day plus a CTA that lies until the next cold launch. The genuinely important half is the shared root cause — no validation of the registered interval plus a swallowed `startMonitoring` error — which on the Block-mode route kills a block the user actually wanted.

**Correction to the original claim**

(a) The claim's trace cites StatusBanner reading "Block inactive" as part of the symptom; it is not. `StatusBanner.swift:33` keys only off `model.insideInterval`, so it reads "Block inactive" for every armed-but-not-yet-active block, healthy or not. The only false signal is the primary CTA reading "Stop blocking" and being enabled (`ContentView.swift:37-48`) — which is exactly why the user has no tell: the failed state is pixel-identical to a correctly armed state.

(b) The mechanism is not allow-only-specific. The same missing validation is reachable in Block mode — the more damaging mode, since there the registered interval *is* the block the user wants. `ScheduleRangeSlider.swift:136` applies the clamp to the minute value before converting (`end = dateAtMinute(max(m, minutes(of: start) + minGap))`), so when `m == 1440` the clamp evaluates to 1440, `dateAtMinute(1440)` returns nil (verified) and `end` becomes `Date()`. With `start = 09:00` and a drag to the right edge at 09:05, Block mode registers a 5-minute interval — under the documented minimum, minGap bypassed, and (because `stopMonitoring([.daily])` runs first at `Schedule.swift:34`) the previous schedule is already torn down when the start throws. If the clock is *before* `start`, e.g. 08:00, `end` becomes 08:00 and Block mode instead registers a 23-hour wrapping block. The fix that closes the claimed bug (validate the derived interval and surface `startMonitoring` failures instead of `catch { print }`) is the same fix that closes these.

(c) "User impact" as written ("the user believes they are protected and is not") overstates the allow-only case: an allow window of 23h45m+ means the user requested at most 15 minutes of blocking per day, so the enforcement actually lost is ≤15 min/day.

**Failure trace (re-derived from source by the verifier)**

1. Legacy user on the shipped pre-redesign build sets Schedule Start 00:00 / Schedule End 23:59 with the unconstrained DatePickers (git show 8c5aca7^:ScreenTimeShield/ContentView.swift:109-113). Values land in group.screentimeshield under "start"/"end".
2. They install v1.3. Model init reads both back verbatim (/Users/stevendiviney/code/ScreenTimeShield/ScreenTimeShield/Model.swift:40-52). No migration or clamp exists (only /Users/stevendiviney/code/ScreenTimeShield/ScreenTimeShield/AccessController.swift:195-196 ever rewrites them).
3. They tap "Allow only these hours" (/Users/stevendiviney/code/ScreenTimeShield/ScreenTimeShield/ScheduleCard.swift:16-19) -> onChange(of: model.blockOutsideWindow) (ContentView.swift:235) -> disarmIfArmedInactive() -> stop() (ContentView.swift:90-92). Caption: "Blocking all day except this window".
4. They tap "Start blocking" -> start() (ContentView.swift:70-74) -> isRiskyToArm() (ContentView.swift:124-132): free = ScheduleMath.freeMinutes(windowStart: 0, windowEnd: 1439, blockOutsideWindow: true) = 1439 (UnplugCore/Sources/UnplugCore/ScheduleMath.swift:29-32) > 30; activeNow = windowContains(now, 1439, 0) = false outside 23:59 -> not risky -> performArm() with no confirmation dialog.
5. performArm() sets model.isArmed = true (ContentView.swift:78), then applySchedule() (ContentView.swift:59-68) reads model.blockedInterval = (start: 23:59, end: 00:00) (Model.swift:36-38) and calls Schedule.setSchedule(start: 23:59, end: 00:00, repeats: true).
6. Schedule.swift:26-36 builds DeviceActivitySchedule(intervalStart: {h:23,m:59}, intervalEnd: {h:0,m:0}, repeats: true) — a 1-minute interval — dispatches to its serial queue, calls center.stopMonitoring([.daily]) and then try center.startMonitoring(...). Apple documents a fifteen-minute minimum, so this throws (intervalTooShort, or invalidDateComponents); Schedule.swift:37-39 prints and returns. The notification schedule (00:00 -> 23:59, 1439 min) registers successfully at Schedule.swift:43-59.
7. Resulting persisted state: is_armed = true in the app group, no .daily activity in DeviceActivityCenter, ManagedSettingsStore untouched, inside_interval false.
8. What the user sees: the primary CTA reads "Stop blocking" and is enabled (ContentView.swift:39, :46) — indistinguishable from a correctly armed, not-yet-active block. intervalDidStart never fires, so no app is ever shielded. On the next cold launch model.isArmed = DeviceActivityCenter().activities.contains(.daily) = false (ContentView.swift:248) and the CTA silently reverts to "Start blocking" with no explanation.

Alternative route with no legacy data: I verified Calendar.current.date(bySettingHour: 24, minute: 0, second: 0, of: Date()) returns nil, so dateAtMinute(1440) (ScheduleRangeSlider.swift:39-42) yields Date(). Drag start to the left edge (00:00) and the end handle to the right edge of the track at 23:52 -> end = 23:52 -> allow window 1432 min -> blocked interval 8 min -> steps 4-8 as above. Also reachable by releasing the end handle in the ~1pt band at 23:50/23:55.

**Apple API semantics checked**

Apple docs, fetched via the documentation JSON endpoint (developer.apple.com/tutorials/data/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort.json): abstract "The activity's schedule has an interval that is too short", discussion "The minimum interval length for monitoring device activity is fifteen minutes." Confirmed the API surface directly in the SDK: /Applications/Xcode.app/.../iPhoneOS.sdk/System/Library/Frameworks/DeviceActivity.framework/Modules/DeviceActivity.swiftmodule/arm64e-apple-ios.swiftinterface:143-166 — MonitoringError has cases excessiveActivities, intervalTooLong, intervalTooShort, invalidDateComponents, unauthorized, and startMonitoring(_:during:events:) throws. Also verified locally (swift snippet, not a project build) that Calendar.current.date(bySettingHour: 24, minute: 0, second: 0, of: Date()) == nil, which is what makes the in-app near-midnight route work. What I could NOT confirm without a device: how the system measures the length of a wrapping component pair such as (23:59 -> 00:00), i.e. whether it is rejected as intervalTooShort, rejected as invalidDateComponents, or accepted. This does not change the consequence — both rejection paths throw and hit the same swallowed catch. The only outcome that would make the claim harmless is the system silently accepting a sub-minimum interval, which contradicts the documented minimum. A device run (arm allow-only with a 23h50m window, then check DeviceActivityCenter().activities) would settle it definitively.

**Proof path**

The producer half is provable today with no view extraction. ScreenTimeShieldTests already does `@testable import Unplug` (ScreenTimeShieldTests/ScreenTimeShieldTests.swift:9), and the derived interval lives on a plain ObservableObject: set `model.blockOutsideWindow = true`, `model.start = 00:00`, `model.end = 23:59`, then assert that the minute distance from `model.blockedInterval.start` to `.end` (mod 1440, matching what `Schedule.components(from:)` keeps — hour+minute only) is >= 15. That fails today with 1. Cleaner: add a pure `ScheduleMath.blockedMinutes(windowStart:windowEnd:blockOutsideWindow:)` next to `freeMinutes` and unit-test it in UnplugCoreTests/ScheduleMathTests.swift for (0, 1439, allowOnly) == 1 and (0, 1430, allowOnly) == 10, then have `applySchedule()` gate on it. What a unit test cannot prove is the consequence half — that `startMonitoring` throws and the failure is invisible while `isArmed` stays true. That needs a device (or at least a simulator with Screen Time) because `DeviceActivityCenter` is not fakeable here, and `applySchedule()` is a private method on a SwiftUI View, so asserting "isArmed true while activities is empty" would require lifting the arm sequence out of ContentView into a testable coordinator.

---

### `V17` · Restore asserts 'No previous purchase found' when AppStore.sync() actually failed (offline)

- **🟡 Nit** · impact **ux** · reasoned from source
- **Feature** F9 · **Discovery IDs** F9-SK-03
- **Already in status.md:** Not recorded in status.md as a known bug. The nearest entry is the open item at status.md:30, "Manual QA the trial → paywall → purchase flow" — a general untested-flow note, not this mechanism (it says nothing about restore error handling or offline behaviour). No mention of `AppStore.sync`, restore, or offline anywhere in status.md.

**Verifier's reasoning**

Every cited line says what the claim says it says.

- `ScreenTimeShield/Store.swift:52-55` — `func restore() async { try? await AppStore.sync(); await refreshPurchasedState() }`. The `try?` discards every thrown error with no logging, no return value, and no stored error state. `restore()` returns `Void`, so there is literally nothing for a caller to inspect.
- `ScreenTimeShield/Store.swift:58-67` — `refreshPurchasedState()` iterates `Transaction.currentEntitlements` and unconditionally assigns `isPurchased = purchased`, i.e. an empty local entitlement cache deterministically yields `false`. There is no "unknown / couldn't determine" state.
- `ScreenTimeShield/AccessController.swift:107-110` — `restore()` awaits the store then `recomputeAccessState()`; returns `Void`. Confirmed the error is not propagated.
- `ScreenTimeShield/PaywallView.swift:144-153` — exactly two branches: `access.hasFullAccess` → `dismiss()`, else → `errorMessage = String(localized: "No previous purchase found.")`, rendered in `Style.errorColor` at :79-85. So a swallowed sync failure is presented as a factual assertion about the user's purchase history.

Searched for mitigations and found none: no `errorMessage` set anywhere else for restore, no `catch`/`do` around restore in the view or controller, no alert, no network-reachability guard. Grepped `showPaywall` — the Restore button is reachable in every relevant state (`ContentView.swift:187` trial chip, :71 and :101 expired CTAs, `QAMenuView.swift:60`), so a reinstalled paid user (whose `trial_start` is nil, so they land in `.trial`, chip visible) can reach it. `PaywallView.swift:120-122` (`onChange` → dismiss on `.fullAccess`) only helps the success path.

Two incidental notes that do not change the verdict: `PaywallView.restore()` also never clears a stale `errorMessage` on entry (unlike `buy()` at :133), and `Store.restore()` does not call `refreshGrandfatheredState`, so a grandfathered user's tap on Restore relies on `isGrandfathered` already being true from a prior `refreshAccess()`.

**Correction to the original claim**

Mechanism is exactly as claimed; the *consequence* is overstated in two places. (a) "the most likely reaction is buying again" — the user cannot pay twice for a non-consumable: the App Store deduplicates and re-grants an already-owned non-consumable free of charge, and while offline the buy button is dead anyway (`product == nil` → `.disabled` at PaywallView.swift:102). So this is not a revenue-loss bug; it is misinformation plus support/refund/1-star risk. (b) The offline and user-cancelled cases are not distinguishable even if the error were caught: Apple's own StoreKit 2 behaviour reports `AppStore.sync()` surfacing `StoreKitError.userCancelled` when the network is unavailable, so any fix must present a neutral "couldn't reach the App Store, check your connection and try again" rather than trying to branch on the error case.

**Failure trace (re-derived from source by the verifier)**

1. Paid user reinstalls Unplug (new phone / restore-from-backup). App-group defaults are empty, so `trialStart == nil`; `ContentView.task` → `AccessController.refreshAccess()` (AccessController.swift:93-99) → `refreshPurchasedState()` finds no cached entitlement → `isPurchased = false`; `accessState = .trial`; the trial chip is shown.
2. User is offline (Airplane Mode / captive portal) or dismisses the Apple-ID sheet `sync()` presents.
3. User taps the trial chip (ContentView.swift:187) → `showPaywall = true` → `PaywallView`. Taps "Restore Purchase" (PaywallView.swift:104-111) → `PaywallView.restore()` → `AccessController.restore()` (:107) → `Store.restore()` (Store.swift:52).
4. `AppStore.sync()` throws → discarded by `try?` (Store.swift:53). No log, no state.
5. `refreshPurchasedState()` runs against the still-empty local cache → `isPurchased = false` (Store.swift:66).
6. `recomputeAccessState()` → `accessState` stays `.trial`; `hasFullAccess` false.
7. Back in the view: `access.hasFullAccess == false` → `errorMessage = "No previous purchase found."` (PaywallView.swift:151) rendered in red at :79-85.
Persisted state: unchanged (`enforcement_allowed` recomputed to the same value). What the user sees: a definitive statement that they never bought the app, with no mention of the network and no retry guidance.

**Apple API semantics checked**

`AppStore.sync()` is `static func sync() async throws` — confirmed by the source itself (a `try?` on a non-throwing call would not compile cleanly) and by Apple's docs/forums; it presents a system Apple-ID authentication prompt and is meant to be called only from an explicit user action. Web check (Apple Developer Forums thread 692177 and related) confirms it throws on failure and, notably, throws `StoreKitError.userCancelled` even when the cause is no network (airplane mode) — reported in debug-with-StoreKit-config, TestFlight and production. `Transaction.currentEntitlements` yields only locally cached verified transactions, so an offline fresh install legitimately yields none. All three semantics support the claim; nothing I checked contradicts it. Apple's own doc page for `sync()` did not render usable prose via WebFetch, so the throwing-and-offline behaviour rests on the signature plus the forum reports rather than a doc quote — that does not affect the verdict, since `try?` erases the error regardless of which error it is.

**Proof path**

Not provable today. The outcome→message mapping lives in a `private func restore()` inside a SwiftUI view (`ScreenTimeShield/PaywallView.swift:144-153`), and the layer below it (`Store.restore()`, Store.swift:52) returns `Void` with the error already destroyed by `try?`, so there is no observable value to assert on at any seam. SKTestSession also gives no hook to make `AppStore.sync()` fail (`failTransactionsEnabled`/`askToBuyEnabled` affect purchases, not sync), so even an integration test cannot drive the failure branch.
Extraction needed: (1) make `Store.restore()` return an outcome (e.g. `enum RestoreOutcome { case restored, noneFound, storeUnreachable }`) by catching the `sync()` error instead of `try?`-ing it; (2) put the outcome→user-message mapping in a pure `UnplugCore` function, e.g. `RestoreMessage.text(for: RestoreOutcome)`. Then a pure test in `UnplugCore/Tests` asserts `.storeUnreachable` maps to a connectivity message and only `.noneFound` maps to "No previous purchase found." — with a companion assertion that a thrown sync error maps to `.storeUnreachable`, not `.noneFound`.

---

## Uncertain (3)

Real-looking but turns on a behaviour the verifier could not confirm. Each says what would settle it — most are answerable with one device test.

### `V13` · Revoking Screen Time mid-block leaves inside_interval true forever -> app permanently bricked

- **🔴 Important** · impact **lockout** · needs device · hit **rare for an ordinary user (needs Screen Time access disabled *during* an active block); common for a user actively escaping their own block — and in either case only if iOS behaves as branch A below**
- **Feature** F4 · **Discovery IDs** F4-HOSTILE-02
- **Already in status.md:** Partially. status.md, Bugs section, first entry: "[x] **Family Controls authorization not handled** (was a release blocker)". Same trigger (revoked authorization) but a different and narrower mechanism — it covers only showing `PermissionDeniedView` and disabling the CTAs when `authorizationStatus != .approved`. The stranded `inside_interval` / permanent false "Block active" state is NOT recorded there. Two things in that entry are relevant and both are wrong or under-scoped: it asserts "**There is no per-app Screen Time toggle in iOS Settings**" (false — Settings → Screen Time → Apps with Screen Time Access, per DevForums 758333), and it dismisses the live case with "revoking auth in system settings while the app is running doesn't update `authorizationStatus` until next cold launch (Apple bug) — acceptable", which is the very window in which this bug strands the flag. So: the trigger is known and was explicitly judged acceptable; this consequence of it is news.

**Verifier's reasoning**

Every cited line says what the claim says, and I found no guard anywhere that clears or reconciles the flag.

Code truth (verified by exhaustive grep for `inside_interval|insideInterval` across all targets — 21 hits, listed below):
- Only three writers exist: `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:63` (true), `:77` (false), and `ScreenTimeShield/AccessController.swift:199` (false, inside `qaResetToFreshInstall()` at :186). Its sole caller is `ScreenTimeShield/QAMenuView.swift:65`, reachable only from the Section commented out at `ScreenTimeShield/SettingsView.swift:25-29` — so unreachable in production, as claimed.
- `stop()` (`ScreenTimeShield/ContentView.swift:82-86`) writes `isArmed = false`, `Schedule.stopMonitoring([.daily, .notificationSchedule])`, `clearRestrictions()` — never touches `insideInterval`. Confirmed.
- `onAppear` (`ScreenTimeShield/ContentView.swift:245-255`) re-derives only `isArmed = DeviceActivityCenter().activities.contains(.daily)`. No clock/schedule reconciliation of `insideInterval`. Confirmed.
- No `onChange(of: access.fcAuthorized)` anywhere (grep: `fcAuthorized` appears only at AccessController 33/36/50/80/95 and ContentView 32/44/190) — losing or regaining authorization triggers no state repair.
- Every recovery control is gated on the flag: `primaryDisabled` returns true at `ContentView.swift:45` before it consults `isArmed` (:46); `onPrimary` early-returns at :51; `isQuickRestrictDisabled` includes `model.insideInterval` (:32) and `PinnedActions.swift:35/48` apply `.disabled(...)` to both buttons; `ScheduleCard.swift:21` disables the mode picker and `ScheduleRangeSlider.swift:129` sets `.gesture(locked ? nil : ...)`; `disarmIfArmedInactive()` (:91) no-ops while the flag is true.
- Dead-end verified: with `isArmed == false`, `applySchedule()` (:60) hard-guards on `model.isArmed`, so even the reachable app-picker path (`onChange(of: model.selectionToRestrict)`, :218-229) registers nothing. `Schedule.setSchedule` is called only from `performArm()`/`performRestrictHour()`, both behind the disabled CTAs. So no daily/hourly activity can be registered → no `intervalDidEnd` → nothing can clear the flag. The UI meanwhile renders "Block active" (`StatusBanner.swift:33`), "Restricted" (`AppCard.swift:27`), a locked "Blocking" CTA and "Schedule locked while a block is active" (`ScheduleCard.swift:30-33`) with nothing enforced.

Reachability: real. Settings → Screen Time → "Apps with Screen Time Access" lets a user toggle a third-party app's Family Controls authorization off, and revocation lifts all of that app's ManagedSettings restrictions immediately (Apple DevForums 758333, 820796). status.md's own note on the FC entry already records that "revoking auth in system settings while the app is running doesn't update authorizationStatus until next cold launch", so the author has hit revocation on device.

Two claim details are wrong but only in the candidate's favour or neutral (see correctedMechanism): the toggle is historically NOT passcode-protected (that is the whole complaint in DevForums 758333), and "forever" is stronger than the evidence supports.

**Correction to the original claim**

Two corrections, neither of which removes the bug.

1. Permanence is conditional, not certain. The stranded flag is permanent only if the system also drops Unplug's `.daily` DeviceActivity registration on revocation. If the registration survives (DevForums 820796 reports that after re-enabling access "everything syncs back to normal", which suggests it does), then the next cycle's `intervalDidEnd(.daily)` clears the flag — so the user is falsely locked out and unprotected for up to ~24h rather than forever. Conversely if `onAppear` read an empty activity list only because the query ran while unauthorized, `isArmed` is now false while the system schedule still exists, which is its own inconsistency. So: "false 'Block active' + fully locked UI + zero enforcement, lasting until the next intervalDidEnd if one ever arrives, permanently if it does not."

2. The Settings toggle is *not* gated by Face ID / passcode as the claim states. Settings → Screen Time → Apps with Screen Time Access accepts a plain toggle-off with no Screen Time passcode — that is the substance of Apple DevForums 758333 (a fix appears to have landed only around iOS 26.4). That makes the escape cheaper than claimed and makes status.md's "There is no per-app Screen Time toggle in iOS Settings" factually wrong.

3. Broader root cause, worth reporting instead of the revocation framing: revocation is merely one trigger. Any missed `intervalDidEnd` — documented Screen Time flakiness (DevForums 777564 "Device Activity Monitor Schedules Disappear", 731691 Screen Time connection breaking) — strands the flag identically. The defect is that `inside_interval` is treated as the sole source of truth for "a block is active" while being writable only by an out-of-process callback that may never arrive, and `ContentView.onAppear` reconciles `isArmed` against `DeviceActivityCenter().activities` but never reconciles `insideInterval` against the clock — even though `ScheduleMath.windowContains(now:start:end:)` is already imported and used 120 lines below (ContentView:126-128).

**Failure trace (re-derived from source by the verifier)**

Daily block 23:00–07:00, armed. 23:00 `intervalDidStart(.daily)` → `enforcementAllowed` true → `setRestrictions()`, `inside_interval = true` (Extension:60-63). Shields applied.

23:20 user goes Settings → Screen Time → Apps with Screen Time Access → Unplug → off. System immediately drops every ManagedSettings restriction Unplug applied (platform-level escape, not the app's bug). The monitor extension is not invoked, so nothing writes `inside_interval = false`.

07:00 passes with authorization revoked → no `intervalDidEnd` delivered.

08:00 user re-enables Screen Time access and cold-launches Unplug. `AccessController.init` (:36) sets `fcAuthorized = true`. `ContentView.onAppear` (:246-254) calls `loadSelection()` (tokens voided by revocation → empty selection → `selectionIsInvalidated()` true → "App selection was reset" toast, `hasSelection = false`) and `model.isArmed = DeviceActivityCenter().activities.contains(.daily)`.

Persisted state now: `inside_interval = true`, `is_armed` = whatever the activity list says, shield store empty.

What the user sees: StatusBanner "Block active" with the pulsing dot, AppCard header "Restricted", primary CTA "Blocking" with a lock glyph and `.disabled(true)` (ContentView:38/45 → PinnedActions:22-35), "Restrict for next hour" greyed out (ContentView:32), schedule slider and mode picker inert with "Schedule locked while a block is active". Nothing is enforced.

Recovery attempts, all dead: re-select apps → `onChange` passes validation (`savedSelection()` decodes to nil/empty so `validateRestriction()` returns true) → `saveSelection()` → `applySchedule()` returns at the `guard model.isArmed` when isArmed synced false. Drag the slider → gesture is nil. Tap Blocking → `onPrimary` returns at :51. Toggle refocus notifications → touches only `.notificationSchedule`, whose name the extension's interval callbacks ignore (Extension:53/74). Force-quit/reinstall-free relaunch → same `onAppear`, flag survives in the app group. Only delete-and-reinstall (or the commented-out QA reset) clears it.

**Apple API semantics checked**

1. Per-app revocation exists and is user-reachable: Settings → Screen Time → "Apps with Screen Time Access" toggles a third-party app's Family Controls authorization. Confirmed via Apple DevForums thread 758333 (title: "[iOS 18] Screen Time Passcode is still NOT compatible with screen time permissions for 3rd party-apps"), which also establishes that NO Screen Time passcode was required to flip it (fixed only around iOS 26.4 per the thread's last comment). This directly contradicts both the candidate ("gated by Face ID / passcode") and status.md ("There is no per-app Screen Time toggle in iOS Settings").

2. Revocation lifts restrictions: confirmed. DevForums 820796 ("FamilyControls individual authorization: No way to detect revocation while app is backgrounded") states all ManagedSettingsStore restrictions are lifted immediately by the system and the app receives no notification; FamilyActivitySelection tokens are voided.

3. Revocation is silent to the app: confirmed — `AuthorizationCenter.shared.$authorizationStatus` does not emit on Settings-initiated revocation (820796). This matters because AccessController.swift:48-50 relies on that publisher, so `fcAuthorized` can stay true after revocation; the app therefore cannot even react.

4. Whether revocation cancels DeviceActivity monitoring / whether `intervalDidEnd` is ever delivered for the interrupted interval: COULD NOT CONFIRM. I could not retrieve the `revokeAuthorization(completionHandler:)` doc text (Apple's docs page returned no body to WebFetch), and forum evidence is contradictory — 820796 implies schedules resume on re-authorization, while 777564/731691 report schedules silently disappearing when the Screen Time connection breaks. This is exactly what separates "locked out for up to 24h" from "bricked forever", so it is the one thing to settle on device: revoke mid-block, re-grant, then inspect `DeviceActivityCenter().activities` and whether `inside_interval` ever flips back to false. Note `intervalDidEnd` is NOT invoked by `stopMonitoring` in any case, which is what makes the stranded-flag class of failure real regardless.

**Second opinion (**DISAGREES** with the first verifier)**

_Worst realistic outcome:_ The user disables Screen Time access mid-block, re-enables it, and from then on Unplug is a dead app: it permanently shows "Block active" with a locked "Blocking" button, the schedule slider and "Restrict for next hour" are inert, and nothing is actually blocked. No sequence of taps recovers — only deleting and reinstalling. If instead iOS keeps the schedule registered across revocation, the worst case is nothing at all beyond the platform escape itself.

I disagree with the first verifier's CONFIRMED. Their code reading is accurate — I re-verified every writer and every gate — but they graded the wrong question and, in doing so, missed that the two API branches are not "permanent vs temporary lockout" but "bug vs no bug at all."

WHAT I CONFIRM (all of it code-level, independently re-derived)
- `ScreenTimeShield/Model.swift:25` — `inside_interval` is `@AppStorage` in the `group.screentimeshield` suite; it survives force-quit and relaunch.
- Writers are exactly three: `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:63` (true), `:77` (false), `ScreenTimeShield/AccessController.swift:199` (false, in `qaResetToFreshInstall()`). That last one is reachable only from `ScreenTimeShield/QAMenuView.swift`, entered only from the Section commented out at `ScreenTimeShield/SettingsView.swift:25-29` — I confirmed those lines are still commented out. So in production only the extension can clear it.
- `stop()` (`ScreenTimeShield/ContentView.swift:82-86`) and `onAppear` (`:245-255`) never touch it; `onAppear` re-derives only `isArmed` from `DeviceActivityCenter().activities`. No `onChange(of: access.fcAuthorized)` exists anywhere.
- The dead-end is real and total: `Schedule.setSchedule` has exactly three callers — `performArm()` (`:76`, behind `onPrimary`'s early return at `:51` and `primaryDisabled` at `:45`), `performRestrictHour()` (`:105`, behind `isQuickRestrictDisabled` at `:32` → `.disabled` at `PinnedActions.swift:48`), and `applySchedule()` (`:59`, hard-guarded on `model.isArmed`). So **if `inside_interval` is ever left true while `isArmed` is false, no code path in the app can register any activity, therefore no `intervalDidEnd` can ever be delivered, therefore the flag is permanent.** That conditional I would defend to the author.

WHAT THEY GOT WRONG — the branch analysis
The first verifier wrote off the API question as "forever is stronger than the evidence supports… only in the candidate's favour or neutral." It is neither. Work branch B through:
- Branch A — revocation destroys the `.daily` registration: `activities` is empty → `isArmed = false` → permanent brick, as claimed.
- Branch B — the registration survives revocation: `.daily` is still scheduled, so on next device use at the scheduled 07:00 `intervalDidEnd(.daily)` fires and clears the flag; `onAppear` re-syncs `isArmed = true`; the app is fully functional. In that branch there is **no stale-flag window to report at all** — 23:20→07:00 is the block's own scheduled window, so "Block active" is not even a lie; the only harm is the platform-level escape, which the candidate itself explicitly excludes as not the app's bug. Branch B means this finding does not exist.
So the whole finding rests on one unconfirmed system behaviour, and the first verifier's "I found no guard anywhere" does not address it — the missing guard is not the load-bearing step, the trigger is.

THEIR CITATIONS DON'T CARRY THE WEIGHT THEY CLAIM
I fetched the sources. Apple's `revokeAuthorization(completionHandler:)` discussion says only: "After you revoke authorization, your app no longer provides parental controls, and the system no longer enforces restrictions, such as preventing the user from deleting your app." Not a word about cancelling DeviceActivity monitoring. And `intervalDidEnd(for:)`'s discussion says: "An activity ends when someone first uses the device outside the activity's scheduled time interval or when your app stops monitoring an activity with an ongoing interval. In other words, the system only invokes this method when the device is in use." Neither clause covers system-initiated revocation — which is precisely why the branch is undecidable from docs. I read DevForums 758333 and 821959 myself: 758333 establishes only that the toggle exists and is not Screen-Time-passcode protected; 821959 (iOS 26.4/27b2, still open) says the per-app toggle takes Face ID instead of the Screen Time passcode. **Neither thread says anything about restrictions being dropped, monitoring being torn down, or schedules being cleared** — the first verifier's parenthetical "revocation lifts all of that app's ManagedSettings restrictions immediately (Apple DevForums 758333, 820796)" is not supported by 758333, and monitoring teardown is not attested anywhere I could find.

TWO CONSEQUENCE POINTS THEY OVERSTATED
1. "The false 'Blocking' display means they believe they are protected" — only partly. `ContentView.swift:190-194` swaps in `PermissionDeniedView` ("Screen Time access is off" / "Allow access") in place of the app card whenever `!access.fcAuthorized`, and `AccessController.swift:48-51` subscribes to `$authorizationStatus` live. So while access is off the app does tell the user, plainly, that it can't enforce. The fake "Block active" becomes the *only* story only after they re-grant. Contradictory UI during the off period, yes; silent false confidence, no.
2. Frequency: they hedged, but this needs stating flatly. The strand requires the toggle to be flipped *inside* the block window — outside it `inside_interval` is already false and nothing is stranded. So the non-hostile version ("turned Screen Time off for an unrelated reason") requires that unrelated reason to land mid-block. This is a hostile-user-first bug, not an ordinary-evening bug.

ONE POINT IN THE CANDIDATE'S FAVOUR THAT NEITHER OF THEM MADE
The more plausible branch-A trigger is not the per-app toggle but Settings → Screen Time → **Turn Off Screen Time** entirely, which tears down the Screen Time database (Apple support: it removes Downtime/App Limits/Always Allowed) and would almost certainly take registered third-party activities with it. That is a far more ordinary user action than the per-app toggle, and it strengthens branch A — but I still could not confirm the activity list is destroyed, so it doesn't change the verdict.

ALREADY KNOWN? Partly. `status.md:6` records the Family-Controls-authorization work as done and notes on-device that "revoking auth in system settings while the app is running doesn't update `authorizationStatus` until next cold launch (Apple bug) — acceptable," so the author has flipped this toggle on a device. The stranded `inside_interval` is **not** recorded. Also worth passing on: `status.md:6`, `AccessController.swift:71-73` and `PermissionDeniedView.swift:6-8` all assert "There is no per-app Screen Time toggle in iOS Settings" — that is factually wrong (Settings → Screen Time → Apps with Screen Time Access; DevForums 758333, 821959) and is a threat-model error worth correcting on its own.

WHAT WOULD SETTLE IT (device, ~one block cycle): arm a daily block; after `intervalDidStart` confirm shields applied and `inside_interval == true` in `group.screentimeshield`; disable Screen Time access for Unplug in Settings; re-enable; cold-launch and log `DeviceActivityCenter().activities`. If it still contains `.daily` → branch B → REFUTED. If empty → let the scheduled end time pass with the device in use and re-read `inside_interval`; if it is still true → branch A → CONFIRMED as an unrecoverable brick.

FIX NOTE (worth doing regardless of this verdict): the underlying defect — `inside_interval` is never reconciled against the clock or the activity list — is also reached by `F4-HOSTILE-03` Outcome B and the `F4.8` note, neither of which depends on revocation semantics. A reconciliation in `ContentView.onAppear` (`:245`) that clears the flag when no activity is registered, or when `ScheduleMath.windowContains` says the window has passed, closes all three. The helper is already in the target and already called at `ContentView.swift:126-128`.

**Proof path**

Not provable today. The gating logic (`primaryTitle`/`primaryDisabled`/`isQuickRestrictDisabled`/`onPrimary`) is private computed state inside the `ContentView` struct, and the only writer of the flag is a `DeviceActivityMonitor` subclass that cannot be instantiated or driven from a test. `SKTestSession` is irrelevant here (no StoreKit involvement).

What extraction would make it testable: move the "is a block active" decision into UnplugCore as a pure function alongside the existing `ScheduleMath` (UnplugCore/Sources/UnplugCore/ScheduleMath.swift), e.g. `BlockState.isActive(persistedFlag: Bool, isArmed: Bool, nowMinutes: Int, startMinutes: Int, endMinutes: Int) -> Bool` implemented as `persistedFlag && isArmed && ScheduleMath.windowContains(...)`, and have ContentView use it in place of raw `model.insideInterval` at :32/:38/:45/:51/:200 (plus ScheduleCard/AppCard/StatusBanner via a single Model-level computed property). Then a pure test in UnplugCore/Tests/UnplugCoreTests can assert: (a) `persistedFlag = true, isArmed = false` → false (the stranded-flag case in this report — CTA usable again); (b) `persistedFlag = true, isArmed = true`, now outside the window → false (missed intervalDidEnd); (c) `persistedFlag = true, isArmed = true`, now inside a wrapping 23:00–07:00 window → true (the lock still holds, i.e. the fix does not open a bypass). Additionally a reconciliation call in `ContentView.onAppear` that sets `model.insideInterval = false` when `!activities.contains(.daily) && !activities.contains(.hourly)` would need the same pure helper to be testable.

---

### `V25` · Trial resets on delete + reinstall (no reinstall-proof anchor)

- **🟡 Nit** · impact **revenue** · needs device · hit **adversarial-only (and rare even there — requires a user who deliberately deletes a self-restraint app to dodge a one-time unlock, AND an OS behaviour that current field reports say does not occur)**
- **Feature** F9 · **Discovery IDs** F9-INTEG-05
- **Already in status.md:** Not recorded in status.md. The nearest entries are "Implement free download + 7-day trial + one-time 'lifetime unlock' IAP, with grandfathering" (status.md:26, marked done) and "Manual QA the trial → paywall → purchase flow" (status.md:30, still open) — neither mentions reinstall, trial-reset abuse, Keychain, or a receipt-based anchor. grep of status.md for reinstall/Keychain returns nothing. This is news.

**Verifier's reasoning**

Every code fact the claim rests on checks out at the cited lines, and I found no guard anywhere in the repo.

1. `trial_start` is the sole record that a trial was ever started. `AccessController.trialStartDate` reads/writes it through `AppGroupStore` only (/Users/stevendiviney/code/ScreenTimeShield/ScreenTimeShield/AccessController.swift:55-58 → AppGroupKeys.trialStart = "trial_start", /Users/stevendiviney/code/ScreenTimeShield/ScreenTimeShield/AppGroupStore.swift:13, :24-31), and `AppGroupStore` is backed purely by `UserDefaults(suiteName: "group.screentimeshield")` (AppGroupStore.swift:22). The only writers of `trialStartDate` are `startTrialIfNeeded()` (AccessController.swift:84-90) and the three QA hooks (:157, :163, :169).

2. No secondary/reinstall-proof anchor exists. `grep -rn "Keychain|kSecClass|NSUbiquitous|SecItem" --include="*.swift" .` returns zero hits repo-wide. There is no network client and no `UserDefaults.standard` first-install flag either: the only `UserDefaults.standard` reference in the whole project is `removePersistentDomain(forName: "group.screentimeshield")` inside the QA reset (AccessController.swift:191), and every `@AppStorage` in Model.swift:25-32 is explicitly bound to the same app-group suite, so nothing at all lives in the per-app container that could survive as a "trial already used" witness.

3. `AppTransaction.originalPurchaseDate` — which does survive reinstall — is fetched but consumed only by `Grandfather.isGrandfathered` (/Users/stevendiviney/code/ScreenTimeShield/ScreenTimeShield/Store.swift:68-79 → AccessControl.swift:76-79). It is never passed to `AccessEvaluator`, whose signature has no install-anchor parameter at all (AccessControl.swift:52-58). Confirmed the claim's line cites: `accessState` returns `.trial` on nil trialStart (AccessControl.swift:56) and `trialDaysRemaining` returns the full ceil(7) (AccessControl.swift:63-65), and both behaviours are locked in by existing tests (AccessControlTests.swift:53-60).

4. Nothing gates the post-reinstall state: `refreshAccess()` (AccessController.swift:91-97) → `recomputeAccessState()` writes `enforcement_allowed = (accessState != .expired)` (:113-117), so a nil `trial_start` yields a fully-working app with `enforcement_allowed = true`.

The claim self-reports low confidence because it turns on whether the app-group container is cleared on delete. I checked Apple's position and it points the claim's way, not against it: in developer.apple.com/forums/thread/720458 a DTS engineer states the shared container is expected to be deleted when the last app referencing the app group is uninstalled, and treats the observed persistence as a bug to file (FB11844942). `group.screentimeshield` is referenced only by this app and its three extensions, all removed together on delete, so documented behaviour is deletion. The developer.apple.com/forums/thread/718449 persistence reports the candidate cites are developer anecdotes with no Apple reply and describe an acknowledged defect — i.e. Unplug's entire trial-reset defence is currently an iOS bug it has no contract on. That is enough for me to defend the finding; see rederivedTrace for what a device settles.

**Correction to the original claim**

Two corrections to the claim's framing, neither of which undoes the bug.

(a) The OS dependency is the opposite of what the candidate feared. Apple's DTS position (forums/thread/720458) is that the container SHOULD be deleted once the last app in the group is uninstalled; the persistence reports in forums/thread/718449 are an acknowledged iOS defect (FB11844942), not a contract. So the claim's own "this may not reproduce" hedge is weaker than warranted: the app is depending on a filed bug staying unfixed. Also note two variants that reset the trial with no container-deletion question at all — a second device on the same Apple ID, and Erase All Content and Settings — so "there is no reinstall-proof anchor" is unconditionally true even if same-device delete happens to leak.

(b) The proposed remedy is not a drop-in. Anchoring the trial to `AppTransaction.originalPurchaseDate` would run the 7 days from first *download* rather than from first block setup, which silently expires the trial for a legitimate user who downloads now and sets up a block three weeks later — a lockout regression. The receipt date is usable only as a one-way sanity check ("trial cannot start more than once per originalPurchaseDate" needs a separate persisted marker), so the correct fix is a Keychain-backed `trial_start` (Keychain items survive app deletion) with the receipt date as a corroborating floor, not the receipt date alone.

Additional context on severity, not a correction: delete+reinstall already lifts an *active* block outright (deleting the app tears down its `ManagedSettingsStore`), so this path is a pre-existing hole in the product promise; the trial reset is the revenue consequence riding on it, and reinstall costs the user their app selection, schedule, Screen Time authorization and `times_stopped` stat each time.

**Failure trace (re-derived from source by the verifier)**

1. Fresh post-cutover install. User grants Family Controls, picks apps, taps "Start blocking" → `startTrialIfNeeded()` sees `trialStartDate == nil`, writes `trial_start = now` into the app group, `recomputeAccessState()` → `.trial`, `enforcement_allowed = true` (AccessController.swift:84-90, :113-117).
2. Day 8 foreground → `refreshAccess()` → `refreshPurchasedState()` false, `refreshGrandfatheredState` false (originalPurchaseDate ≥ cutoverDate) → `accessState(now:, trialStart: day0, hasFullAccess: false)` returns `.expired` (AccessControl.swift:57) → `enforcement_allowed = false` persisted → the monitor extension stops applying shields on the next `intervalDidStart`. User sees trial-ended UI.
3. Long-press icon → Remove App → Delete App. All four targets of `group.screentimeshield` are gone, so per Apple's stated behaviour the shared container is torn down; `trial_start` is destroyed along with `times_stopped`, `is_armed`, the encoded `ScreenTimeSeletion` and every other app-group key.
4. Reinstall from the App Store, launch. `AppGroupStore` recreates an empty suite. `AccessController.init` → `.trial` default; first `refreshAccess()` → `recomputeAccessState()` with `trialStart: nil, hasFullAccess: false` → `.trial` (AccessControl.swift:56), and it persists `enforcement_allowed = true`.
5. Persisted state: `trial_start` absent, `enforcement_allowed = true`, no purchase. `trialDaysRemaining` = 7 (AccessControl.swift:63-65).
6. What the user sees: the trial chip reads "7 days left" and blocking works again. `startTrialIfNeeded()` re-stamps `trial_start = now` on the next arm, so the cycle is repeatable indefinitely. No code path in the app can notice the repeat — there is no value it could compare against.

**Apple API semantics checked**

App-group container lifetime on app deletion (the only semantic the claim needs). Checked developer.apple.com/forums/thread/720458 — an Apple DTS engineer states the expected behaviour is that the shared container is deleted when the last app referencing the app group is uninstalled, and asked the reporter to file Feedback for the case where it persisted (FB11844942, iOS 16). Checked developer.apple.com/forums/thread/718449 — the "app-group defaults survive reinstall from iOS 16" claim the candidate leans on is developer anecdote with no Apple reply; the accepted answer is a workaround (mirror an `isNotFirstInstall` flag in `UserDefaults.standard` and hand-clear the group keys), which itself concedes the group container is not a reliable place to keep an install-scoped fact. Apple publishes no timing guarantee for the cleanup either way. StoreKit 2 semantics needed no verification beyond confirming `AppTransaction.originalPurchaseDate` is only read by `Grandfather.isGrandfathered` in this codebase — the claim does not depend on how the receipt behaves, only on the fact that the app never consults it for the trial.

**Second opinion (**DISAGREES** with the first verifier)**

_Worst realistic outcome:_ A non-paying user who is willing to delete and re-set-up Unplug can keep re-granting themselves 7-day trials, at the cost of re-authorizing Screen Time, re-picking every app, re-setting the window and losing their "times stopped" stat on each cycle. Pure developer-side revenue leakage from a self-selected non-paying cohort on a one-time unlock. No legitimate user loses access, and no active block is weakened.

I re-derived every code fact independently and they all hold — so my disagreement is not about the code, it is about (1) how verifier 1 resolved the OS-behaviour question and (2) the size of the consequence.

CODE FACTS (all confirmed, no guard exists)
- `trial_start` is the sole witness: /Users/stevendiviney/code/ScreenTimeShield/ScreenTimeShield/AccessController.swift:55-58 → AppGroupStore.swift:13 (`trialStart = "trial_start"`), and AppGroupStore.swift:22 backs everything with `UserDefaults(suiteName: "group.screentimeshield")!`.
- Nil `trial_start` → `.trial` (UnplugCore/Sources/UnplugCore/AccessControl.swift:56) and `trialDaysRemaining` → full ceil(7) (:63-65); `recomputeAccessState()` then writes `enforcement_allowed = true` (AccessController.swift:113-117).
- No reinstall-proof anchor anywhere: my own grep for `Keychain|kSecClass|NSUbiquitous|SecItem` returns zero hits, and I verified there is no per-app-container witness either — every `@AppStorage` and every raw write in Model.swift:25-51 is explicitly bound to the group suite, and the only `UserDefaults.standard` use in the project is the QA `removePersistentDomain` (AccessController.swift:191).
- `AppTransaction.originalPurchaseDate` is fetched but only feeds `Grandfather.isGrandfathered` (Store.swift:70-79 → AccessControl.swift:74-77); `AccessEvaluator.accessState`'s signature (AccessControl.swift:52-58) has no install-anchor parameter.
- Not recorded in status.md; the pricing section (status.md:25-30) has no entry for a reinstall/trial-anchor issue, so this is not already-known.

WHERE VERIFIER 1 IS WRONG — they inverted the evidence on the only load-bearing question
The finding fires only if iOS clears the app-group container on delete+reinstall. Verifier 1 called that settled in the claim's favour by citing forums/thread/720458. I fetched that thread: Quinn's actual words are "If you've deleted all the apps using the shared container and the container doesn't go away, that seem eminently bugworthy to me." That is a normative aside inviting a bug report, not a statement about what shipping iOS does — and FB11844942 ("Shared App Container persists across installs") was filed precisely because it did NOT go away.
Meanwhile the only *observational* evidence I could find points the other way and matches Unplug's exact configuration. forums/thread/718449: "I saved data in appgroups, and that data not cleared after uninstall. but other data saved in userdefaults.standard, cleared after uninstall" (iOS 16), corroborated on iOS 17 ("Still same issue here. Data stored in group UserDefaults is not cleared") and tvOS 17. Unplug keeps 100% of trial state in the group suite and nothing in `standard` — i.e. exactly the bucket that reportedly survives. And in the much more recent forums/thread/821222 (iOS 26 era) the same DTS engineer writes "iOS is expected to preserve app group containers across OS and app installs."
So verifier 1 built CONFIRMED on the one normative quote and dismissed the only descriptive reports as "developer anecdotes." Anecdotes are the only class of evidence that exists here, and they say the trial would NOT reset. That is UNCERTAIN at best, and their own claim of "no contract on it" cuts both ways — Apple has documented no clearing guarantee either.

CONSEQUENCE OVER-CLAIM
"Unlimited free trials via a 30-second delete/reinstall" is inflated. Deleting also wipes `ScreenTimeSeletion`, `is_armed`, `has_selection`, `block_outside_window`, `start`/`end` and `times_stopped` (all group-suite, Model.swift:22-51). Each cycle therefore costs a fresh Family Controls authorization prompt (AccessController.swift:74-82), a full re-pick through `FamilyActivityPicker`, re-setting the range slider, an explicit re-arm plus the risky-arm confirm (ContentView.swift:73-80), and the loss of the motivational stat. Minutes of weekly friction, not 30 seconds — and the actor is someone deliberately deleting a self-restraint app rather than paying once.
Also worth stating plainly: the trace begins from an already-expired trial, so `enforcement_allowed` is already `false` and there is no live block being escaped — this is re-acquiring an unpaid feature, not defeating the product's core promise. And no legitimate user is harmed: purchases restore through `Transaction.currentEntitlements` and grandfathering through `AppTransaction` (Store.swift:57-79), both of which survive reinstall.

WHAT VERIFIER 1 MISSED (the stronger version of this finding)
There is a genuinely non-adversarial path they never mention: forums/thread/821222 reports app-group containers being recreated *empty on ordinary app updates*, ~85% of cases on iOS 26, with Quinn acknowledging "that doesn't preclude there being a bug that causes this problem for some users of some apps" and recommending canary files. That resets `trial_start` with zero user action — but it simultaneously wipes the selection and `is_armed`, so its real consequence is the much worse "the user's block silently vanishes after an update," a different (and higher-severity) finding than this one. The receipt-date/canary anchor is the fix for both, which is the useful part of this candidate.

CLASS AND SEVERITY
"Revenue" is the right class. "Important" is not: it is a hardening gap of the kind every locally-anchored trial has, it is gated on an undemonstrated OS behaviour that current reports contradict, it harms no user, and it cannot touch an active block. Nit / product-hardening backlog.

WHAT WOULD SETTLE IT (5 minutes, one device, no ambiguity left)
On a device running the target iOS: arm a block so `trial_start` is stamped, confirm via the TrialChip, delete the app (all four group members go together, so the group has no remaining member — the precondition Quinn's 720458 remark is about), reinstall, launch, read the TrialChip. "N days left in trial" → CONFIRMED as claimed; "Trial ended · Unlock Unplug" → REFUTED and the trial anchor is fine as-is. Verifier 1 should have stopped at UNCERTAIN pending exactly this, as the candidate itself did ("Needs device: yes", confidence low).

**Proof path**

Not provable today, in either half.

The pure half is already tested and passing as *intended* behaviour: `AccessControlTests.testNilTrialStartWithoutAccessIsTrial` (/Users/stevendiviney/code/ScreenTimeShield/UnplugCore/Tests/UnplugCoreTests/AccessControlTests.swift:53-60) asserts exactly the nil-trialStart → `.trial` mapping this bug exploits, so there is nothing to catch at that layer — `AccessEvaluator.accessState` has no install-anchor parameter to assert against (AccessControl.swift:52-58). SKTestSession cannot help either: the gap is that `AppTransaction.originalPurchaseDate` is never fed into the access decision, and StoreKit is behaving correctly.

What would make it testable: extend `AccessEvaluator.accessState` (and a new pure helper, e.g. `TrialAnchor.resolveStart(persisted: Date?, installDate: Date?, now:)`) to take a reinstall-proof anchor, then a pure UnplugCore test can assert `resolveStart(persisted: nil, installDate: 30 days ago, now:) == 30 days ago` → `.expired`, i.e. a wiped `trial_start` does not hand back a fresh 7 days. Until that seam exists the only proof is the device check the candidate describes: burn the trial, delete the app, reinstall, read the trial chip — if it says "7 days left", confirmed on that iOS build.

---

### `V12` · DeviceActivityCenter().activities read synchronously on the main thread on the launch path

- **🟡 Nit** · impact **ux** · needs device
- **Feature** F4 · **Discovery IDs** F4-CONC-02
- **Already in status.md:** status.md:8 — "Arm-confirm UI stall — the synchronous `DeviceActivityCenter` start/stop XPC ran on the main thread (4 calls on confirm), freezing the UI. Moved off-main onto a serial queue in `Schedule`…" Same mechanism class and marked done, but that entry covers only the `start`/`stop` calls in `Schedule`; the `activities` read at ContentView.swift:248 is not mentioned anywhere in status.md, and git blame confirms the off-main commit did not touch it. So: the class of bug is known and believed fixed; this specific residual call is news.

**Verifier's reasoning**

Every code-truth element of the claim checks out verbatim; what I cannot confirm is the consequence.

CONFIRMED code facts:
- `ScreenTimeShield/ContentView.swift:248` is exactly `model.isArmed = DeviceActivityCenter().activities.contains(.daily)`, inline in `.onAppear` (opens at :245, right after `model.loadSelection()` at :246). No `Task`, no queue hop, no guard — so it runs on the main thread.
- It is on the launch path for every user: `ContentView` is the root of the single `WindowGroup` (`ScreenTimeShield/ScreenTimeShieldApp.swift:90-92`), and this `onAppear` is not gated on authorization, trial state, or the `UNPLUG_SKIP_FC`/`XCTestConfigurationFilePath` env hooks (those guard only the `.task` at ContentView.swift:256-261 and the scenePhase block at ScreenTimeShieldApp.swift:96-102).
- "The one call the off-main fix missed" is accurate. `grep -rn DeviceActivityCenter --include=*.swift` yields exactly: `Schedule.swift:33, :52, :65` (all inside `queue.async`, queue declared at `Schedule.swift:23`), `AccessController.swift:188` (inside `qaResetToFreshInstall()`), and `ContentView.swift:248`. The `AccessController` one is genuinely unreachable in production — its only entry is the QA Section commented out at `SettingsView.swift:25-29`. `git log -L 248,248:ScreenTimeShield/ContentView.swift` shows the line was introduced by a94003e ("Explicit arm/disarm model…", 17 Jun 2026) and never touched by the later off-main refactor, so it is a genuine miss, not a deliberate exemption.
- `Schedule.swift:18-21` does say what the claim quotes ("synchronous XPC calls to the system daemon and are slow enough to stall the UI"), and status.md:8 records the arm-confirm stall as a real, fixed, UI-freezing bug of exactly this class.

I searched for a mitigation and found none: no dispatch, no caching of `isArmed` that would let the read be skipped, no early return, no warm-up of the DeviceActivity connection before it (the `AuthorizationCenter.requestAuthorization` in `AppDelegate` is a different endpoint and is `async` in a detached Task, `ScreenTimeShieldApp.swift:110-116`).

Why not CONFIRMED: the claimed user impact (launch freeze / 0x8badf00d watchdog kill) requires `DeviceActivityCenter.activities` to be an expensive — or wedgeable — synchronous cross-process call, and I could not establish that. Apple's docs for the property say nothing about cost, threading, or actor isolation. The repo's own comment is evidence about `startMonitoring`/`stopMonitoring` only; transferring it to a property read is inference from "same class, same daemon". The only direct evidence for `activities` specifically is one unreproduced anecdote (forums thread 761299, kgaidis, Aug 2024: "My application code … seems to deadlock on calling DeviceActivityCenter.activities"), which is iOS 18 beta 4, explicitly not reproducible on 17.6, has no Apple reply, and was still unanswered when another dev bumped it in Mar 2025 — two years stale now. There are credible reports of `startMonitoring` freezing the UI >10s (forums 770223 and related), but none for the `activities` getter. Also mildly against the claim: this line has shipped since mid-June and nothing in status.md reports a slow or hanging launch, whereas the 4-call arm-confirm stall was noticed immediately.

Secondary claim in the mechanism — "unordered with respect to any queued start/stop" — is technically true but has no reachable consequence I could construct: at :248 nothing has been enqueued yet in that launch (the `applySchedule()` triggered by `loadSelection()` runs from `.onChange(of: model.selectionToRestrict)` at ContentView.swift:218, which fires after the body pass that ran `onAppear`), and `onAppear` does not re-run on foreground return. So the ordering half of the claim is not a defect.

What would settle it: a main-thread Instruments/`os_signpost` trace of `.onAppear` on a real device across (a) a post-reboot cold launch and (b) a launch coinciding with an interval boundary, measuring the duration of line 248. >~50-100ms makes this important; sub-millisecond makes it a non-issue. Note the fix is one `queue.async { let armed = …; DispatchQueue.main.async { model.isArmed = armed } }` regardless of the measurement, so the cost of acting without the measurement is near zero.

**Correction to the original claim**

Defensible version: `ContentView.swift:248` performs a `DeviceActivityCenter` daemon call on the main thread inside the root view's `onAppear` — the only production call of that class left off `Schedule`'s serial queue, missed by the fix recorded in status.md:8. Consequence as evidenced: an unquantified main-thread block on the pre-first-frame launch path. The claim's escalation to "watchdog kill / crash-on-open" rests on a single unreproduced iOS 18-beta forum anecdote and should not be stated as the impact; the deadlock scenario that IS corroborated in that thread is `startMonitoring` called from inside `intervalDidEnd` in the monitor extension, which this repo does not do (the extension never calls `DeviceActivityCenter` at all). Drop the ordering-with-the-queue half of the mechanism — at `onAppear` nothing is enqueued yet, and `onAppear` does not re-run on foreground return, so it has no reachable consequence.

**Failure trace (re-derived from source by the verifier)**

User taps the Unplug icon → `ScreenTimeShieldApp.body` builds the single `WindowGroup` → SwiftUI evaluates `ContentView.body` → before the first frame is committed, `.onAppear` (ContentView.swift:245) runs on the main thread → `model.loadSelection()` (:246, PropertyList decode from the app-group defaults) → line :248 constructs a `DeviceActivityCenter` and reads `.activities`, blocking the main thread for the duration of that daemon interaction → only then does the main thread return to CoreAnimation and the first content frame is drawn. Persisted state afterwards: `is_armed` in the app group is overwritten with whether the daemon currently reports `.daily` registered (this is the intended source-of-truth sync and is correct in itself). What the user sees: nothing at all until the read returns — the gradient background with no content and no touch handling. This trace is complete and reachable on every launch; the part I cannot supply from source is the duration of the blocking read, and therefore whether "until the read returns" is imperceptible or a visible hang.

**Apple API semantics checked**

1) Apple docs for `DeviceActivityCenter.activities` (developer.apple.com/documentation/deviceactivity/deviceactivitycenter/activities): no statement about cost, blocking, threading, or actor isolation — nothing supports or refutes "expensive synchronous XPC". 2) Apple Developer Forums thread 761299 (fetched): the candidate's quote is accurate — kgaidis writes "My application code (which is a lot more complicated) seems to deadlock on calling DeviceActivityCenter.activities" — but it is an aside in a report whose reproducible case is `startMonitoring` called from `intervalDidEnd` inside the monitor extension; iOS 18 beta 4 only, not reproducible on 17.6, filed as FB14664238, no Apple reply, still unanswered after a Mar 2025 bump. 3) Searched for independent reports of the `activities` getter being slow or blocking: found none. Found corroborated reports of `DeviceActivityCenter.startMonitoring` causing multi-second UI freezes/crashes (forums 770223 and the device-activity tag), which supports the repo's comment about start/stop but not the transfer to a property read. 4) SwiftUI `onAppear` semantics: documented as "Adds an action to perform before this view appears", i.e. synchronous on the main thread ahead of the view being displayed — consistent with the claim that this is pre-first-frame. Net: the threading claim is confirmed; the cost claim is unconfirmed in either direction.

**Proof path**

Not provable today. The call sits inline in a SwiftUI `.onAppear` closure in `ContentView`, so nothing in `UnplugCore` (pure) or an `SKTestSession` can reach it, and no unit test can measure a system daemon's round-trip cost anyway. To get any test value you would have to extract the arm-state sync into a seam — e.g. an `ArmStateSync` type in `UnplugCore` with an injected `activities: () -> [String]` provider and a completion delivered on a caller-supplied queue — after which a test could assert that the provider is invoked off the main thread and that the resulting `isArmed` assignment lands back on main. That tests the shape of the fix, not the defect. The defect itself is only observable as a main-thread duration in an on-device Instruments Time Profiler / hang trace of launch (worst cases: first launch after reboot, and a launch coinciding with an interval boundary while the monitor extension is being spun up).

---

## Refuted (1)

Reported by discovery, killed by verification. Recorded so the sweep's precision is auditable.

### `V08` · Re-registering .daily mid-block (selection edit) tears the block down / strands inside_interval

- **🟡 Nit** · impact **bypass** · needs device
- **Feature** F4 · **Discovery IDs** F4-STATE-02, F4-XPROC-01 (2 agents found this independently)
- **Already in status.md:** No matching entry. status.md has no record of mid-block re-registration. The only adjacent item is under Bugs → "Arm-confirm UI stall": "Note: `Schedule` still swallows `startMonitoring` errors (`catch { print }`) — likely culprit if a block ever silently fails to register; surface/validate next." That is the one sub-path where this candidate's teardown would actually become durable, and it is already recorded as open. The two undocumented open bugs ("Notifications bug", "Outstanding bug mentioned in README") have no stated mechanism, so I cannot claim overlap.

**Verifier's reasoning**

The code the two write-ups cite is real and correctly quoted, but the user-visible consequence both of them claim is contradicted by Apple's documented behaviour of `startMonitoring`.

What I confirmed in source:
- `ScreenTimeShield/Schedule.swift:32-40` — `setSchedule` does `center.stopMonitoring([activityName])` then `try center.startMonitoring(activityName, during: schedule, ...)` on a private serial queue, so the stop/start pair is ordered and back-to-back.
- `ScreenTimeShield/ContentView.swift:59-68` — `applySchedule()`'s guard is `guard model.isArmed, !isExpired, !model.isEmpty()`. There is genuinely no `!insideInterval` check, and I grepped for one: no other guard exists anywhere on this path.
- `ScreenTimeShield/ContentView.swift:218-229` — `.onChange(of: model.selectionToRestrict)` reaches `applySchedule()` (line 228) even when `insideInterval` is true, because the removal guard at :221 only fires when `validateRestriction()` fails, and a cold-launch reload or an app *addition* both pass validation (`Model.swift:74-81`).
- Reachability on a plain cold launch is real: `Model.selectionToRestrict` starts as an empty `FamilyActivitySelection()` (`Model.swift:40`), `Model.shared` is the injected `@StateObject` (`ScreenTimeShieldApp.swift:17`), and `onAppear` does `loadSelection()` (`ContentView.swift:246`) then `isArmed = DeviceActivityCenter().activities.contains(.daily)` (:248) — so the onChange fires on the following body pass with `isArmed` already true. Mid-block "Add" is also reachable (`AppCard.swift:35-42` renders the Add button unconditionally when the selection is non-empty; `openPicker()` only gates on `isExpired`).
- `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:68-79` — `intervalDidEnd` for `daily`/`hourly` does `clearRestrictions()` + `insideInterval = false`, with no ownership/refcount.

Where both claims break: neither branch of the claimed outcome survives Apple's `startMonitoring(_:during:events:)` documentation, which states verbatim "The application extension's [monitor] may begin receiving callbacks as soon as the system calls this method if the activity's scheduled interval is ongoing." The re-registered 09:00–17:00 schedule *is* ongoing at 12:00, so the documented behaviour is that `intervalDidStart(.daily)` is re-delivered immediately after the `intervalDidEnd(.daily)` caused by the stop — which runs `loadSelection()` + `setRestrictions()` + `insideInterval = true` (`DeviceActivityMonitorExtension.swift:60-63`), restoring the shields and the flag.

That kills F4-XPROC-01's stated impact ("clears every shield for the remainder of the window", "`.daily` re-registered for tomorrow") and both branches of F4-STATE-02: branch (b)'s ~29-hour lockout requires `startMonitoring` to resolve to tomorrow (contradicted by the quote above) *and* is internally inconsistent — it asserts "the shields stay applied" while simultaneously conceding that `stopMonitoring` on an ongoing interval delivers `intervalDidEnd`, which clears them. Branch (a)'s "block is over at 12:00" needs the teardown to be durable, which it isn't.

Worse for the claims: this stop/start is load-bearing, not a bug. It is the only mechanism by which an app added mid-block ever gets shielded — the main app never calls `setRestrictions()`, only the extension does at `intervalDidStart`. So the "action that is supposed to only grow the enforced set empties it" reading is backwards.

Residual (not enough to report as filed): there is an unguarded transient in which shields are down between the extension's `intervalDidEnd` and `intervalDidStart`, and `inside_interval` flaps true→false→true. To convert that into the claimed bypass a user would have to (a) hit a body re-render inside that window — hard, since the extension's cross-process write does not invalidate the app's views at all, and (b) tap the momentarily-enabled CTA before `intervalDidStart` lands. I could not write an honest trace for that; it is a sub-second-to-seconds race, not a repeatable escape. The one path where the teardown *is* durable is `startMonitoring` throwing (`.excessiveActivities`) into the swallowed `catch { print }` at `Schedule.swift:37-39` — which is already the open item in status.md, not new.

**Apple API semantics checked**

Fetched both Apple doc JSON endpoints directly (developer.apple.com/tutorials/data/...). `DeviceActivityMonitor.intervalDidEnd(for:)`: "An activity ends when someone first uses the device outside the activity's scheduled time interval or when your app stops monitoring an activity with an ongoing interval. In other words, the system only invokes this method when the device is in use." — this half of the claim is confirmed. `DeviceActivityCenter.startMonitoring(_:during:events:)`: "If the app already monitored the activity, this method overwrites the previous schedule and events." and, decisively, "The application extension's [monitor] may begin receiving callbacks as soon as the system calls this method if the activity's scheduled interval is ongoing." — this is what refutes the claimed consequence; the re-registration of an in-progress window is documented to re-deliver callbacks, not to defer to tomorrow. `intervalDidStart(for:)`: "An activity starts when someone first uses the device within the activity's scheduled time interval ... the system only invokes this method when the device is in use" — the device is in use in every trace offered, so the re-start callback is not gated out. `stopMonitoring(_:)` itself documents nothing about callbacks (consistent with the intervalDidEnd page carrying that semantic). Residual unverified: the *latency* between the two callbacks, i.e. the width of the unshielded transient — Apple documents neither ordering timing nor extension wake latency.

**Proof path**

Not provable today. The decision point is `applySchedule()`, a private method on the `ContentView` struct (ScreenTimeShield/ContentView.swift:59-68) that reads `Model.shared` state and calls the static `Schedule.setSchedule`, which constructs a live `DeviceActivityCenter()` inside a `DispatchQueue.async` (Schedule.swift:32-40) — no seam, no injectable center, and `UnplugCore` deliberately excludes DeviceActivity/StoreKit. SKTestSession is irrelevant here. To make it testable you would need to (1) extract the "should we re-register?" predicate into a pure `UnplugCore` function over (isArmed, isExpired, isEmpty, insideInterval) so a test could assert re-registration is/isn't suppressed mid-block, and (2) put `DeviceActivityCenter` behind a protocol so a spy could assert the stop→start call order. Even with both, the actual question this candidate turns on — whether `startMonitoring` on an in-progress interval re-delivers `intervalDidStart`, and how wide the unshielded gap is — is daemon behaviour and can only be settled on a device by watching the extension's `print` output across a mid-block cold launch.

---
