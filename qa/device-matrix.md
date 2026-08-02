# Device matrix — manual QA script for features 3, 4, 9

> ## ⚠️ Read this first (added 2026-08-02)
>
> This script was written **before any fixes**, to reproduce bugs. Several are now fixed, so those
> steps have flipped meaning: you are confirming a fix holds, not watching a bug happen. Where a step
> says "expected (buggy) result", expect the *opposite* for anything in this list.
>
> **Already fixed — the step should now pass, and a failure is a regression:**
> `V01` (end handle at 24:00), `V02` (DST drift), `V04` (overlapping handles), `V05` (overnight risk
> gate), `V22` (cutover date), `N1` (trial countdown), `N4` (times-stopped counter reaching the app),
> and swallowed `startMonitoring` errors.
>
> **Not yet fixed — reproduce as written:** `V07`, `V11`, `V12`, `V14`, `V15`, `V16`, `V18`, `V19`,
> `V20`, `V21`.
>
> **Still genuinely unknown, and the reason this document exists:** `V13`, `V25`, `N3`, plus the
> `intervalDidEnd` semantics that `V07`'s fix design depends on. Both outcomes are informative —
> write down what actually happens.
>
> Current live status per finding is in `qa/README.md`.

Everything in this pass that **only a real iPhone can settle**. The simulator cannot authorize Family
Controls, so real app tokens, shields, `ManagedSettingsStore` enforcement and the monitor extension's
`intervalDidStart`/`intervalDidEnd` callbacks are unobservable there. This script covers:

- every finding in `qa/findings.md` marked **needs device**: `V07`, `V09`, `V11`, `V14`, `V19`, `V20`, `V21`
- all three **UNCERTAIN** findings, whose whole point is to be settled here: `V12`, `V13`, `V25`
- one optional re-check of the single **REFUTED** device finding, `V08`, because the Apple semantic it
  was refuted on (re-registering an in-progress interval re-fires `intervalDidStart`) is load-bearing
  for four other findings

Ordered so expensive state — a real block window, an expired trial, a revoked authorization — is
established once and reused by several tests. Work top to bottom. Steps are numbered continuously;
if something fails, quote the step number.

| Group | Settles | Wall clock | Notes |
|---|---|---|---|
| 0 · Prep | — | ~20 min | Flags, QA menu, breakpoints, Console, panic recovery |
| 1 · Launch path | V12 | ~15 min | Needs a post-reboot cold launch |
| 2 · Trial anchor | V25 | ~10 min | **Deletes the app.** Must run before any state is built |
| 3 · One 20-min armed window | V11, V14 (legs 1–2), V08, V12 rider | ~40 min | The core boundary-observation state |
| 4 · The race tap | V14 (leg 3) | ~20 min | **Can brick `inside_interval`** |
| 5 · Empty selection while armed | V09 | ~30 min | |
| 6 · Quick-restrict collision | V07 | ~80 min | Longest wait; device must stay undisturbed |
| 7 · Expired-trial cluster | V20 → V19 → V21 | ~60 min | One expiry, three findings |
| 8 · Revocation mid-block | V13 (branch A vs B) | ~40 min | Last, because it may end in delete + reinstall |

Total ≈ 4½ hours, most of it waiting. If you only have an hour, run **steps 27–40** (the V11/V14
severity fork), **group 6** (V07 — the only actual bypass in the pass) and **step 89** (the Apple
semantic four findings lean on). Those three change verdicts; the rest confirm them.

---

## Conventions

**PASS / FAIL is about the app, not about the test.** Several findings are UNCERTAIN precisely because
the Apple behaviour is unknown, so both outcomes are results worth writing down:

- **PASS** — the app behaved as `qa/invariants.md` requires. The finding does **not** reproduce on this
  device/iOS build. Record it as refuted-on-device, with the build number — that is a real finding too.
- **FAIL** — the finding reproduces as described. Confirmed on device.
- **UNSETTLED** — the trigger could not be landed (a race too tight to hit, a callback that never
  arrived). Record verbatim what did happen; do not round it to PASS.

**Record for every step:** device model, iOS build (Settings → General → About → *Version*, including
the letter suffix), app build number (`CURRENT_PROJECT_VERSION`, currently 13), wall-clock time, and
the device time zone. There is a results table at the end of this file.

**Never guess at state.** Every step names either a UI element to read or an app-group key to inspect.
The app-group suite is `group.screentimeshield` throughout. Keys that matter:

| Key | Written by | Meaning |
|---|---|---|
| `inside_interval` | monitor extension only (`DeviceActivityMonitorExtension.swift:63`/`:77`) | "a block is active" — gates every lock in the UI |
| `is_armed` | app (`Model.swift:32`), resynced at `ContentView.swift:248` | daily schedule registered |
| `enforcement_allowed` | app only (`AccessController.swift:118`) | the gate the extension reads at `:42-44` |
| `trial_start` | app (`AccessController.swift:84-90`) | sole witness that a trial ever began |
| `qa_force_full_access` | QA menu only | forces full access; **read by release builds** (V24) |
| `has_selection`, `block_outside_window`, `start`, `end`, `ScreenTimeSeletion` | app | selection + window config |

---

## Group 0 — Prep

### Flags that make this tractable

**`UNPLUG_SKIP_FC`** (`ScreenTimeShield/AccessController.swift:28`) — set as a scheme environment
variable, it:

- forces `fcAuthorized = true` without Screen Time authorization (`AccessController.swift:36`)
- skips the launch-time authorization prompt (`ScreenTimeShieldApp.swift`, `AppDelegate`)
- skips the live `AuthorizationCenter.$authorizationStatus` subscription (`AccessController.swift:47`)
- **skips `refreshAccess()` entirely** — both `ContentView`'s `.task` (`:256-262`) and the
  `scenePhase == .active` handler (`ScreenTimeShieldApp.swift:95-104`) return early

**Leave it unset for every step in this document.** It exists so the paywall UI can be exercised on a
simulator. Here it would defeat the point twice over: no real enforcement to observe, and — because
`refreshAccess()` never runs — `enforcement_allowed` is never recomputed, which silently changes the
outcome of V19, V20 and V21. If you find yourself with a confusing F9 result, check the scheme first.

**The QA menu** is reachable only by uncommenting the `Section` at `ScreenTimeShield/SettingsView.swift:26-29`
(hidden for production per `status.md`; the comment at `:25` says so). Re-enabling it gives you, from
`QAMenuView.swift`: current access state / trial days / times stopped / full-access flag, *Start trial
now*, *Expire trial*, *Reset trial*, *Force full access*, *Open paywall*, and **Reset to fresh install**
(`AccessController.qaResetToFreshInstall()`, which stops all activities, clears restrictions, wipes the
app-group domain and resets `inside_interval`). That last one is your main recovery tool — **without it,
recovery means deleting and reinstalling the app.**

**Steps**

