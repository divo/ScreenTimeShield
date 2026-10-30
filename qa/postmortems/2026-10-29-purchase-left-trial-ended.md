# Postmortem: a purchase left the app on "Trial ended"

**Date of report:** 2026-10-29 · **Build:** 19 (QA build, TestFlight) · **Status:** fix written, not yet
on a device · **Severity:** release blocker for 1.3

## Summary

During device QA, a sandbox purchase of the lifetime unlock succeeded after the trial had expired. The
paywall closed, but the app still said "Trial ended" and asked the user to unlock again.

No customer was affected. 1.3 has not shipped, and the purchase flow only exists in 1.3.

The most likely cause is a QA tool, not the production purchase path. A QA pin on the access state
was still set, and the pin hides a real purchase by design. I saw this exact symptom on the simulator
two days earlier, called it "by design", and changed the checklist instead of the app. That was the
main failure, and it was mine.

A second cause is possible but not confirmed. After a purchase, the app re-asked StoreKit for the
user's purchases instead of trusting the purchase it had just received. If StoreKit answered late,
real customers would see the same symptom.

Both causes have a fix in the working tree. Neither fix has been on a device yet.

## Impact

- **Customers:** none. 1.3 is not released.
- **QA:** one device purchase run is invalid and must be repeated. The sandbox purchase is one-way, so
  the repeat needs a fresh sandbox account, or a re-test that uses the pins.
- **Release:** the target was today, Fri 2026-10-30. The fix needs a new build and a device re-run of
  the purchase cases, so the release moves unless that happens today.
- **Trust:** the core money path looked broken in front of the owner. That cost is real even though
  the cause is most likely QA-only.

## Background: what a QA pin does

The QA menu has an **access state pin** (`QAAccessOverride`, added in `691d2d8` on 2026-08-04). A pin
forces the app into one state: fresh install, trial, last trial day, expired, purchased or
grandfathered.

A pin replaces the *entitlement input*, not the state itself. The non-entitled pins (fresh install,
trial, last day, expired) tell the app "this user has not paid", even when StoreKit says they have.
This is deliberate: a sandbox purchase can't be undone, so after one purchase the pins are the only
way back to the pre-purchase screens.

The cost of that design: **while a non-entitled pin is set, a real purchase is invisible.** Nothing
cleared the pin when the user bought.

## Timeline

| When | What happened |
|---|---|
| 2026-06-16 | `Store.purchase()` written. After a verified purchase, it calls `refreshPurchasedState()`, which re-reads `Transaction.currentEntitlements` rather than using the transaction in hand. |
| 2026-08-04 | `691d2d8`: the access state pin replaces the old QA buttons. The commit message states that a non-entitled pin suppresses a real purchase. |
| Earlier QA pass | Findings `V15`, `V16`, `V18`, `V21` record gaps in the purchase flow (no `Transaction.updates` listener, pending purchases reported as failures, no stored purchase verdict, no re-enforcement after buying). All were marked "fix". |
| 2026-10-27 | Release decision: only QA blocks 1.3. `V15`, `V16`, `V18` and `V21` move to 1.3.1. |
| 2026-10-27 | Simulator QA on build 18, section D. **After buying with the "Trial expired" pin set, the chip stayed on "Trial ended".** I recorded it as "steps 21–22 are out of order … by design" and moved the "pin Off" step in the checklist (`qa/README.md`, build 18 run). The app was not changed. |
| 2026-10-27 | `b3881ff`: the in-app QA checklist. The buy case says "pin Off, then pin Trial expired" before buying. The "pin Off" that makes the purchase visible is in the *next* case. The notification case leaves "Trial nearly over" pinned. |
| 2026-10-27 | Build 19 archived for TestFlight with this checklist. |
| 2026-10-29 | Device QA: the trial expires, the purchase succeeds, and the app stays on "Trial ended". Reported via another Claude session. |
| 2026-10-29 | Fix written (not committed): a purchase now grants access from the transaction in hand, and clears a non-entitled pin. |

## Root cause

**Probable, not confirmed:** a non-entitled pin was still set when the purchase went through.

The evidence for it:
- The buy case in the checklist tells the tester to pin **Trial expired** right before buying. The
  step that unpins comes one case later. So the screen right after a correct purchase showed "Trial
  ended", exactly as reported.
