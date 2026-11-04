# IAP & pricing QA checklist

Manual test script for the trial → paywall → lifetime-unlock flow. Work top to bottom: the sections
are ordered so expensive setup (a real purchase, a wiped install) happens once and later scenarios
reuse it.

**This runs against a dev build** — the QA menu is enabled, `PricingConfig.cutoverDate` is set to
2020-01-01 so a fresh install is *not* grandfathered, and `PricingConfig.trialDays` is shortened to
**1 day** so the whole trial can elapse overnight. Revert checklist is at the top of `status.md`.

⚠️ **Treat the real purchase as one-way within a test run.** Clearing a sandbox account's purchase history is a reset between runs, not a step inside one.
Do every pre-purchase scenario *before* step 19. After buying, turn on the QA menu's **Ignore
purchase & grandfathering** switch to get back to the unpaid screens. Apple owns the purchase
record, so the app can't undo a purchase; it can only ignore it.

The trial counts local calendar days. The rest of the day the user first arms a block is free, then
`trialDays` full days follow, and the trial ends at local midnight. On the 1-day build, a trial
started today ends at midnight at the end of tomorrow.

Day counts below assume a 7-day trial. With the 1-day build, read "N days left" as "1 day left"
throughout; what matters is that the state is right, not the number.

## Before you start

- **Settings → QA / Debug** is the menu. It has two controls:
  - **Set trial state** buttons (fresh install, started today, last day, expired). Each one rewrites
    the app's trial clock once, then the app runs normally. Nothing stays pinned, so a real purchase
    always wins.
  - The **Ignore purchase & grandfathering** switch. It treats the device as unpaid, so the trial
    screens are reachable after a sandbox purchase. A yellow banner shows on the main screen while it
    is on, and buying or restoring turns it off.

  The **Real StoreKit state** section shows what StoreKit reports, before the ignore switch.
- Most of this needs a **real device** — the simulator cannot authorize Family Controls, so nothing
  involving enforcement, shields or real app tokens is observable there. Steps marked 💻 work on the
  simulator; ones marked 📱 need the phone.
- ⚠️ **On the simulator, don't use `UNPLUG_SKIP_FC` for anything about launch or foreground.**
  Under it the app never computes the access state at launch, so it shows the default trial
  state until something recomputes it. Authorize Screen Time once (an Xcode ⌘R run does it), then launch without the flag.
- To clear a sandbox purchase on device: **Settings → App Store → Sandbox Account → Manage → clear**,
  or delete and reinstall the app. In Xcode: **Debug → StoreKit → Manage Transactions**.
- ⚠️ If **Real StoreKit state → grandfathered** reads **yes** on a fresh install, stop and note it.
  It means the environment's synthesized original-purchase date predates the cutover, so the paywall
  is unreachable without the ignore switch — and the *real* grandfathering test below is invalid.
- ⚠️ If **Real StoreKit state → purchased** reads **yes** before section D, this sandbox account
  already owns the unlock. Use a new sandbox account, or clear its purchase history in App Store
  Connect (Users and Access → Sandbox → the tester → Clear Purchase History) and reinstall.

---

## 0. Upgrade from build 18 (optional — only if build 18 is on the phone)

Builds up to 18 scheduled a **daily, never-ending** "Your blocks are off" reminder after expiry.
Build 19 and later replace it with a one-shot notification and must remove the old reminder on upgrade.

0a. 📱 On **build 18**: set a schedule, pin **Trial expired**, and open the app once.
0b. 📱 Update to build 21 from TestFlight **without deleting** the app. Open it once.
0c. 📱 Expect no "Your blocks are off" notification at the next schedule start time.

## A. Fresh install — trial not yet started

1. 💻 Delete the app. Reinstall. Launch.
2. 💻 Confirm the trial chip reads **"1 day left in trial · Unlock"** (or 7 on a full-length build).
   *(This is the case where `trial_start` is nil — the countdown shows the full length before the
   clock has actually started.)*
3. 💻 Open **QA / Debug** and confirm **Access state = trial**, **Trial days remaining = 7**, and
   the ignore switch off.
4. 📱 Pick apps, set a window, tap **Start blocking**. Confirm it arms without a paywall.
5. 💻 Reopen QA / Debug. Confirm **Trial days remaining** is still 7 — *arming* is what starts the
   trial clock, so it should now be counting from today.
6. 💻 Tap the trial chip. Confirm the paywall opens, shows the price on the buy button, and can be
   dismissed with the ✕ without buying.
7. 💻 Confirm the paywall's headline reads the generic *"Your blocks are unskippable…"* line, **not**
   the "stopped you N times" stat — the stat needs ≥5 stops.

## B. Trial running

8. 💻 QA menu → Set trial state → **Trial started today**. Confirm the chip shows the full trial length, not 0.
9. 💻 Set trial state → **Last day of trial**. Confirm the chip reads **"1 day left"** — check the
   singular reads correctly and isn't "1 days".
10. 📱 With the trial active, confirm blocking still enforces: open a restricted app, see the shield.
11. 💻 Background the app for 10 seconds, reopen. Confirm the trial state **survives** — this is what
    the old menu got wrong.

## C. Trial expired

