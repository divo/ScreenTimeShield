# IAP & pricing QA checklist

Manual test script for the trial → paywall → lifetime-unlock flow. Work top to bottom: the sections
are ordered so expensive setup (a real purchase, a wiped install) happens once and later scenarios
reuse it.

**Build 17 is a dev build** — the QA menu is enabled and `PricingConfig.cutoverDate` is set to
2020-01-01 so a fresh install is *not* grandfathered. Revert checklist is at the top of `status.md`.

## Before you start

- **Settings → QA / Debug** is the menu. Under **Pin access state**, a dropdown pins any of the six
  states; **Off** returns to the real StoreKit state. The **Real StoreKit state** section below it
  shows what StoreKit actually reports, ignoring the override.
- Most of this needs a **real device** — the simulator cannot authorize Family Controls, so nothing
  involving enforcement, shields or real app tokens is observable there. Steps marked 💻 work on the
  simulator; ones marked 📱 need the phone.
- To clear a sandbox purchase on device: **Settings → App Store → Sandbox Account → Manage → clear**,
  or delete and reinstall the app. In Xcode: **Debug → StoreKit → Manage Transactions**.
- ⚠️ If **Real StoreKit state → grandfathered** reads **yes** on a fresh install, stop and note it.
  It means the environment's synthesized original-purchase date predates the cutover, so the paywall
  is unreachable without the override — and the *real* grandfathering test below is invalid.

---

## A. Fresh install — trial not yet started

1. 💻 Delete the app. Reinstall. Launch.
2. 💻 Confirm the trial chip reads **"7 days left in trial · Unlock"**.
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

8. 💻 QA menu → pin **Trial active (3 days left)**. Confirm the chip reads **"3 days left"**.
9. 💻 Pin **Trial final day (1 day left)**. Confirm the chip reads **"1 day left"** — check the
   singular reads correctly and isn't "1 days".
10. 📱 With the trial active, confirm blocking still enforces: open a restricted app, see the shield.
11. 💻 Background the app for 10 seconds, reopen. Confirm the pinned state **survives** — this is what
    the old menu got wrong.

## C. Trial expired

12. 💻 QA menu → pin **Trial expired**. Confirm the chip changes to **"Trial ended · Unlock Unplug"**
    with a lock icon.
13. 💻 Tap **Start blocking**. Confirm it opens the **paywall** instead of arming.
14. 💻 Tap **Restrict for next hour**. Confirm it also routes to the paywall.
15. 📱 **Known bug, not yet fixed (`V19`)** — if a block was already armed before expiry, the app
    still shows an armed, normal-looking state while the extension quietly refuses to enforce.
    Confirm this is what you see, and that it matches the finding rather than something worse.
16. 📱 **Known bug, not yet fixed (`V20`)** — expiry is only recalculated when the app comes to the
    foreground. Confirm that a block armed before expiry keeps enforcing until you next open the app.

## D. Buying the unlock — the real purchase

17. 💻 QA menu → pin **Off**, so you're testing the real path. Then pin **Trial expired** to reach the
    paywall. *(Off first clears any stale override; the expired pin only suppresses entitlement, so
    the purchase itself is still real.)*
18. 💻 Open the paywall. Confirm the buy button shows a real localized price, not "Unlock forever"
    with no amount — a missing price means the product failed to load.
19. 💻 Tap buy. Complete the sandbox purchase.
20. 💻 Confirm the paywall **dismisses itself** on success.
21. 💻 Confirm the trial chip is now **gone entirely**.
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
42. 💻 Confirm the price still renders in the correct local format.

---

## Record as you go

For each ⚠️ step, note what actually happened — several are known-unfixed findings where the point is
to confirm the bug matches its description rather than being worse. Anything that behaves *differently
from the note* is new information worth adding to `qa/README.md`.

**Do not ship build 17.** Revert checklist: top of `status.md`.
