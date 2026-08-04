# Unplug QA pass — executive summary & fix plan

**26 July 2026.** A systematic bug hunt across three features: the schedule slider, arming and
disarming blocks, and the trial/paywall/lifetime-unlock flow. Chosen because the first two are the
UI redesign that has never had on-device QA, and the third is code no customer has ever run.

**19 confirmed problems, 3 unresolved, 1 investigated and dismissed.** Triaged with Steven's
decisions on 26 Jul; the fix pass began 26 Jul and is partly done — see Progress below.

| | |
|---|---|
| Breaks the "no bypass" promise | 2 |
| Traps or wrongly blocks a legitimate user | 7 |
| Costs money, or charges the wrong person | 5 |
| Confusing or broken UI | 5 |
| Proven by a test you can run today | 4 |
| Ever observed on a real phone | **0** |

## Progress (last updated 2026-08-02)

**9 of 17 fixes landed.** `swift test` is green at 58 tests, up from 25 tests with 20 failures when
the pass began. Everything below is on `main`.

| Done | Item | Commit |
|---|---|---|
| ✅ | One command runs every suite; ⌘U's blind spot documented | `483675d` |
| ✅ | `N4` shield extension app-group entitlement | `3797744` |
| ✅ | `V22` IAP cutover date | `da16e73`, `7351ceb` |
| ✅ | `V05` wrap-aware free-time arithmetic | `7375d72` |
| ✅ | `N1` trial countdown clamp | `6c403db` |
| ✅ | `N2` accepted V23 risk as strict expected failures | `75690b2` |
| ✅ | Registration failures surfaced (F4.6, and `V06`'s real half) | `c594525` |
| ✅ | Minutes-of-day types in `UnplugCore` | `0f67fed` |
| ✅ | `V02` + `V01` schedule storage and migration (also closed `R1`) | `e508014` |
| ✅ | `V04` single-gesture slider | `18bf3a9` |

**Still to do, in order.** `V11` is first despite its severity because three other findings lean on it:

| # | Item | Note |
|---|---|---|
| 1 | `V11` + `V14` — derive block-active from the clock | Also quiets `V13` and unblocks `V07`'s guard |
| 2 | `V07` — don't tear down a block that should still run | Needs the device answer on `intervalDidEnd` |
| 3 | `V12` — move the activities read off the main thread | Two defensive lines |
| 4 | `V18` + Keychain — persist the entitlement verdict | Blocks `V20`; see `V25` for what goes in the Keychain |
| 5 | `V15` + `V16` — complete the purchase flow | Register `StoreKitEdgeTests.swift` in the project here |
| 6 | `V21` — re-apply enforcement the moment access returns | |
| 7 | `V20` — judge trial expiry inside the monitor extension | Depends on 4 |
| 8 | `V19` — honest "trial ended" state | New strings ×10 languages |

**Won't fix, by decision:** `V06` (tiny block), `V09`, `V17`, `V23`, `V24`.
**Needs a phone, not code:** `V13`, `V25`, `N3`, plus verification of everything above marked device.

### Two things to know before touching any of it

- **`V11` is load-bearing beyond itself.** `V07`'s existing guard, `V13`'s stuck-flag symptom and
  `V14` all depend on the app knowing whether a block is active. Fix that once and three findings get
  quieter.
- **The fixed items still need the device matrix.** Nothing above has been observed on a real phone;
  a passing test suite is not the same as working enforcement.

---

## 1. The schedule slider

### 🔴 The right-hand end of the slider doesn't mean midnight · `V01`
**✅ Fixed — `e508014`.** Minutes-of-day storage removed the `Date` round trip, so there is no failing conversion left to fall back from.
*Fires on the gesture the UI advertises · no test yet*

The slider prints "24:00" as its last tick. Dragging the end handle there asks iOS for hour 24,
which doesn't exist — the call fails, and the code falls back to **the current time**. Your end time
silently becomes "now", the window is now backwards, and iOS reads a backwards window as wrapping
midnight. Result: a block of up to ~24 hours that you never configured and can't stop, arriving with
no confirmation prompt. Confirmed by actually running the failing call in four timezones.

> **Decision: fix.**

**Plan.** Two parts, because the fallback and the missing guard are separate faults.

1. Make the minute→time mapping total, so it can never substitute an unrelated time.
   `dateAtMinute` in `ScheduleRangeSlider.swift:39-42` currently clamps to 1440 and then falls
   through `?? Date()`. Clamp the *value* to 1439 and drop the fallback (make the function
   non-failing). Minute 1440 keeps its meaning at the schedule layer, where `Schedule.components`
   should emit `hour: 0, minute: 0` for an end-of-day boundary — that is what
   `DeviceActivitySchedule` wants for "until midnight", so the "24:00" affordance stays honest.
2. Add an ordering guard before arming, in `applySchedule()`. Refuse to register a window whose
   start equals its end, and require an inverted window to be *intentionally* inverted (allow-only
   mode) rather than an artefact.

**Extraction needed to make it testable.** The mapping is `private` to the view, so nothing can test
it today. Move `minute(forX:)` / `x(for:)` / `dateAtMinute` into a small pure `TrackMapping` type in
`UnplugCore` and have the view call it. Without this, the fix is unregressable — and note the
critic's warning that changing the clamp ceiling could silently alter behaviour elsewhere.

### 🔴 The safety check can't understand overnight blocks · `V05`
**✅ Fixed — `7375d72`.** Wrap-aware, verified against a brute-force oracle across all 2,073,600 windows.
*Common — it is the app's main use case · **proven by test***

Before arming, the app checks "would this leave almost no free time?" by subtracting start from end.
For a 10pm–7am window that subtraction goes negative, gets clamped to zero, and the app concludes
the **whole day is free** — so it never warns you. Measured against a brute-force reference, the
answer is wrong for **1,036,080 of 2,073,600** possible windows: precisely every one that crosses
midnight. It also makes the slider draw the wrong picture for anyone with an existing overnight
window.

> **Decision: fix.**

**Plan.** `ScheduleMath.freeMinutes` (`ScheduleMath.swift:29-32`) needs to be wrap-aware. Compute the
blocked length modulo the day — `(end - start + 1440) % 1440` — and derive free time from that,
rather than `max(0, end - start)`. Add a companion `blockedMinutes(...)` so callers can ask the
question directly instead of inferring it.

Then check the call site at `ContentView.swift:129-131`, which passes the **uninverted** window while
the risk check's other half uses the **inverted** interval. Both halves should be reasoning about the
same interval.

`ScheduleMathBoundaryTests` already checks any fix against all 2,073,600 windows in both modes, so
this one is verifiable the moment you touch it. Expect the tests currently red at lines 156, 171,
173, 182 and 184 to go green.

### 🔴 Your window drifts by an hour twice a year · `V02`
**✅ Fixed — `e508014`.** Stored as minutes since midnight; armed users migrated exactly from the interval the system already holds.
*Common across the user base · partly proven*

Times are saved as absolute moments but read back as clock times in whatever timezone the phone is
in now. When the clocks change, the slider shows times you never picked — and the next edit
re-registers the block at those drifted times. Affects every armed user in a DST-observing region,
which is most of the ten shipped locales, plus anyone who travels.

> **Decision: fix properly** — no interim papering-over.

**The real fix is a storage-format change.** `start`/`end` are `Date` instants (`Model.swift:41-53`)
but every consumer only ever wants hour and minute. Store **minutes-of-day integers** instead, and the
class of bug disappears rather than being mitigated.

Touch points:

- `Model.start` / `Model.end` become `Int` minutes-of-day, persisted as integers.
- `ScheduleRangeSlider` binds to the same integers — which removes its `dateAtMinute` /
  `minutes(of:)` round trip entirely, and with it the `V01` fallback bug. **These two fixes want to be
  done together**; doing `V02` first makes `V01` mostly disappear.
- `Schedule.components(from:)` takes minutes and builds `DateComponents(hour:minute:)` directly, with
  no `Calendar` involved.
- `AccessController.updateTrialEndedNotification` reads the same integer.
- `ScheduleMath` already speaks minutes-of-day, so the call sites get simpler, not harder.

> **You asked: don't we re-arm the block every day?**
>
> **No — and that detail is what makes the bug's shape clear.**

`setSchedule` has exactly two callers: `applySchedule()` (`ContentView.swift:63`, on arming and on a
selection edit) and `performRestrictHour()` (`:109`). The daily schedule is registered **once**, with
`repeats: true`, and iOS repeats it from then on. The extension never registers anything.

The consequence is worth internalising: because the registration carries bare hour/minute components,
**iOS's own enforcement is already DST-correct** — it fires at 22:00 local every day, forever. The
drift exists only in the app's stored `Date`. So nothing breaks at the DST boundary itself; what breaks
is the *next* re-registration, when the app overwrites a correct schedule with drifted values. The
symptom order is: display goes wrong first, enforcement follows later when you next edit anything.

**Which also gives us a much better migration than I first thought.** `DeviceActivityCenter` exposes
`schedule(for:) -> DeviceActivitySchedule?` — confirmed present in the iOS 26.2 SDK — and the schedule
it returns holds the `intervalStart`/`intervalEnd` components **as originally registered**, undrifted.
So for armed users we can recover the true intended hour and minute from the system rather than
guessing at the stored `Date`:

1. If a `.daily` schedule is registered, migrate from its components. Exact, no ambiguity.
2. Otherwise fall back to reading the stored `Date` with the current calendar — possibly an hour off,
   but nothing is being enforced for these users, so the stakes are low and they'll see the value on
   the slider before they arm.

That removes the unrecoverable-hour problem for precisely the users it mattered for, and the earlier
open question about whether to warn them goes away with it.

One piece is already covered: the composed case where drift inverts the window is proven red in
`ScheduleMathBoundaryTests:256`, and the `V05` fix resolves that half.

### 🔴 Short windows hide the start handle · `V04`
**✅ Fixed — `18bf3a9`.** One gesture owns the track and picks the handle by proximity, falling back to drag direction when the thumbs overlap.
The two handles overlap, so the start one can't be grabbed.

> **Decision: fix** — approved.

**Plan.** The problem is architectural, not cosmetic: each handle owns its own `DragGesture`
(`ScheduleRangeSlider.swift:129`), so when they overlap, whichever is drawn on top wins every touch
and the one underneath is unreachable.

Replace the two per-handle gestures with **one gesture on the track** that decides which handle it is
moving when the drag begins, and keeps moving that same handle for the rest of the drag:

- On the first change event, pick the handle whose value is nearer the touched minute.
- If they're within a few minutes of each other, tie-break on drag direction — leftward moves the
  start handle, rightward moves the end handle. That makes the buried handle reachable by dragging
  *away* from the other one, which is the intuitive gesture anyway.
- Hold the chosen handle in `@GestureState` so a drag can't switch handles halfway through.

This also fixes a second problem nobody has complained about yet: today the handle jumps to your
finger on touch-down rather than moving relative to it, because the mapping is absolute (raised as an
unverified nit, `F3-MAP-03`). Tracking a drag offset from the initial touch fixes both at once.

Not urgent, but it's a contained change to one view and worth doing whenever that file is next open.

### 🟡 Allow-only mode can build a block iOS rejects · `V06`
**✅ Addressed — `c594525`.** The tiny block stays accepted as won't-fix; its *silent* failure does not — registration errors now surface.
*proven by test*

Allowing nearly the whole day leaves a blocked interval shorter than the minimum iOS will monitor.
Registration fails, the error is swallowed, and nothing blocks — silently.

> **Decision: won't fix.** — "if they only want to block 5 minutes and it doesn't work who cares".
> Agreed on the 5-minute block itself.

**But separate the two halves.** The part that doesn't matter is the tiny block. The part that does
is that **`startMonitoring` failures are invisible** — the same swallowed `catch { print }` at
`Schedule.swift:36-39` and `:56-58` hides *every* registration failure, not just this one. That is
already an open item in `status.md` ("Schedule still swallows startMonitoring errors"), and it is the
thing to fix. Surfacing that error would turn this finding from a silent no-op into a visible "that
window is too short", at which point it stops mattering on its own.

Test housekeeping: see `N2`.

---

## 2. Starting and stopping blocks

### 🔴 "Restrict for next hour" can kill your nightly block · `V07`
*Occasional by accident, deterministic on purpose · needs phone*

There are two kinds of block — the repeating daily one and the one-off hour — and a single cleanup
function handles the end of both. It checks which one ended, then **clears all the shields either
way**. So when a quick hour block finishes while your nightly block is running, your apps open. The
schedule stays registered and the app still believes it's blocking.

This is a genuine bypass of the thing the app promises, and three separate agents found it
independently through different routes.

> **Decision: fix.**

**Plan.** `intervalDidEnd` in `DeviceActivityMonitorExtension.swift:68-79` must stop treating
teardown as unconditional. Instead of clearing shields whenever *an* interval ends, it should ask
whether *any* block should still be in force, and only clear if not:

- Re-evaluate the daily window against the clock using `ScheduleMath.windowContains` — `UnplugCore`
  is already available to the extensions, so this needs no new plumbing.
- If the daily window still contains now, **re-apply** the restrictions rather than clearing them,
  and leave `inside_interval` true.
- Only clear when nothing is currently in force.

> **You said: "that should be the behaviour already."**
>
> **It partly is — and finding out why it doesn't hold is the more useful answer.**

The guard exists. `isQuickRestrictDisabled` (`ContentView.swift:31-33`) includes
`model.insideInterval`, so the button *is* greyed out during an active block. Your memory of the intent
is correct. It fails in two specific ways:

1. **It only covers "a block is active right now", not "the hour I'm booking will overlap the window
   that starts soon".** Tap it at 21:30 with a 22:00 block armed, and nothing objects: the hour block
   is registered, the nightly block starts at 22:00, and at 22:30 the hour block's end tears down both.
   This matches the verifier's frequency note exactly — *"needs quick-restrict tapped inside the 60 min
   before the armed window starts"*.
2. **The guard reads the flag `V11` says the app never sees updated.** So even the case it does cover is
   unreliable: if the block started while the app was foregrounded, `model.insideInterval` is still
   `false` and the button stays live.

**Plan, then, is to make the existing intent actually hold** rather than invent new behaviour:

- Extend `isQuickRestrictDisabled` to also disable when `now + 1 hour` would intersect the armed
  window, computed from `blockedInterval` with `ScheduleMath` — no new state, just a better predicate.
- Fix (2) by way of the `V11` change, so the flag it relies on is no longer the weak link.
- Keep the conditional teardown in the extension regardless, as the safety net for any overlap that
  still gets created (a schedule edit, a race at the boundary).

**Device answer needed first** (matrix step for `V07`): whether re-applying inside `intervalDidEnd`
actually sticks, or whether iOS treats that callback as terminal for the store.

### 🔴 The app doesn't notice when a block starts · `V11`, `V14`
*Common · needs phone*

The main app and the background extension are separate processes, and the app reads the
"block active" flag using a mechanism that doesn't watch for writes from another process. If you're
looking at the app when your block begins, the banner still says "Block inactive", the schedule
stays editable when it should lock, and Stop stays tappable. Most visible in the obvious first-run
habit: set the window to start in a minute, watch, conclude it's broken.

> **Decision: fix.**

**Plan.** Stop treating `inside_interval` as the source of truth in the app. The clock and the
schedule are authoritative and always available locally:

- Derive "is a block active right now" in the app from `blockedInterval` + the current time via
  `ScheduleMath.windowContains`, with `inside_interval` used only as a corroborating hint.
- Drive it off a timer while the app is foregrounded (a low-frequency one is fine — the granularity
  that matters is one minute), plus the existing `scenePhase` refresh.
- Keep `inside_interval` as the extension's record for its own use; just stop the UI depending on
  observing a cross-process write that never arrives.

This one fix covers both findings: `V14`'s inert Stop button is the same divergence seen from the
other side. It also removes the app's dependence on the exact `@AppStorage` cross-process semantics,
which is the part nobody could confirm from documentation.

### 🔴 Deselecting every app while armed · `V09`
*needs phone*

The schedule stays registered, so the block still starts on time and locks the interface — while
shielding nothing.

> **Your note:** *"Apps cannot be de-selected when armed, there should already be a unit test
> enforcing this."*
>
> **Both halves of that are wrong, and it's worth knowing why.**

**The guard is narrower than you remember.** `ContentView.swift:221` reads
`if model.insideInterval && !model.validateRestriction()`. It is gated on `insideInterval` — a block
actually *running* — not on `isArmed`. So in the armed-but-not-yet-active state (which is most of the
day for a nightly block), removal is fully permitted and `validateRestriction()` is never even
called.

**And there is no test.** `grep -rn validateRestriction --include=*.swift` finds zero references in
any test target. `ScreenTimeShieldTests` contains only `StoreTests` and a placeholder. The invariant
is enforced by one `if` statement in a view and nothing else.

> **Decision: won't fix.** — "drop 09, who cares."

Accepted. Recording the consequence so it isn't a surprise later: during armed-but-inactive, a user
can empty their selection, and the block will still activate on schedule — locking the UI while
shielding nothing. It resolves itself when the window ends, and a user who just deselected everything
probably doesn't want a block anyway. The `V11` fix makes the UI honest about it (a block genuinely
*is* active; it just has nothing to shield). No test, and the removal-while-active guard stays
enforced by a single `if` statement in a view.

