# Unplug QA pass — executive summary & fix plan

**26 July 2026.** A systematic bug hunt across three features: the schedule slider, arming and
disarming blocks, and the trial/paywall/lifetime-unlock flow. Chosen because the first two are the
UI redesign that has never had on-device QA, and the third is code no customer has ever run.

**19 confirmed problems, 3 unresolved, 1 investigated and dismissed.** Now triaged with Steven's
decisions (26 Jul). No code changed yet.

| | |
|---|---|
| Breaks the "no bypass" promise | 2 |
| Traps or wrongly blocks a legitimate user | 7 |
| Costs money, or charges the wrong person | 5 |
| Confusing or broken UI | 5 |
| Proven by a test you can run today | 4 |
| Ever observed on a real phone | **0** |

## Triage outcome

| Disposition | Items |
|---|---|
| **Fix** | `V01` `V02` `V04` `V05` `V07` `V09` `V11`+`V14` `V18` `V19` `V20` `V21` `V22` `N1` |
| **Fix — one piece of work: "complete the payment flow"** | `V15` + `V16` + `V18`'s persistence |
| **Fix — two defensive lines** | `V12` |
| **Won't fix — accepted** | `V06` `V17` `V23` `V24` |
| **Verify on device, then harden with Keychain** | `V25` `N3` |
| **Verify on device** | `V13` |
| **Housekeeping created by this triage** | `N2` |

### Work that clusters — do these together, not item by item

- **Schedule storage** — `V02` + `V01`. Moving to minutes-of-day deletes the `Date` round trip that
  causes `V01`, so doing them separately means writing `V01`'s fix twice.
- **Payment flow** — `V15` + `V16` + `V18` + `V21`. One coherent change: every purchase outcome gets a
  defined path, the verdict is persisted, and a live window lights up immediately.
- **Trial state** — `V19` + `V20` + `V18`'s persisted flag. The extension needs to judge expiry
  itself, and the UI needs an honest "inactive because the trial ended" state.
- **Cross-process truth** — `V11` + `V14` + most of `V13`. Derive active-state from the clock instead
  of a flag, and three findings collapse into one fix.
- **Durability** — `V25` + `N3` + the Keychain move, gated on the device check first.

### Three open questions before I start

Each is a fork where guessing wrong means doing the work twice. They're marked ⚠️ in place below:
`V09` (which removal rule to lock in), `V02` (how to handle the one-hour migration ambiguity), and
`V07` (whether to refuse an overlapping quick-hour block).

Three of the annotations rested on a claim that turned out to be wrong or incomplete — `V09`
(deselection is *not* currently prevented), `V15` ("only one purchasing flow"), and `V25`
(reinstall). Each is corrected in place below.

### Suggested order

1. `V22` — one constant, has a deadline.
2. `V05` + `N1` — proven wrong, one function each, oracle test already written.
3. `N2` — retire the tests for the two won't-fix items so the suite can reach green.
4. `V19` + `V20` + `V21` + `V18` — the money and trial-state cluster; they share a root cause and a fix design.
5. `V07` — the bypass. Needs the device answer from step 7 to pick the right approach.
6. `V15` + `V16`, `V11`+`V14`, `V09`, `V12`.
7. Device sitting (`qa/device-matrix.md`) — settles `V13`, `V25`, `N3` and confirms the rest.

---

## 1. The schedule slider

### 🔴 The right-hand end of the slider doesn't mean midnight · `V01`
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

**The migration is the risky part, and it has an unavoidable flaw worth stating plainly.** Existing
users have a stored `Date` whose intended wall-clock time can only be recovered by applying *some*
UTC offset — and the offset that was in force when they last dragged the slider is not recorded
anywhere. So migration must read it with the current calendar, which is correct for everyone who
hasn't changed zone or crossed a DST boundary since, and one hour out for those who have. There is no
way to do better with the data we have.

⚠️ **Open question — what do we do about the hour we can't recover?** Three options: (a) migrate
silently and accept that a minority wake up with a window an hour off from what they last saw;
(b) migrate silently but **disarm** anyone whose values migrate, forcing a deliberate re-arm — safest
for correctness, annoying for people whose schedule was fine; (c) migrate and show a one-time
"check your block times" notice. I'd take (c): it's honest, it's one alert, and it costs a user who
was unaffected two seconds. (a) is defensible given the affected slice is small.

One piece is already covered: the composed case where drift inverts the window is proven red in
`ScheduleMathBoundaryTests:256`, and the `V05` fix resolves that half.

### 🔴 Short windows hide the start handle · `V04`
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

⚠️ **Open question.** Should the quick hour block be *refusable* when a scheduled block is already
running? Right now it happily registers a second overlapping activity, and that overlap is the root of
the collision — the conditional teardown above is a guard against a situation we could decline to
create. Refusing it (or greying out the button while a block is active) removes the whole class of
problem; it also changes behaviour someone may rely on. I'd do both: conditional teardown as the
safety net, plus declining the redundant overlap. Your call on the second half.

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

> **Decision: fix, and lock it in with a test.**

**Plan.** Lift `validateRestriction`'s logic out of `Model` so it can be tested at all — it is pure
set arithmetic over token collections, so a small pure function in `UnplugCore` taking
(previous tokens, new tokens, current state) and returning a verdict is enough. `Model` keeps a thin
wrapper so the call site doesn't change shape.

Then widen the guard from `insideInterval` to cover the armed state, and add tests pinning the whole
truth table: removal while idle (allowed), removal while armed-but-inactive (currently allowed —
**see open question below**), removal while active (blocked), addition in every state (always
allowed), and emptying the selection entirely.

⚠️ **Open question — which behaviour do we lock in for armed-but-inactive?** Two defensible answers
and I don't want to pin the wrong one into a test: (a) **block the removal**, matching what you
expected the code to do, which keeps an armed block's promise intact all day; or (b) **let it through
and auto-disarm**, matching the existing "editing the schedule while inactive disarms" rule at
`ContentView.swift:90-92`. I lean to (b) for consistency, but (a) is the stronger promise. Deciding
this *is* the fix — the test just makes it permanent.

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
Surfaced by `PricingBoundaryTests`: `trialDaysRemaining` returned **18** for a 7-day trial. Unlike
`V23` this needs no clock tampering and is visible on the trial chip. Root cause is in
`AccessEvaluator.trialDaysRemaining` (`AccessControl.swift:60-69`) — the remaining-time calculation
isn't clamped to the trial length. Cheap fix, cheap test, and it's the number on your main screen.

### 🟡 `N2` — Retire the tests for the won't-fix items
`V06` and `V23` are now accepted rather than fixed, but each has red assertions in
`PricingBoundaryTests` / `ScheduleMathBoundaryTests`. Left alone they keep the suite permanently red,
which trains everyone to ignore it.

Wrap those specific assertions in `XCTExpectFailure` with a comment recording the decision and the
date, rather than deleting them — that keeps the knowledge, keeps the suite honest, and makes the test
go red again if the behaviour ever changes. Everything else stays red until genuinely fixed.

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
| **`device-matrix.md`** | Numbered script for testing on a real phone — settles the unresolved items and the fourteen nobody has watched |
| **`invariants.md`** | The 37 statements of what the app is supposed to do, which these findings violate |
| **`candidates.md`** | Raw unverified output, including 9 minor items never checked |
| **`workflow-notes.md`** | How the pass was run, what it missed, and 10 unverified leads for a second round |
| **`../status.md`** | The prioritised to-do version |