1. Open the results table at the bottom of this file and fill in device model, iOS build, app build,
   time zone, and today's date.
2. Xcode → scheme editor → Run → Arguments: confirm **no** `UNPLUG_SKIP_FC` environment variable is
   set (and no `XCTestConfigurationFilePath`). *Inspect:* the Environment Variables list is empty or
   the row is unticked.
3. Uncomment `ScreenTimeShield/SettingsView.swift:26-29` to expose the QA / Debug entry.
   **Do not commit this.** *Inspect:* after building, the gear → Settings sheet shows a "QA / Debug"
   row below the refocus toggle.
4. *Optional but recommended:* add three read-only rows to `QAMenuView`'s "Current state" section that
   print the raw `inside_interval`, `is_armed` and `enforcement_allowed` values from the app group.
   Saves most of the debugger work below. Temporary scaffolding — do not commit.
5. Confirm the scheme's StoreKit configuration still points at `StoreKit.storekit` (needed for the V21
   purchase in group 7; works on a physical device when launched from Xcode).
6. Build and run a **Debug** build on the device and leave Xcode attached. *Inspect:* the app launches
   and the Family Controls prompt appears (approve it).
7. Create these four breakpoints, all **disabled** for now — you will enable them individually:
   - **BP-A** `ContentView.swift:248` — the `DeviceActivityCenter().activities` sync in `onAppear`.
     A pause point with app-module Swift context, so `DeviceActivity` types resolve in expressions.
   - **BP-B** `ContentView.swift:51` — `if model.insideInterval { return }` in `onPrimary()`.
     Fires on every primary-CTA tap; this is where you read the flag *as the tap reads it*.
   - **BP-C** `ContentView.swift:83` — first line of `stop()`. If this is hit after BP-B, the tap got
     through the lock.
   - **BP-D** `ContentView.swift:246` — `model.loadSelection()`, one line before BP-A, for reading
     state *before* the arm resync overwrites `is_armed`.
8. Verify the debugger recipes work. Pause the app (Xcode debug bar → Pause, or hit BP-A by
   backgrounding and cold-launching) and run, in the console:
   ```
   e -l swift -- UserDefaults(suiteName: "group.screentimeshield")!.dictionaryRepresentation() as NSDictionary
   e -l swift -- UserDefaults(suiteName: "group.screentimeshield")!.bool(forKey: "inside_interval")
   e -l swift -- UserDefaults(suiteName: "group.screentimeshield")!.object(forKey: "trial_start")
   e -l swift -- DeviceActivityCenter().activities.map { $0.rawValue }
   ```
   *Expect:* the dictionary dump and a `["daily", ...]`-shaped array (empty at this point).
   The `activities` expression needs a frame in a file that imports `DeviceActivity` — use BP-A.
   *Inspect:* all four expressions evaluate without error. If they don't, do step 4 instead; you
   cannot run this script without a way to read those keys.
9. Open **Console.app** on the Mac, select the device in the sidebar, start streaming, and filter
   `Process` = `CustomDeviceActivityMonitor`. Save the search. This is the only way to see the
   extension's callbacks — Xcode's console is attached to the app process, not the extension.
   The lines you will be reading all day:
   - `Interval did start for: daily` / `: hourly` / `: notificationSchedule` (`Extension:50`)
   - `Interval did end for: daily` / `: hourly` (`Extension:71`)
   - `Enforcement not allowed (access lapsed) — skipping restriction.` (`Extension:57`)
   *Inspect:* if no output ever appears from that process, fall back to Xcode → Debug → Attach to
   Process by Name → `CustomDeviceActivityMonitor` (it will attach when the system launches it).
10. Pick **two ordinary third-party apps** you can open in one tap and that you don't need during the
    session (a game, a social app). Note their names in the results table. Avoid Safari and system
    apps — web-domain shielding behaves differently and would muddy the enforcement checks.
11. Gear → Settings → turn **"Send refocus notifications" off**. This cuts the notification spam and
    the `notificationSchedule` log noise for the rest of the session. Side effect, harmless here:
    `ContentView.swift:242` calls `Schedule.stopMonitoring([.notificationSchedule])`.
    *Inspect:* `DeviceActivityCenter().activities` no longer lists `notificationSchedule`.

### Safety rules and panic recovery — read before step 12

**Hazard 1 — the unstoppable ~24h block (V01).** `ScheduleRangeSlider.dateAtMinute()` falls back to
`?? Date()` when the minute is 1440, so **dragging the end handle to the far right of the track
silently sets the end time to "now"**. In Block-these-hours mode with `now < start`, the registered
interval then wraps and you have armed a ~24-hour block that the UI will not let you stop. While
setting windows in this script: drag handles only to interior positions, and always confirm the
handle pill reads the time you intended before tapping Start. If the pill reads the current time when
you dragged to the right edge, you have reproduced V01 — do not arm.

**Hazard 2 — a bricked `inside_interval`.** Groups 4 and 8 can deliberately leave
`inside_interval = true` with nothing registered to ever clear it (invariant F4.3). In that state the
CTA is a disabled "Blocking", quick-restrict is greyed, the slider has no gesture, and no tap
recovers — this is the finding, not a mistake.

**Hazard 3 — an expired trial and a stray QA override.** `qa_force_full_access` is read by release
builds and cannot be cleared once set (V24). Clear it before any F9 test, and clear it again at
teardown.

**Panic recovery, in order of preference:**

| Situation | Recovery |
|---|---|
| `inside_interval` stuck true | Debugger: `e -l swift -- UserDefaults(suiteName: "group.screentimeshield")!.set(false, forKey: "inside_interval")` then **force-quit and relaunch** (the write publishes nothing to the UI — that is V11) |
| Any block you can't stop | Debugger: `e -l swift -- DeviceActivityCenter().stopMonitoring()` then `e -l swift -- Model.shared.clearRestrictions()` |
| State beyond repair | QA menu → **Reset to fresh install** (stops all activities, clears shields, wipes the app group, resets the model) |
| QA menu unavailable, or reset didn't take | **Delete the app and reinstall.** Deleting also tears down its `ManagedSettingsStore`, so it lifts any active block. Costs you the Screen Time authorization, the app selection, the window and `times_stopped` |
| Trial state wrong | QA menu → *Reset trial* / *Start trial now*; or debugger `removeObject(forKey: "trial_start")` |
| Accidentally hold full access | Xcode → Debug → StoreKit → Manage Transactions → delete the transaction; and QA menu → *Force full access* off |

12. Confirm you can reach the QA menu and that **Force full access** reads off and **Access state**
    reads `trial`. *Inspect:* QA menu "Current state" rows. Fix with the table above if not.

---

## Group 1 — Launch path (V12)

**Settles:** `V12` (UNCERTAIN) — `DeviceActivityCenter().activities` read synchronously on the main
thread inside the root view's `onAppear` (`ContentView.swift:248`), the one call the off-main fix in
`status.md` missed. Code truth is confirmed; the **cost** is unknown, and cost is the whole finding.