12. 💻 QA menu → Set trial state → **Trial expired**. Confirm the chip changes to **"Trial ended · Unlock Unplug"**
    with a lock icon.
13. 💻 Tap **Start blocking**. Confirm it opens the **paywall** instead of arming.
14. 💻 Confirm **Restrict for next hour** is disabled. That is by design (`8fea951`): only the chip
    and the primary CTA open the paywall.
15. 📱 **Known bug, not yet fixed (`V19`)** — if a block was already armed before expiry, the app
    still shows an armed, normal-looking state while the extension quietly refuses to enforce.
    Confirm this is what you see, and that it matches the finding rather than something worse.
16. 📱 **Known bug, not yet fixed (`V20`)** — expiry is only recalculated when the app comes to the
    foreground. Confirm that a block armed before expiry keeps enforcing until you next open the app.

16a. 📱 **Trial ends at midnight, notification at 09:00 (overnight).** Before buying: Set trial state →
    **Last day of trial**, which ends the trial at midnight tonight. Close the app. Expect no notification at
    midnight, one *"Your Unplug trial has ended"* notification at 09:00, "Trial ended" when you open
    the app, and no repeat the next day. Buying cancels the notification.

## D. Buying the unlock — the real purchase

17. 💻 QA menu → confirm the ignore switch is **off**, then Set trial state → **Trial expired** to
    reach the paywall.
18. 💻 Open the paywall. Confirm the buy button shows a real localized price, not "Unlock forever"
    with no amount — a missing price means the product failed to load.
19. 💻 Tap buy. Complete the sandbox purchase.
20. 💻 Confirm the paywall **dismisses itself** on success.
21. 💻 Confirm the trial chip is **gone straight away**, with no QA step in between.
22. 💻 QA menu → confirm **Real StoreKit state → purchased = yes** and **Access state = fullAccess**.
24. 📱 Confirm blocking still arms and enforces after purchase.
25. 💻 Force-quit and relaunch. Confirm full access persists across a cold launch.
26. 💻 **Airplane mode on**, force-quit, relaunch. Confirm you are **not** shown the paywall.
    ⚠️ **This is `V18`, not yet fixed** — the entitlement verdict isn't persisted, so a failed lookup
    may demote you to "Trial ended". If it does, that's the known bug; record it.
27. 💻 Still offline, tap **Restore Purchase**. ⚠️ Expect the misleading **"No previous purchase
    found."** (`V17`, accepted as won't-fix). Confirm it says that rather than crashing.

## E. Restore on a clean install

28. 💻 Delete and reinstall the app **without** clearing the sandbox account.
29. 💻 Confirm the app opens in trial state (local trial data is gone with the container).
30. 💻 Open the paywall → **Restore Purchase**. Confirm full access returns and the paywall dismisses.
31. 💻 Confirm the trial chip is gone.

## F. The ignore switch, and the grandfathered user

32. 💻 After buying: QA menu → turn on **Ignore purchase & grandfathering**, then Set trial state →
    **Trial expired**. Confirm the yellow banner, the "Trial ended" chip, and that **Start blocking**
    opens the paywall.
33. 💻 In the paywall, tap **Restore Purchase**. Confirm the paywall closes, the banner and the chip
    go, and the switch is off in the QA menu.

The real grandfathering check needs the release cutover date and a genuine pre-cutover purchase
date, which a local `.storekit` config cannot fake.

34. 📱 **Real test, before shipping:** restore `PricingConfig.cutoverDate` to its production value
    (see `status.md`), install via **TestFlight** on a device whose Apple ID bought the app *before*
    that date, and confirm no trial chip and no paywall. This is the only way to verify the promise
    made to existing $0.99 customers; the simulator cannot.
35. 📱 On the same build, confirm a **post**-cutover Apple ID *does* get the trial and paywall.

## G. Refund / revocation

36. 💻 With a purchase active, revoke it in Xcode (**Debug → StoreKit → Manage Transactions** → refund).
37. 💻 Relaunch. Confirm access drops back to trial/expired and the paywall becomes reachable again.

## H. Paywall stat gate

38. 📱 QA menu → set **Times stopped** to **4**. Open the paywall. Confirm the **generic** headline.
39. 📱 Set it to **5**. Confirm the headline switches to **"Unplug stopped you 5 times during your
    trial."** — 5 is the threshold.
40. 📱 **Verify the real counter works** (`N4`, just fixed): set Times stopped to 0, arm a block, open
    a restricted app several times to hit the shield, then reopen the QA menu and confirm the count
    has gone **up**. Before the entitlement fix the shield extension's writes never reached the app,
    so this had always read 0.

## I. Localization spot-check

41. 💻 Switch the device to German. Confirm the paywall, trial chip and "Trial ended" copy are
    translated and not clipped.
42. 💻 Confirm the price still renders in the correct local format. The format follows the App Store
    *country*, not the device language, so this needs a German sandbox account or storefront.

---

## Record as you go

For each ⚠️ step, note what actually happened — several are known-unfixed findings where the point is
to confirm the bug matches its description rather than being worse. Anything that behaves *differently
from the note* is new information worth adding to `qa/README.md`.

**Do not ship build 21.** Revert checklist: top of `status.md`.