<details><summary>The plan, if this is ever revisited</summary>

Lift `validateRestriction`'s set arithmetic out of `Model` into `UnplugCore` so it is reachable from a
test, widen the guard from `insideInterval` to the armed state, then pin the truth table: removal
while idle / armed / active, addition in every state, and emptying the selection.

</details>


### ❓ Turning Screen Time off mid-block may brick the app · `V13`
*unresolved — depends on undocumented iOS behaviour*

The "block active" flag may never clear, leaving the app permanently showing "Blocking" with a
disabled button and no way out.

> **Your note:** *"Uninstalling the app has iOS remove the block."* — Agreed, and that lowers the
> severity: it is not a permanent brick, it is an escape that costs the user all their settings.

**Two consequences worth recording, though.**

First, the `V11`/`V14` fix above largely dissolves this: once the app derives active-state from the
clock rather than the flag, a stuck flag can no longer strand the UI. That is a good argument for
doing `V11` before worrying about this one.

Second — and this is the uncomfortable part — if deleting the app reliably removes the block, then
**uninstall is a universal bypass of the no-bypass promise**. That is presumably a deliberate,
unavoidable limitation of the Screen Time APIs rather than a bug, but it is not written down
anywhere, and it interacts with `V25` below. Worth an explicit line in the README about what the
guarantee actually is.