- The overnight notification case leaves **Trial nearly over** pinned until the trial expires. "After
  the trial expired" in the report matches that case.
- The simulator showed the same symptom on 2026-10-27 with a pin set.

**What would confirm it:** QA / Debug on the phone, the **Override** row. If it shows a pin, this is
the cause. If it shows **none** while **StoreKit purchased = yes** and the app still says "Trial
ended", the cause is the second one below, and it would affect real customers.

**Possible second cause:** `Store.purchase()` re-read `Transaction.currentEntitlements` straight after
`finish()`. If that list did not yet include the new purchase, `isPurchased` stayed `false`. The
paywall still closed, because it closes on any verified purchase. The app would then show "Trial
ended" until the next time it came to the foreground. I have not reproduced this. It is in the
production path, so it is fixed regardless.

## Why it got through

1. **I wrote off a symptom in the core money path as "by design".** The design was deliberate, but
   "the user pays and still sees Trial ended" is never an acceptable state, even in QA. The right
   response on 2026-10-27 was to make the purchase clear the pin, or to ask you. I edited the
   checklist instead.
2. **The checklist fix put the unpin step after the moment the tester looks.** A tester follows the
   case they are on. Expecting them to read ahead to the next case to see a correct result was the
   wrong place for it.
3. **Two QA cases leave a non-entitled pin set for hours.** Nothing on the main screen shows that a
   pin is active, so the app looks like the real app while it is not.
4. **No automated test covers the purchase path.** `UnplugCore` tests only pure logic. `Store` and
   `AccessController` have no tests, and the app test suite (`xcodebuild test`) fails to launch on
   the simulator in this environment ("Simulator device failed to launch … RequestDenied"). It did
   not run on 2026-10-28 or 2026-10-29.
5. **The known purchase-flow gaps were deferred.** `V15`, `V16`, `V18` and `V21` are all "the app's
   idea of purchased lags reality". They moved to 1.3.1 under "only QA blocks the release". None of
   them caused this report, but they live in the same code (`Store.swift`).

## What went well

- Device QA caught it before release. That is what the dev build and the checklist were for.
- The pin design meant every pre-purchase screen stayed reachable after the one-way sandbox purchase.

## Fixes (in the working tree, not committed)

1. **A verified purchase sets `isPurchased = true` directly** (`ScreenTimeShield/Store.swift:42`). It
   no longer depends on `currentEntitlements` having caught up.
2. **A successful purchase clears a non-entitled pin** (`ScreenTimeShield/AccessController.swift`,
   `purchase()`). Release builds never set a pin, so this only changes QA builds.
3. **The QA checklists now expect the chip to disappear immediately after buying**, with Override =
   none (`ScreenTimeShield/QAChecklistView.swift`, `qa/iap-test-checklist.md` steps 20–21).

`swift test` passes 58/58 and the simulator build succeeds. The app test suite did not run (see 4
above).

## Actions

| # | Action | Owner | Blocks 1.3? |
|---|---|---|---|
| 1 | Check QA / Debug → **Override** on the phone that made the purchase, and report what it shows. This confirms or rules out the pin. | Steven | Yes |
| 2 | Commit build 20 (calendar-day trial and this fix). Archive and upload to TestFlight. | Claude, then Steven | Yes |
| 3 | Re-run the purchase cases on build 20 on a device: once with no pin, once with the "Trial expired" pin set. Both must show full access straight after buying. Use a new sandbox account, because the old one already owns the unlock. | Steven | Yes |
| 4 | Show a visible "QA pin: …" label on the main screen whenever a pin is set, so a pinned app never passes for the real one. | Claude | No (QA builds only) |
| 5 | Add a StoreKitTest unit test: a purchase through `AccessController` against `StoreKit.storekit` must end in `.fullAccess`. This is the test that would have caught the second cause. Needs the app test suite to launch first. | Claude | Recommended |
| 6 | Fix the app test suite launch failure on the simulator. | Claude | Recommended |
| 7 | Decide whether `V15` (no `Transaction.updates` listener) moves back into 1.3. It is the remaining gap where a real customer can pay and not get access until a later launch (Ask to Buy, interrupted purchases). It is a small change in `Store.swift`. | Steven | Your call |

## Lesson

A symptom in the purchase path does not get classified as "by design" without the owner's sign-off,
even when the code behaves as written. If paying leaves the user on a paywall, the design is wrong.
