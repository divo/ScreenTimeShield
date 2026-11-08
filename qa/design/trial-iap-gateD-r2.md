# Gate D, review of v3 (model H) — verdict SHAKY (2026-11-08)

Holes, condensed:
1. Listener/purchase re-ask StoreKit (snapshot incl. AppTransaction) instead of using the verified
   transaction in hand — the postmortem's second cause again; a hung AppTransaction stalls the serial
   listener; purchase path never records the new id. Write the held transaction; snapshot only on refresh.
2. First arm after the ceiling has passed (download + 14 days) has no outcome: trial starts expired,
   schedule arms but never enforces; chip says "7 days left" pre-arm. Evaluator must use the ceiling
   even with no start date; first arm past the ceiling → paywall, no arm.
3. 7b puts one failable call (AppTransaction) on the arm button: signed-out users, offline, sandbox
   reviewer locked out; no timeout/double-tap guard; `.unverified` undefined; "doesn't prompt" is
   unverified. Smaller: fail open (start the local trial), fill in the ceiling at the next successful
   refresh. Removes FirstArm, .unreachable, async gate, new string.
4. Third trial-start path: `applySchedule()` → `startTrialIfNeeded()` (`ContentView.swift:71`, runs on
   selection change). Missing start date → `.trial` even when everything else is stored.
5. Purchased rule assumes increasing transaction ids (undocumented); "order-independent" is false (a
   stale snapshot can re-grant after a refund). Store the granting transaction id; revoke only when that
   id shows revoked; serialize refreshes or accept the stale re-grant as a known limit.
6. Earliest-wins / never-cleared derived values make a bad write permanent. Store the raw production
   `originalPurchaseDate`; derive grandfathering and the ceiling each time (app and extension).
7. No disclosure before the trial starts (3.1.1 asks for duration, what stops, price). Show "7-day free
   trial, then $4.99 one-time" before the first arm; put it in the review notes.
8. Criterion 11 can still pass empty: `StoreKitEdgeTests.swift` isn't in any target; the simulator
   can't arm (Family Controls); the uncommitted `ScreenTimeShield.xctestplan` includes UI tests.
9. Cutover +14 days would grandfather the launch cohort (marketing aims at launch installs), permanently.
   Keep cutover = 00:00 UTC the day after release, manual release, Free the same day.
10. Buy-mid-window re-arm, expired-looks-armed screen, refocus notifications still undecided.
11. The production-only line is untestable before release; add a release-day check with a 1.2-owner
    Apple ID; check whether a promo code on a Pending Developer Release build gives a production install.
12. How the QA expire button is hidden in release is unspecified; show it only when environment ≠ production.
13. `KeyValueStore` lacks bool/UInt64/missing-vs-false; `AppGroupStore` isn't in the monitor target.

Scope cuts: FirstArm/.unreachable/async gate/new string (fail open); snapshots for purchase/listener;
grandfathered + trialCeiling + earliest-wins (one raw date); purchased + newest id (one granting id);
arming in the simulator pass unless proven; dev trialDays override; unused `EntitlementProviding`.