Still in the device matrix, now for the narrower question of whether the flag clears.

### 🟡 A blocking system call on the launch path · `V12`
*unresolved*

> **You asked me to expand on this.**

**What the code does.** `ContentView.swift:248` is
`model.isArmed = DeviceActivityCenter().activities.contains(.daily)`, sitting inline in `.onAppear`
with no `Task` and no queue hop — so it runs on the main thread during launch, for every user. It is
not gated on authorization, trial state, or the QA env hooks.

**Why it was flagged.** This is the one surviving main-thread `DeviceActivityCenter` call. Your own
comment at `Schedule.swift:18-21` says these are "synchronous XPC calls to the system daemon and are
slow enough to stall the UI", and `status.md` records the arm-confirm freeze as a real bug of exactly
this class that you already fixed by moving four calls onto a serial queue. `git log -L 248,248`
shows this line was added by the explicit arm/disarm commit and was never touched by that off-main
refactor — so it is a genuine miss rather than a deliberate exemption.

**Why it is only "unresolved", not confirmed.** The verifier could not establish that the `activities`
*getter* is expensive. Apple's documentation says nothing about its cost or threading. The evidence
for `startMonitoring` being slow is solid; transferring that to a property read is inference. The only
direct report is a single unanswered forum thread from an iOS 18 beta describing a deadlock on
`activities`, explicitly not reproducible on 17.6 and now two years stale. Against the claim: this
line has shipped since mid-June and nobody has reported a slow launch, whereas the arm-confirm stall
was noticed immediately.