**Verdict rule:** duration of that read on the main thread, pre-first-frame:
**> ~50 ms ⇒ FAIL** (important — it is a visible launch stall and should move off-main like the rest of
`Schedule`); **< ~5 ms ⇒ PASS** (nit, no user-visible defect; record the number and close it).
Anything in between: record the number and call it a nit with a note.

Cheap and non-destructive. Do it first because it wants a post-reboot launch, which also gives the
DeviceActivity daemon a clean start for everything that follows.

13. Reboot the device. Do not launch Unplug yet.
14. On the Mac: Instruments → **Time Profiler** → target the Unplug app on the device → Record.
    Let Instruments launch the app (not Xcode — a debugger-attached launch distorts timings).
    Stop recording as soon as the first content frame is on screen.
    *Inspect:* the recording contains the app launch.
15. Filter the call tree to the **main thread**, invert nothing, and search the symbols for
    `activities` / `DeviceActivityCenter` / `DAActivity`. Record self and total weight, and whether
    it appears under `ContentView` `onAppear`. *Expect:* a single synchronous call on the main thread
    before the first frame.
16. Repeat the measurement once more on a second cold launch (no reboot). *Inspect:* whether the
    first-launch number is an outlier (daemon connection warm-up) or the steady state.
17. Record the verdict per the rule above. Note in the results table that the third measurement — a
    launch that coincides with an interval boundary, while the monitor extension is being spun up —
    is taken later, at **step 43**, when a block window actually exists.

---

## Group 2 — Trial anchor across delete + reinstall (V25)

**Settles:** `V25` (UNCERTAIN) — no reinstall-proof trial anchor. `trial_start` lives only in the
app-group `UserDefaults`; the two verifiers disagreed about whether iOS clears an app-group container
when the last member app is deleted. Nothing else in the repo could witness a repeat trial.

**Verdict rule:** after delete + reinstall, **trial chip reads "7 days left in trial" and `trial_start`
is absent ⇒ FAIL** (the container was cleared; trials are farmable by reinstall).
**Chip reads "Trial ended · Unlock Unplug" and `trial_start` survives ⇒ PASS** (the container
persisted; the anchor is adequate as-is on this iOS build).

> **Destructive — and this is why it runs second.** Step 21 deletes the app and every app-group key
> with it: selection, window, `is_armed`, `times_stopped`, `trial_start`. There is nothing to recover
> because there is nothing built yet. Run this **before** you invest in a selection and a window.
> Note the honest caveat: reinstalling the same dev-signed build via Xcode is a proxy for an App Store
> reinstall, not identical to it. Record that in the results.

18. QA menu → **Expire trial**. *Expect:* Access state reads `expired`; the main screen's trial chip
    reads "Trial ended · Unlock Unplug". *Inspect:* QA "Current state" rows + the chip.
19. Debugger (BP-A or a manual pause): read and write down the exact values of `trial_start`,
    `enforcement_allowed` and `is_armed`. *Expect:* `trial_start` ≈ 8 days ago,
    `enforcement_allowed == false`.
20. Home screen → long-press Unplug → Remove App → **Delete App**. *Inspect:* the app and its icon are
    gone; do not reinstall from the App Store, use Xcode.
21. Reinstall from Xcode and launch. Approve the Family Controls prompt if it appears.
    *Inspect:* the app opens on the empty "Choose apps & websites" state.
22. Read the **trial chip** verbatim. *Inspect:* the chip text on the main screen.
23. Debugger: read `trial_start`, `enforcement_allowed`, `is_armed`, `has_selection`,
    `ScreenTimeSeletion`. *Expect (FAIL branch):* all absent, `enforcement_allowed == true`.
    *Expect (PASS branch):* `trial_start` still ≈ 8 days ago.
24. Record the verdict per the rule above, plus the iOS build — this result is build-specific and does
    not generalize.
25. *Optional, 10 min, higher-value than the main test:* the **update** variant. Bump
    `CURRENT_PROJECT_VERSION`, build and install **over the top without deleting**, then read
    `trial_start` / `has_selection` / `is_armed` again. Field reports claim app-group containers are
    sometimes recreated **empty on an ordinary update** — which would silently wipe a user's armed
    block, a worse defect than the trial reset. *Expect:* everything survives. **Anything missing ⇒
    escalate immediately**, note it as a new finding, not as part of V25.
26. Leave the app freshly installed with a live trial. *Inspect:* QA menu Access state reads `trial`,
    Force full access off.

---

## Group 3 — One 20-minute armed window, app foregrounded across both boundaries

**Settles:** `V11` (both legs + the severity fork both second opinions demanded), `V14` legs 1–2,
optionally `V08` and the group-1 rider for `V12`.

This is the reusable expensive state: a real block that starts in a few minutes and ends 20 minutes
later, so you get a **start boundary and an end boundary inside half an hour** instead of waiting out
a 9-hour overnight window. The slider snaps to 5 minutes and enforces a 15-minute minimum gap
(`ScheduleRangeSlider.swift:24-25`), so 20 minutes is the shortest comfortable window.

### Setup

27. Tap the app card → pick the two apps from step 10 → Done.
    *Inspect:* the app list shows both with real icons (a device-only check that `status.md`'s
    redesign follow-ups also ask for).
28. Note the current time. Compute **T_start** = the next 5-minute mark at least 4 minutes out, and
    **T_end** = T_start + 20 min. Do not run this near midnight (a wrapping window is a different
    test) and do not let T_end cross midnight.
29. Drag the **start** handle right until its pill reads T_start. Then drag the **end** handle left
    until its pill reads T_end. *Expect:* both pills read your intended times.
    *Inspect:* the handle pills, not the axis labels. Two hazards here: the far-right end position
    silently means "now" (V01, hazard 1); and at a 20-minute width the start handle is fully occluded
    by the end handle (V04), so if you need to re-adjust, drag the end handle right first to separate
    them.
30. Confirm the mode picker reads **Block these hours** (not Allow only).
    *Inspect:* the segmented control in the schedule card.
31. Tap **Start blocking**. *Expect:* no confirmation alert (a 20-min block-mode window leaves 1420
    free minutes and `now` is outside it, so `isRiskyToArm()` is false). **If a confirm alert appears,
    you mis-set the window — cancel, and re-check the pills.**
32. Debugger (BP-A on a relaunch, or pause): *Expect* `is_armed == true`,
    `DeviceActivityCenter().activities` contains `"daily"`, `inside_interval == false`.
    *Inspect:* those three values; write them down. Then continue execution and disable BP-A.

### The start boundary (V11 leg 1, V14 leg 2)

33. Bring Unplug to the foreground and **keep it there**, screen on, hands off. Do not tap anything.
    Watch Console.app.
