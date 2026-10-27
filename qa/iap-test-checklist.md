# IAP & pricing QA checklist

Manual test script for the trial → paywall → lifetime-unlock flow. Work top to bottom: the sections
are ordered so expensive setup (a real purchase, a wiped install) happens once and later scenarios
reuse it.

**This runs against a dev build** — the QA menu is enabled, `PricingConfig.cutoverDate` is set to
2020-01-01 so a fresh install is *not* grandfathered, and `PricingConfig.trialLength` is shortened to
**1 day** so the whole trial can elapse in one sitting. Revert checklist is at the top of `status.md`.

⚠️ **The sandbox IAP history cannot be reliably erased, so treat the real purchase as one-way.**
Do every pre-purchase scenario *before* step 19, and after buying, use the QA dropdown's
non-entitled options to get back — they suppress a real entitlement, which is the whole reason the
override overrides the entitlement input rather than the state.

Day counts below assume a 7-day trial. With the 1-day build, read "N days left" as "1 day left"
throughout; what matters is that the state is right, not the number.

## Before you start

- **Settings → QA / Debug** is the menu. Under **Pin access state**, a dropdown pins any of the six
  states; **Off** returns to the real StoreKit state. The **Real StoreKit state** section below it
  shows what StoreKit actually reports, ignoring the override.
- Most of this needs a **real device** — the simulator cannot authorize Family Controls, so nothing
  involving enforcement, shields or real app tokens is observable there. Steps marked 💻 work on the
  simulator; ones marked 📱 need the phone.
- ⚠️ **On the simulator, don't use `UNPLUG_SKIP_FC` for anything about launch or foreground.**
  Under it the app never computes the access state at launch, so a saved pin is ignored until
  re-tapped. Authorize Screen Time once (an Xcode ⌘R run does it), then launch without the flag.
- To clear a sandbox purchase on device: **Settings → App Store → Sandbox Account → Manage → clear**,
  or delete and reinstall the app. In Xcode: **Debug → StoreKit → Manage Transactions**.
- ⚠️ If **Real StoreKit state → grandfathered** reads **yes** on a fresh install, stop and note it.
  It means the environment's synthesized original-purchase date predates the cutover, so the paywall
  is unreachable without the override — and the *real* grandfathering test below is invalid.

---

## A. Fresh install — trial not yet started

1. 💻 Delete the app. Reinstall. Launch.
2. 💻 Confirm the trial chip reads **"1 day left in trial · Unlock"** (or 7 on a full-length build).
   *(This is the case where `trial_start` is nil — the countdown shows the full length before the
   clock has actually started.)*
3. 💻 Open **QA / Debug** and confirm **Access state = trial**, **Trial days remaining = 7**,
   **Override = none**.
4. 📱 Pick apps, set a window, tap **Start blocking**. Confirm it arms without a paywall.
5. 💻 Reopen QA / Debug. Confirm **Trial days remaining** is still 7 — *arming* is what starts the
   trial clock, so it should now be counting from today.
6. 💻 Tap the trial chip. Confirm the paywall opens, shows the price on the buy button, and can be
   dismissed with the ✕ without buying.
7. 💻 Confirm the paywall's headline reads the generic *"Your blocks are unskippable…"* line, **not**
   the "stopped you N times" stat — the stat needs ≥5 stops.

## B. Trial running

8. 💻 QA menu → pin **Trial active (half elapsed)**. Confirm the chip shows a plausible countdown, not 0.
9. 💻 Pin **Trial nearly over**. Confirm the chip reads **"1 day left"** — check the
   singular reads correctly and isn't "1 days".
10. 📱 With the trial active, confirm blocking still enforces: open a restricted app, see the shield.
11. 💻 Background the app for 10 seconds, reopen. Confirm the pinned state **survives** — this is what
    the old menu got wrong.

## C. Trial expired

12. 💻 QA menu → pin **Trial expired**. Confirm the chip changes to **"Trial ended · Unlock Unplug"**
    with a lock icon.
13. 💻 Tap **Start blocking**. Confirm it opens the **paywall** instead of arming.
14. 💻 Confirm **Restrict for next hour** is disabled. That is by design (`8fea951`): only the chip
    and the primary CTA open the paywall.
15. 📱 **Known bug, not yet fixed (`V19`)** — if a block was already armed before expiry, the app
    still shows an armed, normal-looking state while the extension quietly refuses to enforce.
    Confirm this is what you see, and that it matches the finding rather than something worse.
16. 📱 **Known bug, not yet fixed (`V20`)** — expiry is only recalculated when the app comes to the
    foreground. Confirm that a block armed before expiry keeps enforcing until you next open the app.

16a. 📱 **Trial-ended notification (one-shot).** Before buying: pin **Trial nearly over**, which puts
    the end of the trial about 2 h 24 min away on the 1-day build. Close the app. Expect one
    *"Your Unplug trial has ended"* notification at that time, and no repeat the next day. Buying
    cancels it.

## D. Buying the unlock — the real purchase

17. 💻 QA menu → pin **Off**, so you're testing the real path. Then pin **Trial expired** to reach the
    paywall. *(Off first clears any stale override; the expired pin only suppresses entitlement, so
    the purchase itself is still real.)*
18. 💻 Open the paywall. Confirm the buy button shows a real localized price, not "Unlock forever"
    with no amount — a missing price means the product failed to load.
19. 💻 Tap buy. Complete the sandbox purchase.
20. 💻 Confirm the paywall **dismisses itself** on success.
21. 💻 QA menu → pin **Off** first (the step-17 pin suppresses the new entitlement too). Then confirm
    the trial chip is **gone entirely**.
22. 💻 QA menu → confirm **Real StoreKit state → purchased = yes** and **Access state = fullAccess**.
23. 💻 Pin **Off** and confirm the state stays `fullAccess` — the entitlement is real, not the override.
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

## F. Grandfathered user

The override covers the *UI* path; the real check needs the cutover date and a genuine pre-cutover
purchase date, which a local `.storekit` config cannot fake reliably.

32. 💻 QA menu → pin **Full access — grandfathered**. Confirm no trial chip, no paywall, and that
    **Start blocking** works.
33. 💻 Confirm **Access state = fullAccess** while **Real StoreKit state → purchased = no**.
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

**Do not ship build 18.** Revert checklist: top of `status.md`.