**Plan.** Not worth investigation — worth two lines of defensive coding. Route the read through the
same serial queue `Schedule` already owns and assign back on the main actor. Cost is trivial, it
removes the last main-thread XPC call, and it makes the question moot rather than answered. The only
subtlety is that `isArmed` then settles a moment after launch, so the UI must tolerate one frame of
the persisted value — which it already does, since `isArmed` is `@AppStorage`-backed.

### ✅ Dismissed: editing your selection mid-block · `V08`
Predicted to strand the app in a stuck state. Checked, and it doesn't. Recorded because it was the
prediction that felt most certain from reading the code alone.

---

## 3. Trial, paywall and purchase

### 🔴 A paying customer can be told they haven't paid · `V18`, `V17`
*Occasional · proof path exists, not yet run*

Whether someone is grandfathered isn't stored — it's recalculated from scratch on every launch,
starting from "no". If that check fails for any reason (offline, slow response) the "no" stands, the
app decides their trial expired, and enforcement switches off. They then tap **Restore Purchase**,
that call fails too, and the app tells them *"No previous purchase found."*

> **Your note:** *"On payment we should set state in local storage… There should not be an offline or
> slow response path possible for grandfathering or after payment. Check this is the case."*
>
> **Checked: it is not the case. Your described design is the fix, not the current behaviour.**