34. At T_start: record the timestamp of `Interval did start for: daily` from Console, to the
    millisecond, and subtract T_start:00. This is the **extension launch latency** — the width of the
    V14 window, which no Apple documentation quantifies. *Expect:* something between tens of
    milliseconds and several seconds. *Inspect:* Console timestamp. If the line never arrives within
    5 minutes of continuous device use, record **UNSETTLED for V14** and note it as an
    enforcement-delivery failure in its own right (forum-reported, and it would also mean V19/V20's
    premise needs re-checking).
35. Without touching the screen, read the whole main screen and write down verbatim: the status banner
    text and dot colour, the app-card header, the primary CTA title and whether it shows a lock glyph
    or looks enabled, the "Restrict for next hour" button's colour, whether the schedule caption
    "Schedule locked while a block is active" is present, and whether the mode picker looks enabled.
    - **Banner still reads "Block inactive" while Console has logged the start ⇒ V11 leg 1 FAIL**
      (the extension's cross-process `inside_interval` write publishes nothing; `Model.swift:25` is
      `@AppStorage` on a plain `ObservableObject`).
    - **Banner flips to "Block active" with the pulsing dot and everything locks ⇒ V11 PASS** — record
      it, because it would mean `@AppStorage` in a class does invalidate the view graph, contradicting
      both verifiers' swiftinterface argument.
    *Inspect:* `StatusBanner`, `AppCard` header, `PinnedActions` both buttons, `ScheduleCard` caption
    and picker.
36. **The severity fork.** Enable **BP-B** and **BP-C**, then tap the primary CTA (which is rendering
    as an enabled "Stop blocking"). When BP-B hits, run `e -l swift -- model.insideInterval` and
    `e -l swift -- UserDefaults(suiteName: "group.screentimeshield")!.bool(forKey: "inside_interval")`,
    then continue.
    - **Both read `true`, BP-C is never hit ⇒ the tap-time read is fresh.** The tap is a dead no-op:
      V11 and V14 are a status-integrity/edit-lock defect, **not** a bypass. Record as
      **FAIL (status-display class)**.
    - **Either reads `false`, BP-C is hit ⇒ the read is cached and `stop()` runs mid-block.** That is
      a genuine bypass: `stop()` deregisters the repeating `.daily` and clears the shields. Record as
      **FAIL (bypass class)** and reclassify V11/V14 upward in `qa/findings.md`.
    This single measurement is what both second opinions said would settle the classification. Do not
    skip it, and record the raw values.
37. Continue execution, disable BP-B/BP-C, background Unplug and open one of the restricted apps.
    *Expect (dead-tap branch):* the Unplug shield appears. *Expect (bypass branch):* it opens
    normally. *Inspect:* the shield screen, and `times_stopped` in the QA menu (the shield extension
    increments it).
38. Debugger: read `inside_interval`, `is_armed`, and `DeviceActivityCenter().activities`.
    *Expect (dead-tap branch):* `true`, `true`, contains `"daily"`.
    *Expect (bypass branch):* `is_armed == false` and `activities` no longer contains `"daily"` — and
    note that because `.daily` was registered `repeats: true`, that tap killed **every** future
    night's block, not just this one (V14's sharpened harm).

### The end boundary (V11 mirror case)

39. If the block survived step 36: foreground Unplug again and keep it there through T_end.
    If the block was torn down: re-run steps 28–32 with a fresh 20-minute window, wait out its start,
    then foreground and hold through its end.
40. At T_end: Console logs `Interval did end for: daily`. Without touching the screen, read the main
    screen again.
    - **Still shows "Block active", the lock caption, a disabled "Blocking" CTA, greyed quick-restrict
      and an inert slider ⇒ V11 mirror FAIL** — the user cannot re-arm or edit until something
      unrelated re-renders the view.
    - **Unlocks by itself ⇒ PASS for the mirror leg.**
    *Inspect:* same element list as step 35.
41. If it stayed locked: tap the gear (a `ContentView` `@State` mutation) and close the sheet.
    *Expect:* the UI snaps to the correct unlocked state. *Inspect:* CTA title reverts to "Stop
    blocking"/"Start blocking". This records the incidental self-heal the second opinion insisted on,
    and it bounds V11's severity.
42. Debugger: read `inside_interval` (*expect* `false`), `is_armed`, `activities`.

### Riders while this state exists

43. **V12 rider.** Arm one more 20-minute window, then use Instruments (as in steps 14–15) to record a
    cold launch **timed to land within a few seconds of T_start**, while the monitor extension is
    being spun up. *Inspect:* the main-thread duration of the `activities` read under `onAppear`.
    This is V12's worst realistic case; add it to the group-1 verdict.
44. *Optional — V08 (refuted) spot-check, and the cross-cutting semantic below.* With a block
    **active**, open the app picker and **add** a third app. Watch Console.
    *Expect:* `Interval did end for: daily` (delivered by the `stopMonitoring` inside
    `Schedule.setSchedule`) immediately followed by `Interval did start for: daily`, and the shields
    back — including on the newly added app. *Inspect:* the Console timestamps (record the gap between
    the two lines — that is the width of the unshielded transient nobody has measured), then open the
    new app and confirm it is shielded.
    **Both lines present and shields restored ⇒ V08's refutation holds (PASS).**
    **Only the end line, shields gone for the rest of the window ⇒ V08 was wrongly refuted — reopen it.**

> ### Cross-cutting semantic: does re-registering an in-progress interval re-fire `intervalDidStart`?
> Four findings lean on this and no verifier could confirm it from Apple's docs: V07's cold-launch
> self-heal, V08's refutation, V09's recovery path, and V21's workaround. Steps **44** and **89**
> measure it from opposite directions. Whatever you observe, write it into `qa/findings.md` once —
> it is the highest-leverage single fact in this document.

45. Tear down: tap "Stop blocking" (or wait out the window). *Inspect:* `is_armed == false`,
    `activities` empty, `inside_interval == false`, and a restricted app opens normally.

---

## Group 4 — The race tap (V14 leg 3)

**Settles:** `V14` leg 3 — the permanent-lockout tail. If the Stop tap lands inside the
extension-launch gap measured at step 34, `stop()` deregisters `.daily` and clears the shields, then
`intervalDidStart` arrives anyway and writes `inside_interval = true`. Nothing is registered any
more, so `intervalDidEnd` never comes and the flag can never be cleared: invariant **F4.3**, the
lock-out state.

**Verdict rule:** **`is_armed == false` + `inside_interval == true` + `activities` empty, with every
recovery control dead ⇒ FAIL** (confirmed permanent lockout).
**The extension's start callback is not delivered after a `stopMonitoring`, or `inside_interval` ends
up `false` ⇒ PASS** (the leg self-heals; downgrade it to a latent invariant violation as the first
verifier did).
**Cannot land the tap in 3 attempts ⇒ UNSETTLED**, and note the latency from step 34 as the reason.

