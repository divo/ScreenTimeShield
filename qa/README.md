# Unplug QA pass — executive summary

**26 July 2026.** A systematic bug hunt across three features: the schedule slider, arming and
disarming blocks, and the trial/paywall/lifetime-unlock flow. Chosen because the first two are the
UI redesign that has never had on-device QA, and the third is code no customer has ever run.

**19 confirmed problems, 3 unresolved, 1 investigated and dismissed.** No fixes applied — this pass
only finds and proves.

| | |
|---|---|
| Breaks the "no bypass" promise | 2 |
| Traps or wrongly blocks a legitimate user | 7 |
| Costs money, or charges the wrong person | 5 |
| Confusing or broken UI | 5 |
| Proven by a test you can run today | 4 |
| Ever observed on a real phone | **0** |

### Fix these three first

1. **The grandfathering date has already passed** — one constant, and the only item with a deadline.
2. **The overnight-window math is wrong** — one function, already proven wrong, with a test that
   checks any fix against every possible window.
3. **The one-hour block can kill your nightly block** — it breaks the promise on your App Store page.

---

## 1. The schedule slider

### 🔴 The right-hand end of the slider doesn't mean midnight · `V01`
*Fires on the gesture the UI advertises · no test yet*

The slider prints "24:00" as its last tick. Dragging the end handle there asks iOS for hour 24,
which doesn't exist — the call fails, and the code falls back to **the current time**. Your end time
silently becomes "now", the window is now backwards, and iOS reads a backwards window as wrapping
midnight. Result: a block of up to ~24 hours that you never configured and can't stop, arriving with
no confirmation prompt. Confirmed by actually running the failing call in four timezones.

### 🔴 The safety check can't understand overnight blocks · `V05`
*Common — it is the app's main use case · **proven by test***

Before arming, the app checks "would this leave almost no free time?" by subtracting start from end.
For a 10pm–7am window that subtraction goes negative, gets clamped to zero, and the app concludes
the **whole day is free** — so it never warns you. Measured against a brute-force reference, the
answer is wrong for **1,036,080 of 2,073,600** possible windows: precisely every one that crosses
midnight. It also makes the slider draw the wrong picture for anyone with an existing overnight
window.

### 🔴 Your window drifts by an hour twice a year · `V02`
*Common across the user base · partly proven*

Times are saved as absolute moments but read back as clock times in whatever timezone the phone is
in now. When the clocks change, the slider shows times you never picked — and the next edit
re-registers the block at those drifted times. Affects every armed user in a DST-observing region,
which is most of the ten shipped locales, plus anyone who travels.

### 🔴 Short windows hide the start handle · `V04`
The two handles overlap, so the start one can't be grabbed.

### 🟡 Allow-only mode can build a block iOS rejects · `V06`
*proven by test*

Allowing nearly the whole day leaves a blocked interval shorter than the minimum iOS will monitor.
Registration fails, the error is swallowed, and nothing blocks — silently.

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

### 🔴 The app doesn't notice when a block starts · `V11`, `V14`
*Common · needs phone*

The main app and the background extension are separate processes, and the app reads the
"block active" flag using a mechanism that doesn't watch for writes from another process. If you're
looking at the app when your block begins, the banner still says "Block inactive", the schedule
stays editable when it should lock, and Stop stays tappable. Most visible in the obvious first-run
habit: set the window to start in a minute, watch, conclude it's broken.

### 🔴 Deselecting every app while armed · `V09`
*needs phone*

The schedule stays registered, so the block still starts on time and locks the interface — while
shielding nothing.

### ❓ Turning Screen Time off mid-block may brick the app · `V13`
*unresolved — depends on undocumented iOS behaviour*

The "block active" flag may never clear, leaving the app permanently showing "Blocking" with a
disabled button and no way out. Reinstalling would be the only escape, since the QA reset menu is
commented out for release. The phone-test script is designed to establish which way iOS actually
behaves.

### ❓ A blocking system call on the launch path · `V12`
*unresolved*

The list of registered activities is read synchronously on the main thread at launch — the same
class of call that caused the arm-confirm stall already recorded in `status.md`.

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

A customer who paid, and is entitled to free access forever, is told they never bought anything and
gets no block that night. This is the refund-and-one-star path.

### 🔴 The grandfathering date has already passed · `V22`
*⏱ Deadline-bound · **proven by test***

You promised that anyone who bought the app before the IAP launch keeps it free. The code compares
their download date against a fixed cutover of **25 June 2026** — now a month in the past, with 1.3
still unshipped. Everyone who paid $0.99 since then is on the wrong side of the line and will be
asked to pay again the day 1.3 goes live. Nobody is affected today; the whole group is affected the
moment it ships, and the group grows by a day for every day of slip.

### 🔴 Buying the unlock mid-block does nothing until tomorrow · `V21`
*Common among people who convert after the trial · needs phone*

Trial expires, that evening nothing is blocked, the user buys the unlock — the exact thing the app
is asking them to do — and enforcement doesn't return until the next window. This sits directly on
your own conversion path, and it hits users who are actively trying to make the product work.

### 🔴 If you never reopen the app, the trial never ends · `V20`
*needs phone*

Whether enforcement is allowed is cached in a flag that only recalculates when the app comes to the
foreground. Set your schedule, close the app, never open it again — blocks keep working, free,
indefinitely. No cleverness required.

### 🔴 Rolling the clock back restores an expired trial · `V23`
***proven by test***

The trial is a start date compared against the current time, with no tamper-proof anchor. For a
self-restraint app the "attacker" is your own user at 11pm, so this is closer to the core threat
model than a typical security edge case. The same tests turned up a related oddity: the countdown
returned **18 days remaining** for a 7-day trial under some inputs.

### 🔴 Purchases made outside the buy button are never seen · `V15`
*Rare*

Nothing listens for transactions arriving from elsewhere — a parent approving Ask to Buy, a purchase
on another device, an interrupted purchase completing later. None register while the app is open,
and completed transactions are never closed out.

### 🔴 Expiry never stops the schedule · `V19`
*needs phone*

Nothing deregisters the daily schedule when the trial ends, so the app sits looking armed —
"Stop blocking" and all — while the background extension quietly refuses to enforce anything.

### 🔴 A pending purchase looks like a silent failure · `V16`
A purchase awaiting approval is reported identically to an outright failure, so the user taps buy
and sees nothing at all — no spinner resolution, no error, no explanation.

### 🟡 Restore blames the customer for a network failure · `V17`
"No previous purchase found" is shown when the restore call itself failed. See `V18` above — this is
the second half of that story.

### 🟡 A debug flag that can't be switched off · `V24`
A "force full access" switch is readable in release builds and no code path ever clears it. Real
exposure today is nil — your own device and testers of the pulled build — but it's a live switch in
shipping code.

### ❓ Reinstalling may reset the trial · `V25`
*unresolved*

The trial start lives in storage that delete-and-reinstall may wipe. Whether it actually does is OS
behaviour that couldn't be established from documentation.

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