**What the code actually does.** `AccessController.refreshAccess()` runs on *every* foreground
(`ScreenTimeShieldApp.swift:101-102`) and calls both `refreshPurchasedState()` and
`refreshGrandfatheredState()`. Those hit `Transaction.currentEntitlements` and `AppTransaction.shared`
every single time. Neither result is ever persisted: `isPurchased` and `isGrandfathered` are
`@Published` properties on a fresh `Store` instance, defaulting to `false` on each launch
(`Store.swift:16-17`). The only thing written to durable storage is the derived
`enforcement_allowed` bool for the extensions — and it is written *after* a possibly-failed refresh,
so a failure actively propagates into it.

So there is a live offline path, and it is on the launch route rather than an edge case.

> **Decision: fix**, implementing the design you described.

**Plan.**

1. Persist the entitlement verdict in the app group — a `full_access` flag plus the date it was
   established. `AppGroupKeys` has no key for this today; add one.
2. **Never downgrade on failure.** `refreshGrandfatheredState` already leaves its value untouched on
   a thrown error (`Store.swift:78-80`) but that is useless while the value starts at `false` each
   launch. Once persisted, "unknown" must resolve to the last known verdict, never to "no access".
   Note that `refreshPurchasedState` (`Store.swift:59-66`) is worse — it assigns `false`
   unconditionally after an empty entitlements loop, with no error path at all. That is a separate
   lead the critics raised (`R5` in `workflow-notes.md`) and it needs the same treatment.
3. Call Apple only when it matters: at purchase, at explicit Restore, and opportunistically on
   foreground to *upgrade* the cached verdict. A grandfathered or paid user should never need the
   network to keep working.

`V17` ("No previous purchase found" on a failed restore) is marked *won't fix — typical* below, and
this plan largely removes its trigger anyway, since a paid user will no longer be pushed toward
Restore by a spurious downgrade.

### 🔴 The grandfathering date has already passed · `V22`
**✅ Fixed — `da16e73`, date set in `7351ceb`.** ⚠️ Currently overridden to 2020-01-01 for the dev build — see the revert checklist in `status.md`.
*⏱ Deadline-bound · **proven by test***

The code compares download date against a fixed cutover of **25 June 2026** — now a month in the
past, with 1.3 still unshipped. Everyone who paid $0.99 since then will be asked to pay again the day
1.3 goes live.

> **Your note:** *"We need to move the grandfather date up, there should be a todo already for it."*
> — Correct, there is: `status.md:45`, *"Cutover date set … **Adjust if the release date slips.**"*
> The slip happened; the adjustment didn't.

> **Decision: fix.**

**Plan.** Move `PricingConfig.cutoverDate` (`AccessControl.swift:27`) to the actual 1.3 release date.
Since that date isn't known yet, set it deliberately *ahead* of the expected submission — being
generous costs you a handful of $0.99 customers getting free access, while being late charges paying
customers twice. `PricingBoundaryTests` encodes this as an invariant and will tell you when the value
is defensible.