> **Destructive — read the recovery first.** This step is *designed* to brick the app into a false
> "Blocking" state with no in-app way out. Recovery, in order:
> 1. `e -l swift -- UserDefaults(suiteName: "group.screentimeshield")!.set(false, forKey: "inside_interval")`, then force-quit and relaunch (the write does not refresh the UI — that is V11).
> 2. QA menu → **Reset to fresh install** (only available because you uncommented `SettingsView.swift:26-29`; in a production build this menu is gone and this state is unrecoverable in-app).
> 3. Delete and reinstall, then redo steps 27–32.
> If step 34's latency was under ~200 ms, expect this to be hard to land at all. That is itself the
> answer to "how exploitable is it".

46. Write down which recovery you will use before you start.
47. Set a fresh window per steps 28–31 (T2_start at least 5 minutes out) and arm. *Inspect:*
    `is_armed == true`, `activities` contains `"daily"`, `inside_interval == false`.
48. Keep Unplug foregrounded. With a separate seconds-accurate clock, tap **Stop blocking** as close to
    T2_start:00 as you can — aiming inside the latency window from step 34. Up to 3 attempts (each
    attempt needs a fresh window, so re-run step 47 between tries).
49. Watch Console: *Expect* `Interval did start for: daily` **after** your tap. *Inspect:* the Console
    timestamp versus the moment of the tap. If the start line arrives before the tap, you missed the
    window — try again.
50. Debugger: read `inside_interval`, `is_armed`, `activities.map { $0.rawValue }`.
51. If the brick state is present, confirm it is a true dead end before recovering. *Expect:* CTA is a
    disabled "Blocking" with a lock glyph; "Restrict for next hour" greyed; slider handles do not
    respond to drag; mode picker disabled; re-selecting apps in the picker produces **no** Console
    output (because `applySchedule()` hard-guards on `model.isArmed`, `ContentView.swift:60`);
    force-quit and relaunch preserves all of it. *Inspect:* each control in turn, plus Console silence.
52. Recover per step 46 and verify: `inside_interval == false`, CTA usable again.

---

## Group 5 — Empty selection under an armed window (V09)

**Settles:** `V09` — deselecting every app while armed-but-inactive leaves `.daily` registered, so the
window opens, `inside_interval` latches true, the UI locks, and **nothing is shielded**. Also settles
the recovery path the two verifiers disagreed about.

**Verdict rule:** **window opens with "Block active" + locked controls + zero enforcement ⇒ FAIL**
(confirmed; the deceptive variant — invalidated tokens decoding empty — reaches the same state with
no user action, which is what makes it worth fixing).
**Something disarms, or the extension declines to latch the flag on an empty selection ⇒ PASS.**

Non-destructive; clears itself at the window end.

53. Confirm apps are selected and set a fresh 20-minute window per steps 28–31, then arm.
    *Inspect:* `is_armed == true`, `activities` contains `"daily"`.
54. **Before T_start**, tap the app card and **deselect every app**, then Done.
    *Expect:* the app card falls back to the "Choose apps & websites" empty state under the
    "Restricted" header. *Inspect:* the app card.
55. Debugger: *Expect* `is_armed` still `true`, `activities` still contains `"daily"`,
    `has_selection == true`, and `e -l swift -- Model.shared.isEmpty()` → `true`. *Inspect:* those
    four. Console should be silent — `applySchedule()` returned at its `!model.isEmpty()` guard, so
    nothing re-registered and nothing disarmed.
56. Background the app and keep using the device until T_start.
57. At T_start, Console: *Expect* `Interval did start for: daily` and **no**
    `Enforcement not allowed` line. *Inspect:* Console.
58. Open one of the previously restricted apps. *Expect (FAIL branch):* it opens normally — no shield
    anywhere on the phone. *Inspect:* the app opens; `times_stopped` does not increment.
59. Foreground Unplug and read the screen. *Expect (FAIL branch):* banner "Block active" with the
    pulsing dot, disabled "Blocking" CTA with a lock, greyed quick-restrict, inert slider, disabled
    mode picker, "Schedule locked while a block is active", and possibly the one-shot "App selection
    was reset, please re-select apps" toast. *Inspect:* every one of those, plus
    `inside_interval == true` in the debugger.