Then make it not happen again: the existing `status.md` item didn't survive a schedule slip because
nothing checked it. The test now does, but only if it actually runs — see `N2` and the scheme wiring
note at the bottom.

### 🔴 Buying the unlock mid-block does nothing until tomorrow · `V21`
*Common among people who convert after the trial · needs phone*

Trial expires, that evening nothing is blocked, the user buys the unlock, and enforcement doesn't
return until the next window.

> **Decision: fix.** — "Once they buy, we should immediately re-enable the blocks."

**Plan.** After a verified purchase, `AccessController.purchase()` already recomputes access state.
Extend it: once state becomes `.fullAccess`, if the app is armed and the current time falls inside
`blockedInterval`, apply the restrictions immediately (`Model.setRestrictions()`) and set
`inside_interval` — don't wait for the next `intervalDidStart`. Do the same on a successful
`restore()`, and on the `V18` path where a cached verdict is restored after a failed refresh.

Pair it with the `V19` fix below, since both are about the app's state not tracking entitlement
changes at the moment they happen.

### 🔴 If you never reopen the app, the trial never ends · `V20`
*needs phone*

The enforcement flag only recalculates when the app comes to the foreground. Close the app and never
open it again, and blocks keep working, free, indefinitely.

> **Decision: fix.** — "We should be checking trial state in the block callbacks!" — right, and the
> reason it isn't already is worth knowing.

**Plan.** The extension *does* check a gate — `enforcement_allowed` at
`DeviceActivityMonitorExtension.swift:56-59` — but it only reads a value the app computed earlier, so
it's exactly as stale as the app's last foreground. The extension can't ask StoreKit anything.

But it doesn't need to. Trial expiry is pure date arithmetic, and `AccessEvaluator` already lives in
`UnplugCore`, which the extensions can import (`ShieldConfigurationExtension` already does). So:

- Have `intervalDidStart` evaluate expiry itself — read `trial_start` from the app group, apply
  `AccessEvaluator.accessState` against the current time, and combine with the **persisted**
  entitlement flag from the `V18` fix.
- That makes the gate self-sufficient: no foreground visit required, and no StoreKit in the extension.
- Keep the fail-safe direction intact — a *missing* entitlement flag must still mean "allow", so a
  paying user is never locked out by an absent key (`DeviceActivityMonitorExtension.swift:41-44`).

This depends on `V18` landing first, since it needs a persisted verdict to read.

### 🔴 Expiry never stops the schedule · `V19`
*needs phone*

Nothing deregisters the daily schedule when the trial ends, so the app looks armed while the
extension quietly refuses to enforce anything.

> **Decision: fix, keeping the blocks.** — "once the trial stops we should retain the blocks but show
> clearly they are inactive." That's the better product answer than tearing the schedule down.

**Plan.** Leave the registration in place and make the state legible:

- Add an explicit "inactive — trial ended" state to `StatusBanner`, distinct from both "Block active"
  and "Block inactive". Right now an expired user sees a normal-looking armed app.
- The primary CTA should route to the paywall in that state rather than reading "Stop blocking".
- Keep the schedule registered so that the moment they buy, the `V21` fix can light it up again
  without them reconfiguring anything.

That turns today's silent failure into the app's clearest upgrade prompt, which is also the honest
version of what's happening.

### 🔴 Rolling the clock back restores an expired trial · `V23`
***proven by test***

> **Decision: won't fix.** — "no one will bother doing that." Fine — it needs deliberate effort and
> the payoff is one $4.99 unlock.

**One thing to separate out, though.** The same tests surfaced a defect that has nothing to do with
clock tampering: **`trialDaysRemaining` returned 18 days for a 7-day trial.** That's a display bug an
honest user can hit, and it's tracked separately as `N1` below.

Test housekeeping: see `N2`.

### 🔴 Purchases made outside the buy button are never seen · `V15`
*Rare*

> **Your note:** *"I don't understand this, there is exactly one purchasing flow."*
>
> **You're right that there's one flow — but it can suspend and resume, and the resumption arrives
> somewhere the app isn't listening.**

**The concrete cases.** `product.purchase()` can return `.pending`, meaning the purchase is real but
not yet complete. The main causes are **Ask to Buy** (a child account needing a parent's approval,
which may come hours later) and account verification the customer has to go and do. There's also the
same-Apple-ID second device, and an interrupted purchase that resolves after your call returned.

In all of those the transaction is delivered later, via `Transaction.updates` — and Apple's guidance
is explicit that without a listener on it, *"your app may miss them"*, and that unfinished
transactions are re-delivered at every launch until finished. Your app has no such listener.

So the failure is: parent approves, StoreKit considers it bought, and Unplug never notices — the user
has paid and is still looking at the paywall.

> **Decision: fix.** — "sounds like we need to complete the payment flow then". Yes — and treating
> `V15`, `V16` and the `V18` persistence as **one piece of work** is the right framing. They are three
> symptoms of the purchase flow having no path for anything except immediate success.

**Plan.** Add a long-lived `Task` in `Store` that iterates `Transaction.updates`, verifies each
transaction, unlocks access, persists the verdict (`V18`), applies restrictions if a window is
currently live (`V21`), then calls `finish()`. Start it at `init` and hold it for the app's lifetime.
Finish only *after* unlocking, per Apple's guidance.

Also iterate `Transaction.unfinished` once at launch, so a transaction that arrived while the app was
dead is settled rather than waiting for the next update.

**What "complete" means, concretely** — every path from tapping Buy now terminates somewhere defined:
immediate success, deferred success via the listener, pending-awaiting-approval, verification failure,
cancellation, and thrown error. That's the table in `V16`.

### 🔴 A pending purchase looks like a silent failure · `V16`
A purchase awaiting approval is reported identically to an outright failure — the user taps buy and
sees nothing at all.

> **You asked: what's the standard pattern?**

**The pattern is to stop collapsing distinct outcomes into `Bool`.** `Store.purchase()`
(`Store.swift:33-49`) currently returns `false` for `.pending`, `false` for `.userCancelled`, and
`false` for an unverified transaction — three completely different situations the UI cannot tell
apart, so it shows nothing for all three.

Return an explicit outcome instead, and handle each:

| Result | What the user should see |
|---|---|
| `.success` verified | Unlock, dismiss the paywall (as today) |
| `.success` **unverified** | An error — this is a failed verification, not a purchase |
| `.pending` | *"Your purchase needs approval and will unlock automatically once it's approved."* Then leave the paywall dismissible |
| `.userCancelled` | Nothing at all — they chose to stop |
| thrown error | The existing "Purchase failed, please try again" |

The `.pending` message is only truthful if the `V15` listener exists to deliver the approval later,
which is why these are one change. Map the outcome to a message with a pure function in `UnplugCore`
so the mapping is testable — the current `errorMessage` lives in `@State` inside `PaywallView` and is
unreachable from a test.

### 🟡 Restore blames the customer for a network failure · `V17`
> **Decision: won't fix.** — "typical". Agreed, and the `V18` fix removes most of its blast radius by
> not sending paid users to Restore in the first place. If you ever want the polish, it's
> distinguishing a thrown `AppStore.sync()` error from a genuine empty-entitlements result.

### 🟡 A debug flag that can't be switched off · `V24`
> **Decision: won't fix.** — "not exposed, not an issue." Correct on today's code: the only entry
> point is the QA section commented out at `SettingsView.swift:25-29`. Noted only so that whoever
> re-enables that menu knows the flag is one-way.

### ❓ Reinstalling may reset the trial · `V25`
> **Your note:** *"I don't think it does but we should search the docs to confirm."*
>
> **Searched. Apple has never documented it, and the field reports point the other way from your
> expectation.**

App-group container behaviour on deletion isn't specified anywhere in Apple's documentation. What
developer reports say is that app-group `UserDefaults` **is** cleared on delete-and-reinstall, and —
more alarmingly — there is at least one report of an app-group container being recreated during an
ordinary **app update**, wiping its contents.

That reframes this finding. The free-trial-reset angle you're dismissing is the *minor* half. The
major half is that everything Unplug persists lives in that container: `trial_start`, the app
selection, the schedule, `is_armed`, `enforcement_allowed`. If a container can be recreated on
update, an ordinary paying user could lose their entire configuration — and given `V18`, also their
grandfathered status. Tracked as `N3`.

> **You asked: how do we defend against this without reaching for iCloud, given we don't need to put
> everything in the durable store?**

**Decision: verify on device** (both directions — reinstall and update-in-place) **and move two
small values to the Keychain.** Right instinct: Keychain is the only non-iCloud store that outlives
the app container, and the whole point is to be selective about what goes in it.

**What goes in the Keychain — two items, both tiny:**

| Value | Why it must survive |
|---|---|
| `trial_start` | The only thing that makes a trial a trial. Losing it restarts the clock; today it lives only in the wiped container |
| `full_access` verdict + the date it was established | From the `V18` fix. This is what stops a paying user being downgraded when the network is unavailable — useless if an update can erase it |

**What stays in the app group:** the app selection, the schedule window, mode, `is_armed`,
`inside_interval`, `times_stopped`. These are larger, change often, and are recoverable by the user
re-picking them. Keychain is for small values, not a general key-value store, and putting an encoded
`FamilyActivitySelection` in it would be an abuse of it.

**Implementation notes that matter here:**

- The **DeviceActivityMonitor extension must be able to read these**, so they need a shared
  `keychain-access-groups` entitlement across the app and the extension targets — the same
  arrangement the app group already has, but declared separately.
- Use `kSecAttrAccessibleAfterFirstUnlock`, **not** `WhenUnlocked`. The extension runs in the
  background at the block boundary, potentially while the phone is locked, and `WhenUnlocked` would
  make the read fail exactly when enforcement needs it.
- Keychain survival across deletion is itself undocumented, so treat it as best-effort: read Keychain
  first, fall back to the app group, and if neither has a value treat it as a genuine fresh install.
  Never fail toward "no access".