60. **Recovery-path check.** Tap the app card and re-select the two apps mid-window. Watch Console.
    *Expect (the second verifier's claim):* `Interval did end for: daily` then
    `Interval did start for: daily`, then the apps really are shielded. *Inspect:* Console lines, then
    open a restricted app and confirm the shield; then confirm the UI is still locked (it should be —
    the block is genuinely active now).
    **Shields appear ⇒ the recovery path is real** and V09's consequence is bounded to "until the user
    notices the empty app card", as the second opinion argued. **Shields do not appear ⇒ the first
    verifier was right** and the window is unrecoverable — note that, it raises severity.
61. Wait out T_end (Console `Interval did end for: daily`) and confirm the UI unlocks and
    `inside_interval == false`. *Inspect:* both. Then tap "Stop blocking" to disarm before the next
    group.

---

## Group 6 — Quick-restrict / daily collision (V07)

**Settles:** `V07` — the only confirmed **bypass** in the pass. `intervalDidEnd` matches on
`"daily" || "hourly"` with no per-activity ownership (`Extension:73-78`), so the quick block's end
wipes the shields of a concurrently-running daily block. Also settles the residual question of
whether `intervalDidEnd` is delivered at all for a **non-repeating** schedule.

**Verdict rule:**
- **`Interval did end for: hourly` fires inside the daily window and restricted apps then open ⇒ FAIL**
  (bypass confirmed, exactly as traced).
- **`Interval did end for: hourly` fires and the shields survive ⇒ PASS** for the collision — record
  verbatim what re-applied them, because nothing in the repo should.
- **`Interval did end for: hourly` never fires ⇒ UNSETTLED for the bypass**, and then follow the
  mirror: check whether `inside_interval` is left `true` after the daily window's own end. A stuck
  flag is the inverse defect (F4.3) and is the same missing guard.

> **Hazard: for 60 minutes you are in a block that cannot be stopped by design.** The hour block
> shields the two apps you picked, so make sure you don't need them. If you must get out early:
> `e -l swift -- DeviceActivityCenter().stopMonitoring()` then
> `e -l swift -- Model.shared.clearRestrictions()`, or delete the app. Note that `stop()` never stops
> `.hourly` (`ContentView.swift:84` passes only `[.daily, .notificationSchedule]`), so tapping "Stop
> blocking" will **not** end the quick block.
>
> This group occupies the device for ~80 minutes and nothing else in this script may run during it —
> every other test touches the same shield store and the same schedules.

62. Note **T0** = now, rounded up to the next 5-minute mark. Compute the daily window as
    **[T0 + 50 min, T0 + 70 min]**. The quick block is always exactly 60 minutes
    (`ContentView.swift:107-109`), so its end at T0+60 lands strictly inside that window — which is
    the precondition for the collision.
63. Set that window per steps 28–31 and tap **Start blocking**. *Expect:* no confirm alert.
    *Inspect:* `is_armed == true`, `activities` contains `"daily"`, `inside_interval == false`.
64. At T0, tap **"Restrict for next hour"**. *Expect:* the confirm alert ("blocks everything for the
    next hour and can't be stopped until then"). Confirm it.
    *Inspect:* the button was tappable at all — note that, it is V07's reachability premise
    (`isQuickRestrictDisabled` has no `isArmed` term, `ContentView.swift:31-33`).
65. Within seconds, Console: *Expect* `Interval did start for: hourly`. Open a restricted app.
    *Expect:* the shield. *Inspect:* Console line, the shield screen, `inside_interval == true`,
    and `activities` now contains **both** `"daily"` and `"hourly"` (confirming that registering
    `.hourly` did not displace `.daily`).
66. At T0+50, keep the device in use. Console: *Expect* `Interval did start for: daily`. Shields
    unchanged (same token set — idempotent). *Inspect:* Console; re-check a restricted app is still
    shielded.
67. From T0+58 onward, **keep using the device** (Apple only delivers interval callbacks while the
    device is in use). Watch Console around T0+60 for `Interval did end for: hourly`. Record its
    timestamp, or record that it never came.
68. At T0+62, open a restricted app. *Inspect:* does it open, or is it shielded? This is the verdict.
    Also read `inside_interval` and `activities`.
69. At T0+70 (the daily window's own end): Console — `Interval did end for: daily`? Read
    `inside_interval` again. *Expect (FAIL branch):* it was already `false` from T0+60.
    *Expect (never-fires branch):* watch whether it is left `true` with nothing to clear it.
70. Force-quit and cold-launch Unplug. *Expect (FAIL branch):* banner "Block inactive" with an
    **enabled "Stop blocking"** CTA and an unlocked slider, while the user believes a 22:00–07:00-style
    block is running. *Inspect:* banner, CTA, slider gestures. This is the second half of V07's harm —
    the user is not merely unprotected, they are told the block is inactive and offered a disarm.
71. Also record whether a plain cold launch **restored** the shields (the second opinion's correction:
    `onAppear` → `loadSelection()` → the selection `onChange` → `applySchedule()` re-registers
    `.daily` mid-window). *Inspect:* Console for an end/start pair right after launch, then whether a
    restricted app is shielded again. This is another read on the cross-cutting semantic above.
72. *Optional, adds ~60 min — the adjacent hole.* Tap "Restrict for next hour", then immediately tap
    "Stop blocking" and re-arm a daily window. 60 minutes later, when the orphaned `.hourly` interval
    ends, check whether its `intervalDidEnd` wipes the new block's shields. *Expect:* it does —
    `stop()` never stops `.hourly`. Record as a confirmation of V07's root cause (no per-activity
    ownership of the shield store), not as a separate finding.
73. Tear down: disarm, confirm `activities` is empty and no shields remain.

---

## Group 7 — Expired-trial cluster (V20 → V19 → V21)

**Settles:** `V20`, `V19`, `V21` — three findings off one trial expiry, in a fixed order because each
consumes the state the previous one needed.

The order is forced by the code: `enforcement_allowed` is written **only** by
`AccessController.recomputeAccessState()` (`:118`), which is reachable only from the app's foreground
paths. So V20 (the leak) requires the trial to lapse **while the app is never foregrounded**, and V19
(the drained-gate steady state) requires exactly one foreground visit. You cannot observe both on the
same window.

**Expiring the trial without touching the device clock.** `trial_start` is the only value the access
evaluator consults, so writing it into the past through the debugger is a faithful expiry — and unlike
a clock jump it does not perturb the registered `DeviceActivitySchedule`:

```
e -l swift -- UserDefaults(suiteName: "group.screentimeshield")!.set(Date(timeIntervalSinceNow: -8*86400), forKey: "trial_start")
e -l swift -- UserDefaults(suiteName: "group.screentimeshield")!.set(true, forKey: "enforcement_allowed")
```

Always read both back before killing the app. The clock-jump variant is noted at step 79 for one
optional confirmation.

74. Pre-conditions: **no full access.** QA menu → Force full access **off**; Xcode → Debug → StoreKit →
    Manage Transactions → delete any lifetime-unlock transaction. *Inspect:* QA "Full access" reads
    `no`, Access state reads `trial`, and the trial chip shows a day count.

### V20 — stale gate keeps enforcing after expiry

**Verdict rule:** **at the window start after expiry, `Interval did start for: daily` with no
`Enforcement not allowed` line and the apps really are shielded ⇒ FAIL** (revenue leak confirmed: an
expired trial enforces indefinitely as long as the app is never foregrounded).
**`Enforcement not allowed (access lapsed) — skipping restriction.` appears, or the apps are not
shielded ⇒ PASS**, and record what recomputed the gate — nothing in the repo should be able to.

75. Set window **W1 = [T+25 min, T+45 min]** per steps 28–31 and arm.
    *Inspect:* `enforcement_allowed == true`, `is_armed == true`, `activities` contains `"daily"`,
    `trial_start` is today.
76. Debugger: run the two write expressions above, then read both keys back.
    *Expect:* `trial_start` ≈ 8 days ago, `enforcement_allowed == true`. Write the values down.
77. Stop the app from Xcode (or force-quit from the app switcher). **Do not launch Unplug again until
    step 81.** Any foreground visit runs `refreshAccess()` and ends the test.
78. At W1's start, with the device in use: read Console, then open a restricted app.
    *Inspect:* the Console lines and whether the shield appears. Record the verdict per the rule above.
79. *Optional confirmation of the same finding by the faithful route:* repeat 75–78 but instead of the
    debugger write, force-quit the app and move the device clock forward 8 days
    (Settings → General → Date & Time, Set Automatically off). Caveats to record: a forward clock jump
    can itself disturb the DeviceActivity daemon, and the window is stored as hour/minute so it still
    fires at the same local time. Set the clock back afterwards.
80. Let W1 run to its end. Console: `Interval did end for: daily`. *Inspect:* the shields are gone and
    `inside_interval == false`.

### V19 — armed but unenforced, forever

**Verdict rule:** **after one foreground visit the app still presents as armed (enabled "Stop
blocking", `.daily` still registered) while `enforcement_allowed == false`, and the next window start
logs `Enforcement not allowed` and shields nothing ⇒ FAIL** (confirmed: nothing drains the schedule on
expiry, contradicting the extension's own "gate-and-drain" comment at `Extension:54-55`).
**Something disarms or unregisters `.daily` on expiry ⇒ PASS.**

81. Foreground Unplug **once**. *Expect:* `.task` → `refreshAccess()` → `recomputeAccessState()`.
    *Inspect:* trial chip reads "Trial ended · Unlock Unplug"; QA Access state reads `expired`.
82. Debugger: *Expect* `enforcement_allowed == false`, `is_armed == true`, `activities` **still
    contains `"daily"`**. *Inspect:* all three. Then read the screen: *Expect* banner "Block inactive"
    and an **enabled "Stop blocking"** CTA — the incoherent pair V19 is about.
83. To observe the next window start without waiting 24 hours, briefly un-expire so a new window can be
    registered (arming is blocked while expired: `start()` routes to the paywall and `applySchedule()`
    guards `!isExpired`). Debugger:
    `e -l swift -- UserDefaults(suiteName: "group.screentimeshield")!.set(Date(), forKey: "trial_start")`,
    then relaunch the app. *Inspect:* the chip reads a fresh day count and Access state reads `trial`.
84. Set window **W2 = [T+15 min, T+35 min]** and arm. *Inspect:* `is_armed == true`, `activities`
    contains `"daily"`, `enforcement_allowed == true`.
85. Re-expire and let the app drain the gate: debugger write `trial_start` = 8 days ago, then foreground
    the app once (or relaunch). *Inspect:* `enforcement_allowed == false`, `is_armed == true`,
    `activities` still contains `"daily"`, chip reads "Trial ended".
86. Background the app. At W2's start, with the device in use: Console *expect*
    `Interval did start for: daily` immediately followed by
    `Enforcement not allowed (access lapsed) — skipping restriction.` *Inspect:* Console, then open a
    restricted app (*expect* it opens normally), then `inside_interval` (*expect* still `false`).
    Record the V19 verdict.

### V21 — buying mid-window does not restore enforcement

**Verdict rule:** **the purchase completes, `enforcement_allowed` flips to `true`, and the apps remain
unshielded for the rest of W2 with no user action ⇒ FAIL** (a paying customer gets no blocking for the
window they just paid to fix).
**Shields appear on their own within a minute or so of the purchase ⇒ PASS** — record what delivered
them.

87. Still inside W2, foreground Unplug and tap the **trial chip** → paywall → buy the lifetime unlock
    (local StoreKit configuration; no real money). *Expect:* the purchase succeeds and the paywall
    dismisses. *Inspect:* QA menu Full access reads `yes`, Access state reads `fullAccess`,
    `enforcement_allowed == true`.
88. Immediately open a restricted app. *Expect (FAIL branch):* it opens normally — `setRestrictions()`
    has exactly one caller and nothing on the purchase path calls it. *Inspect:* the app opens;
    Console shows no new start line; the main screen shows banner "Block inactive" with CTA "Stop
    blocking". Wait 2–3 minutes with the device in use and re-check before recording the verdict.
89. **The workaround, and the cross-cutting semantic.** Tap **"Stop blocking"**, then **"Start
    blocking"**. *Expect:* the risky-arm confirm alert (now is inside the window, so `isRiskyToArm()`
    is true) → confirm → Console logs `Interval did start for: daily` → the apps are shielded within
    seconds. *Inspect:* the alert, the Console line, and the shield.
    **This is the highest-value observation in group 7:** it settles whether re-registering an
    in-progress interval re-delivers `intervalDidStart`, which V07's self-heal, V08's refutation,
    V09's recovery and V21's fix shape all depend on. Record it against all four.
90. Cleanup: wait out W2 or disarm. Xcode → Debug → StoreKit → Manage Transactions → **delete** the
    lifetime transaction (otherwise every later test runs with full access). QA menu → *Start trial
    now*. If you used step 79's clock jump, set Date & Time back to automatic.
    *Inspect:* QA Full access reads `no`, Access state reads `trial`.

---

## Group 8 — Screen Time revocation mid-block (V13)

**Settles:** `V13` (UNCERTAIN) — and it is designed to **distinguish the two OS branches the second
verifier identified**, not merely to observe an outcome. The two branches are not "worse lockout vs
milder lockout"; they are "bug vs no bug at all":

- **Branch A — revocation destroys the `.daily` registration.** `activities` comes back empty, so
  `onAppear` syncs `is_armed = false` while `inside_interval` is still `true`. From there **no code
  path in the app can register any activity** (`applySchedule()` hard-guards on `model.isArmed`;
  `performArm`/`performRestrictHour` sit behind the disabled CTAs), so `intervalDidEnd` can never be
  delivered and the flag is permanent. Unplug is a dead app showing a false "Blocking". **⇒ FAIL,
  confirmed as an unrecoverable brick.**
- **Branch B — the registration survives revocation.** `.daily` is still scheduled, so the window's
  own end delivers `intervalDidEnd`, the flag clears, and the app is fine. The only harm is the
  platform-level escape, which the finding explicitly excludes. **⇒ PASS, V13 refuted.**
- **Branch C — `activities` empty *and* `inside_interval` already `false`.** Record verbatim; V13 does
  not reproduce, for a different reason than branch B, and that difference matters to the fix.

The discriminator is **reading `activities` after re-granting authorization** (reading it while
unauthorized may return empty spuriously — treat that reading as unreliable), followed by watching
whether the flag ever clears.

> **Runs last, and can end in delete + reinstall.** Revocation also voids the
> `FamilyActivitySelection` tokens, so you will have to re-pick apps afterwards regardless of branch.
> Recovery, in order: debugger `set(false, forKey: "inside_interval")` + force-quit + relaunch → QA
> menu **Reset to fresh install** → delete and reinstall. In a production build only the last of those
> exists, which is the point of the finding.

91. Write down which recovery you will use, then confirm enforcement can work: QA Access state reads
    `trial` or `fullAccess`, apps selected (re-pick if group 7 left them empty).
92. Set window **W3 = [T+10 min, T+40 min]** (30 minutes, to leave room to work) and arm.
    *Inspect:* `is_armed == true`, `activities` contains `"daily"`.
93. At W3's start: Console `Interval did start for: daily`; open a restricted app and confirm the
    shield. *Inspect:* the shield, and `inside_interval == true`. Do not proceed until you have
    verified all three — the finding's precondition is a genuinely active block.
94. Settings → Screen Time → look for **"Apps with Screen Time Access"**. Record whether that pane
    exists on this iOS build and whether flipping it demands Face ID or the Screen Time passcode.
    (This also corrects `status.md`, `AccessController.swift:71-73` and `PermissionDeniedView.swift:6-8`,
    all of which assert "There is no per-app Screen Time toggle in iOS Settings".) If the pane does not
    exist, use **Turn Off Screen Time** instead — the second verifier argues that is the more plausible
    branch-A trigger anyway. **Record which route you used**; the branch may depend on it.
95. Turn Unplug's Screen Time access **off**. Immediately open a restricted app.
    *Expect:* it opens — the system lifts all `ManagedSettings` restrictions. This is the documented
    platform escape, **not** the bug. *Inspect:* the app opens; Console shows no extension activity.
96. Foreground Unplug while access is off. *Inspect:* whether `PermissionDeniedView` ("Screen Time
    access is off" / "Allow access") replaces the app card, i.e. whether `fcAuthorized` updated live —
    `status.md` records that it does **not** until the next cold launch and judged that acceptable.
    Record what you see; it bounds how misleading the state is.
97. Debugger, while still revoked: read `activities.map { $0.rawValue }` and `inside_interval`.
    Mark this reading **unreliable** in the results (the query may be answered as empty simply because
    the app is unauthorized) — it is context, not the discriminator.
98. Re-enable Screen Time access for Unplug and approve any prompt. *Inspect:* Settings shows access on.
99. Force-quit Unplug, enable **BP-D** (`ContentView.swift:246`) and **BP-A** (`:248`), and cold-launch
    from Xcode. At BP-D read `inside_interval` and `is_armed` **before** the resync line runs; step to
    BP-A, run `e -l swift -- DeviceActivityCenter().activities.map { $0.rawValue }`, then step over
    `:248` and read `is_armed` again. Write down all five values. **This is the branch discriminator.**
100. **If `activities` contains `"daily"` (branch B):** continue execution, let W3's scheduled end pass
     with the device in use, then read `inside_interval`.
     *Expect:* Console `Interval did end for: daily` and the flag clears to `false`.
     ⇒ **PASS, V13 refuted on this iOS build** — record the build number, and record whether
     enforcement resumed by itself.
101. **If `activities` is empty and `inside_interval == true` (branch A):** confirm the dead end before
     recovering. *Inspect, one at a time:* CTA is a disabled "Blocking" with a lock glyph; "Restrict
     for next hour" greyed; slider handles ignore drags; mode picker disabled; "Schedule locked while a
     block is active" caption present; banner "Block active" with the pulsing dot; re-selecting apps in
     the picker produces **no** Console output and no shields; toggling refocus notifications changes
     nothing; force-quit and relaunch preserves all of it; and no app on the phone is actually
     shielded. ⇒ **FAIL, V13 confirmed as an unrecoverable brick.**
102. **If `activities` is empty and `inside_interval == false` (branch C):** record all five values
     verbatim and note what could have cleared the flag — this is a new observation, not one of the
     verifiers' branches.
103. Also record the token fallout: does the "App selection was reset, please re-select apps" toast
     appear, and is the selection empty? *Inspect:* the toast and the app card. This is the
     no-user-action route into **V09**'s deceptive variant (armed, "Block active", nothing shielded),
     which the second opinion called the reason V09 is worth fixing.
104. Recover per step 91 and re-pick the apps. *Inspect:* `inside_interval == false`, CTA usable.

---

## Teardown

105. Revert `ScreenTimeShield/SettingsView.swift:26-29` to commented out; remove any temporary
     `QAMenuView` debug rows from step 4. *Inspect:* `git diff` is empty apart from this file.
106. Xcode → Debug → StoreKit → Manage Transactions → delete all transactions.
     QA menu (before you revert it) → *Force full access* **off** and *Reset trial*; or debugger
     `removeObject(forKey: "qa_force_full_access")` and `removeObject(forKey: "trial_start")`.
     Leaving `qa_force_full_access` set is exactly the V24 defect.
107. Settings → General → Date & Time → **Set Automatically** back on, if step 79 was run.
108. Delete or disable BP-A…BP-D. Re-enable refocus notifications if you want them.
109. Confirm the device is left clean: `activities` empty, `inside_interval == false`,
     `is_armed == false`, no shields, trial live.

---

## Results log

Copy this into the run and fill it in as you go. One row per verdict, in step order.

| Step | Finding | Invariant | Verdict | Observation (verbatim) |
|---|---|---|---|---|
| 15–17, 43 | V12 | — | PASS / FAIL | main-thread duration of the `activities` read: ___ ms |
| 22–24 | V25 | F9.1, F9.9 | PASS / FAIL | chip after reinstall: ___ ; `trial_start`: ___ |
| 25 | (new, if it fires) | F9.1 | — | app-group survival across an **update**: ___ |
| 34 | V14 leg 2 | F4.13 | measurement | extension launch latency: ___ ms |
| 35 | V11 leg 1 | F4.5, F4.3 | PASS / FAIL | banner / CTA / slider at the start boundary: ___ |
| 36 | V11 + V14 fork | F4.13 | FAIL (status) / FAIL (bypass) | `model.insideInterval` at tap time: ___ ; BP-C hit: ___ |
| 40 | V11 mirror | F4.5 | PASS / FAIL | UI at the end boundary: ___ |
| 44 | V08 | F4.8 | PASS / FAIL | end→start gap: ___ ms; shields restored: ___ |
| 48–51 | V14 leg 3 | F4.3 | PASS / FAIL / UNSETTLED | `is_armed`/`inside_interval`/`activities`: ___ |
| 57–60 | V09 | F4.4 (new) | PASS / FAIL | enforcement during the window: ___ ; recovery worked: ___ |
| 67–70 | V07 | F4.13 | PASS / FAIL / UNSETTLED | `Interval did end for: hourly` at ___ ; restricted app opened: ___ |
| 71 | V07 self-heal | F4.13 | — | cold launch re-applied shields: ___ |
| 78 | V20 | F9.2 | PASS / FAIL | Console lines + shield state after expiry: ___ |
| 82, 86 | V19 | F9.11 | PASS / FAIL | `activities` after expiry: ___ ; gate line logged: ___ |
| 88 | V21 | F9.6, F9.11 | PASS / FAIL | shields after purchase: ___ |
| 89 | cross-cutting | — | — | re-register mid-interval re-fires `intervalDidStart`: yes / no |
| 94 | `status.md` correction | — | — | per-app Screen Time toggle exists: yes / no; auth required: ___ |
| 99–102 | V13 | F4.3 | PASS (branch B/C) / FAIL (branch A) | `activities` after re-grant: ___ ; `inside_interval`: ___ |
| 103 | V09 deceptive variant | F4.4 | — | tokens voided / selection empty / toast: ___ |

**Device:** ___  **iOS build:** ___  **App build:** 13  **Time zone:** ___  **Date:** ___
**Restricted apps used:** ___

### After the run

- Write each verdict back into the finding's entry in `qa/findings.md`, with the device and iOS build.
  A PASS is a result: move the finding to a "refuted on device" note rather than deleting it, so the
  sweep's precision stays auditable (`qa/workflow-notes.md`).
- The three UNCERTAIN findings (V12, V13, V25) should end this session with a verdict or an explicit
  UNSETTLED and the reason.
- Record the four cross-cutting semantics — extension launch latency, `intervalDidEnd` for a
  non-repeating `.hourly`, re-registration mid-interval, app-group container lifetime — once, at the
  top of `qa/findings.md`. Several findings' severities are derived from them.
- Add the confirmed device findings to `status.md` under **Bugs**; none of them are recorded there
  today, and the redesign follow-ups' "real-device QA" line can be closed against this run.