**One thing that reduces the problem before any of this.** `AppTransaction.originalPurchaseDate` —
already used for grandfathering — is reinstall-proof, because it comes from the Apple ID's purchase
record rather than local storage. It can serve as a ceiling on trial validity: however the local
`trial_start` got there, a trial cannot outlive `originalPurchaseDate + trialLength + grace`. That
makes the reinstall-reset abuse impossible without relying on Keychain persistence at all, and it
costs one comparison. Worth doing alongside, since we're already fetching that value.

Note this also quietly closes the abuse half of `V23`, which you'd decided not to care about — a
free side effect rather than a reason to do it.

---

## New items created by this triage

### 🔴 `N1` — The trial countdown can show more days than the trial has
**✅ Fixed — `6c403db`.** Remaining time is clamped to the trial length.
Surfaced by `PricingBoundaryTests`: `trialDaysRemaining` returned **18** for a 7-day trial. Unlike
`V23` this needs no clock tampering and is visible on the trial chip. Root cause is in
`AccessEvaluator.trialDaysRemaining` (`AccessControl.swift:60-69`) — the remaining-time calculation
isn't clamped to the trial length. Cheap fix, cheap test, and it's the number on your main screen.

### 🟡 `N2` — Retire the tests for the won't-fix items
**✅ Done — `75690b2`.** The two accepted V23 assertions are strict expected failures, so reverting the behaviour turns them red again.
`V06` and `V23` are now accepted rather than fixed, but each has red assertions in
`PricingBoundaryTests` / `ScheduleMathBoundaryTests`. Left alone they keep the suite permanently red,
which trains everyone to ignore it.

Wrap those specific assertions in `XCTExpectFailure` with a comment recording the decision and the
date, rather than deleting them — that keeps the knowledge, keeps the suite honest, and makes the test
go red again if the behaviour ever changes. Everything else stays red until genuinely fixed.

### 🔴 `N4` — The paywall's headline stat has never displayed to anyone
**✅ Fixed — `3797744`.** App-group entitlement added to the shield extension.

`CustomShieldConfiguration.entitlements` declared only `family-controls` — no app group — yet the
shield extension writes the "times stopped" counter into `group.screentimeshield`. Without the
entitlement those writes never reached the app, so `timesStopped` was permanently 0,
`StatGate.shouldShowStat` never cleared its threshold of 5, and the paywall always fell through to
its generic copy instead of the loss-framed number it was designed around.

Found while planning the fix pass, in exactly the area the QA pass's F9 completeness critic flagged
as suspicious silence — no discovery lens had examined the `times_stopped` pipeline. Needs a device
to confirm the counter now arrives, since the shield only presents on real hardware.

### ❓ `N3` — Can an app update wipe the app-group container?
From the `V25` research. If it can, an ordinary user could lose selection, schedule and trial state
on a routine update. Verify by installing an older build, configuring it, then updating in place.
If it reproduces, this outranks most of this list.

---

## How much of this is actually established

"Confirmed" means a skeptic checked the source, re-derived the failure step by step, and agreed the
mechanism is real. It does **not** mean anyone watched it happen.

- **Four have a failing test right now** — the overnight-window math, the short-block case, the
  grandfathering date, and the clock rollback. Run `cd UnplugCore && swift test`.
- **One was verified by executing the suspect call** in four timezones — the midnight handle.
- **The other fourteen are code-level confirmations only.**
- **None have been seen on a real phone**, because the simulator cannot authorise Screen Time.

Two caveats worth carrying. Only 1 of 23 claims was rejected during verification, which is a
suspiciously low rejection rate — some of these may still soften under scrutiny. And feature 4 has
no executable proof at all, because its logic lives inside a SwiftUI view where tests can't reach it.
Three of the fixes above (`V01`, `V09`, `V16`) begin with a small extraction into `UnplugCore` for
exactly that reason.

**Before fixing anything:** the new tests are not wired into any Xcode scheme, so ⌘U and
`xcodebuild test` do not run them — only `swift test` does. A fix pass that trusts ⌘U will get a
green light without executing a single proof.

---

## Where to read more

| File | Contents |
|---|---|
| **`findings.md`** | Full report, machine-generated. Per issue: the verifier's reasoning, the step-by-step failure trace, and a second opinion. Search the ID, e.g. `V05` |
| **`iap-test-checklist.md`** | Numbered manual script for the trial → paywall → purchase → restore → grandfather flows, driven by the QA menu's state dropdown |
| **`device-matrix.md`** | Numbered script for testing on a real phone — settles the unresolved items and the fourteen nobody has watched |
| **`invariants.md`** | The 37 statements of what the app is supposed to do, which these findings violate |
| **`candidates.md`** | Raw unverified output, including 9 minor items never checked |
| **`workflow-notes.md`** | How the pass was run, what it missed, and 10 unverified leads for a second round |
| **`../status.md`** | The prioritised to-do version |
