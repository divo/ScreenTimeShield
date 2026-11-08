## UNPLUG-TRIAL: automatic 7-day trial, lifetime unlock, grandfathering — done reliably

*v4, 2026-11-08. The approved plan below supersedes v3's Option H details where they differ. It closes
gate D r2 (`trial-iap-gateD-r2.md`): holes 1–6, 8, 12, 13 in the design; 7, 9, 10, 11 by Steven's
decisions (notice in the confirmation; cutover a few days after release; buy-at-night re-apply,
paused state and reminders in scope; release-day production check). v3 kept below for the criteria
and code map, with these criterion changes: 1 — notice line in the first-block confirmation;
2 — cap = first block within 14 days of download, trial ends by download + 21 days, production only;
6 — a refund revokes only when Apple reports the **granting** purchase (`originalID`) refunded, not
"the newest"; 7 — grandfathering is derived each time from the latest verified answer, never stored as
a flag;
7b — `AppTransaction` with a 10 s timeout, verified only; 9 — paused state; 10 — QA menu only outside
production; new 12 — a purchase during an active window applies the block at once; new 13 — usage
reminders stop after expiry.*

## v5 amendments (after gate D r3, `trial-iap-gateD-r3.md`) — these override v4 where they differ

1. First block decides from **stored** facts first: full access (grandfathered or granting transaction)
   → arm with no notice; a stored verified Apple answer → use it (no network call). Only with no stored
   Apple answer does it call `AppTransaction.shared` (10 s timeout via an unstructured `Task` and a
   one-shot continuation, so a non-cancellable hang can't hold it). (r3 holes 1, 4, 9)
2. While expired, schedule edits are locked like during an active block, so the schedule is kept. An
   active block from before expiry wins over "paused" on the banner and the button. (r3 hole 2)
3. Refreshes are **not** serialized; every write is idempotent. Refresh `AppTransaction` gets the same
   timeout; the Screen Time authorization re-read moves out of the refresh path. (r3 hole 3)
4. One boundary function: the last day a trial can start (production: download day + 14). A nil start
   past it is expired; the chip and the trial-ended notification use the capped end. (r3 hole 5)
5. Chip hidden while no verified Apple answer and no trial start are stored. (r3 hole 7)
6. Re-apply after access returns: `ContentView.onChange(of: accessState)` leaving `.expired` → the
   existing `applySchedule()`. Covers purchase, restore, listener and refresh; the extension stays the
   single writer of `inside_interval`. No re-apply code in AccessController. (r3 hole 8)
7. A refresh grants access too (a reinstall shows full access without Restore). A refresh that read
   `Transaction.all` before a refund can re-grant once; it heals on the next refresh — known limit.
   An SKTestSession test proves a refunded non-consumable appears in `Transaction.all` with a
   revocation date; the listener clears only when the revoked transaction's `originalID` equals the
   stored granting `originalID`. (r3 hole 10)
8. Apple facts stored as **one Codable value under one key** (download date, environment, granting
   original id); `trialStart` under its own key (set once). (r3 hole 11)
9. Move `AppGroupStore`/`AppGroupKeys` into UnplugCore (add bool/missing-vs-false) instead of a new
   store; delete the app copy. Slice 2. (scope cut)
12. A stored trial start decides on its own: with one stored, the first block arms (or opens the unlock
    screen once it ended) without asking Apple; the cap is filled at the next refresh. A trial start is
    only ever stored after Apple has answered, under the new key `trial_started_at`, so leftovers from
    dev builds (`trial_start`) are never read. (gate B r1 #5, r2 #2)
13. **Before the first block (Steven, 2026-11-08):** the chip says "7-day free trial · Unlock", with no
    countdown; the countdown starts at the first block. No trial-ended notification without a trial
    start; past the start window, a block attempt opens the unlock screen. `trialDaysRemaining`
    returning the full trial length before a start matches this. (gate B r3 #1)
10. Delete the V18 test; turn the remaining V16 skips into failures. The TestFlight run starts from a
    deleted app. (r3 hole 12)
11. **QA menu (Steven, 2026-11-08):** back to manual removal — visible in TestFlight builds, commented
    out by hand before the App Store build, as the release checklist says today. (r3 hole 6)

### Approved plan: reliable trial, unlock and grandfathering for Unplug 1.3

## Context

Unplug 1.3 goes from a $0.99 paid app to free + 7-day trial + $4.99 lifetime unlock, with earlier
buyers free for life. The hand-built version keeps failing QA:
- QA mocks hid real purchases (postmortem `qa/postmortems/2026-10-29-purchase-left-trial-ended.md`);
- in Apple's test environment the download date is always 2013, so every tester **and the App Review
  reviewer** counts as an old buyer and never sees the unlock;
- an empty answer from StoreKit takes a purchase away;
- the trial only expires when the user opens the app.

This plan rebuilds the access logic on Apple's facts, removes all purchase mocking, and makes QA
automatic. Design history and the two adversarial reviews: `qa/design/trial-iap.md`,
`trial-iap-gateD-r1.md`, `trial-iap-gateD-r2.md`.

## Decisions (Steven, 2026-11-08)

| Topic | Decision |
|---|---|
| Trial model | Starts automatically at the **first block** (either button). No $0 purchase. |
| Late start / reinstall cap | A first block within **14 days of the Apple ID's first download** gets the full 7 days; later → unlock screen, no arm. A reinstall can't push a trial past download + 21 days. Real App Store only. |
| First block, Apple unreachable | **Don't arm.** "Couldn't reach the App Store" message. |
| Trial notice | One line in the "Start blocking?" confirmation, shown on the first block every time: trial length, what stops, the $4.99 price. |
| Cutover | A few days after release, set when the final build is prepared. |
| Buy while a block window is on | Block applies **straight away**. |
| Screen after expiry | Clear **"paused — trial ended"** state; main button opens the unlock screen; schedule kept. |
| Usage reminders after expiry | **Stop**, like blocks. |
| QA menu | ~~Only outside the real App Store~~ → superseded by v5 #11: manual removal before the App Store build. |
| Mocking | None. The only QA control is "expire trial now", which edits the app's own trial date. |
| Trial length | 7 days in every build. |

## How it works

**Stored facts** (app group, one definition in UnplugCore, read by app and extension):
- `trialStart` — the app's own date, set once at the first block, never moved.
- `downloadDate` + `isProduction` (in `AppleFacts`) — raw values from the latest **verified**
  `AppTransaction`, overwritten by each verified answer. Grandfathering and the cap are derived from
  them every time, never stored as flags (review r2 hole 6).
- `grantingOriginalID` — the verified lifetime purchase that granted access. Cleared only when
  that exact transaction shows a refund (r2 hole 5). Empty answers never clear it.

**Derived (pure functions in UnplugCore, `swift test`):**
- grandfathered = production AND download date < cutover.
- full access = grandfathered OR granting transaction present.
- trial end = earlier of: midnight after start day + 7 full days; production only: midnight after
  download day + 21 days. ~~With no start date but a known production download date, end = that
  ceiling~~ (superseded by v5 #4: end = the last start day) (r2 holes 2, 4).
- first-block decision (superseded by v5 #1: any full access arms, decided from stored facts first): grandfathered → arm; production and past download + 14 days → unlock screen;
  otherwise → confirmation with the trial notice → set `trialStart` → arm.
- extension gate (`AccessPolicy.extensionAppliesBlock`): not expired → apply block (and reminders);
  nothing stored → apply; undecodable facts → apply; a trial start with no facts → the 7-day end applies.

**Who writes:** `AccessController` only, on the main actor.
- **Purchase, restore and the `Transaction.updates` listener** write the verified transaction they
  hold, then `finish()`. They never re-ask StoreKit (r2 hole 1, the postmortem's second cause).
- **Launch and foreground refreshes** ~~run one at a time~~ (superseded by v5 #3: not serialized). They read `Transaction.all` (refunds) and
  `AppTransaction`, and apply whatever succeeded.
- **The first block** calls `AppTransaction.shared` with a 10-second timeout, the button disabled
  while waiting. Unverified, a throw or a timeout means "couldn't reach the App Store".

## Changes (critical files)

- `UnplugCore/Sources/UnplugCore/AccessControl.swift`:
  - stored-facts type and key names (~~a UserDefaults store~~: v5 #9 moves `AppGroupStore` in slice 2);
  - ~~`AccessEvaluator` gains the ceiling~~ → built as `AccessPolicy` over `AppleFacts`; the old
    `AccessEvaluator.accessState`/`trialDaysRemaining` are deleted in slice 2;
  - grandfather derivation with environment;
  - first-block decision;
  - remove unused `EntitlementProviding`;
  - `trialDays = 7`; fix the backwards cutover comment.
  Reuse: `AccessEvaluator.trialEnd`, `Grandfather.isGrandfathered`.
- `ScreenTimeShield/Store.swift`:
  - purchase, restore and the listener return the verified transaction;
  - `Transaction.all` pass for refunds;
  - `AppTransaction` read with environment;
  - delete the empty-answer revoke.
- `ScreenTimeShield/AccessController.swift`:
  - single writer; synchronous init from stored facts (no flash);
  - one arm gate for both buttons;
  - ~~serialized refresh~~ (v5 #3); listener started from `ScreenTimeShieldApp`, never under XCTest;
  - re-apply restrictions after a purchase when inside the block window;
  - delete the QA presets, the ignore switch and `enforcement_allowed`.
- `ScreenTimeShield/ContentView.swift`:
  - `start()` and `restrictForNextHour()` go through the arm gate, and the confirmation always shows on the first block, with the notice;
  - `applySchedule` no longer starts the trial;
  - delete the QA banner;
  - the paused state routes the main button to the unlock screen.
- `ScreenTimeShield/StatusBanner.swift`: "paused — trial ended" state.
- `ScreenTimeShield/ScreenTimeShieldApp.swift`, `ContentView.swift`: remove the `UNPLUG_SKIP_FC` refresh skips.
- `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift`: gate blocks and reminders with the UnplugCore rule.
- `ScreenTimeShield/QAMenuView.swift`, `SettingsView.swift`:
  - ~~QA entry shown only outside production~~ (superseded by v5 #11: manual removal);
  - the menu keeps expire-trial, read-only diagnostics, times-stopped and the checklist.
- `Localizable.xcstrings`: new strings (notice, unreachable, paused) in 10 languages.
- `qa/invariants.md` (F9 rows), `qa/iap-test-checklist.md`, `QAChecklistView.swift`, `status.md` (release checklist: ~~no manual QA revert~~ (v5 #11: manual removal stays); cutover step; release-day check).

## Build order (one commit each, straight to main, pushed)

0. **QA setup:**
   - settle Xcode's uncommitted ⌘U changes: the test plan runs unit tests only;
   - register `StoreKitEdgeTests.swift` in the test target (it isn't compiled today);
   - StoreKit tests fail instead of skip when no products;
   - check that `osascript` can make Xcode run tests and launch the app;
   - check that the one simulator can arm.
1. UnplugCore rules + unit tests.
2. Store + AccessController + SKTestSession tests.
3. Extension gate (blocks and reminders).
4. UI: confirmation notice, paused state, buy-at-night re-apply, QA menu visibility, deletions, strings, docs.
5. Automated QA pass; results in `qa/README.md`.

Before step 1: update `qa/design/trial-iap.md` to these decisions and run one more fresh gate D review.
After each step: quality and hardening reviews, then gate B, per the feature-build process.

## Verification

- **`swift test --package-path UnplugCore`:** every rule with plain values:
  - cap per environment, late start, reinstall can't extend, nil start;
  - grandfathering per environment;
  - refund of the granting id only, empty answer keeps access;
  - first-block outcomes, extension gate, midnight end.
- **App unit tests through Xcode** (osascript, after you allow Automation), `SKTestSession` with its own storage per test:
  - buy, cancel, refund, Ask to Buy, out-of-band purchase, restore;
  - the listener writes the held transaction.
- **Simulator pass on one simulator** (iPhone 17 Pro, app launched by Xcode so `StoreKit.storekit` applies), driven by the simulator MCP:
  - first block shows the notice and arms;
  - the countdown shows;
  - expire trial → paused state;
  - unlock screen, buy, blocks re-apply;
  - restore.
- **TestFlight (you):** one end-to-end run on an Apple ID that has never bought the unlock.
- **Release day (you):** install from the App Store with an Apple ID that bought 1.2 → full access, no countdown. Before that, check whether a promo code on a "Pending Developer Release" build gives a real App Store install, so this can be done before release.

## Needs you

- **Before step 0:** System Settings → Privacy & Security → Automation → allow your terminal to control Xcode. Without it, the StoreKit unit tests and the simulator pass can't run unattended.
- **Before the final build:** the release date, for the cutover.
- **Not done without you:** App Review submission, price change, release settings, TestFlight upload.


---

# v3 (for the criteria and code map)

## UNPLUG-TRIAL: automatic 7-day trial, lifetime unlock, grandfathering — done reliably

*v3, 2026-11-08. Steven picked the trial model "H": no $0 trial purchase; the trial starts at the
first armed block and is capped by Apple's download date. v1/v2 (a $0 "7-day Trial" IAP) are
superseded; gate D round 1 on v1 (`trial-iap-gateD-r1.md`) still applies to the shared parts.*

**Problem:** Unplug 1.3 moves from a $0.99 paid app to a free download with a 7-day trial and a
$4.99 lifetime unlock; earlier buyers keep full access free. The hand-built version keeps breaking:
QA mocks hid real purchases (postmortem `qa/postmortems/2026-10-29-purchase-left-trial-ended.md`),
grandfathering misfires in Apple's test environment (sandbox `originalPurchaseDate` is always
2013-08-01, so every tester and the App Review reviewer is grandfathered and cannot find the IAP),
an empty StoreKit answer revokes a purchase, and expiry only takes effect when the user opens the app.
Every QA run needs manual pin juggling, and 1.3 is blocked. Source: conversation with Steven,
2026-11-04 to 2026-11-08.

**Apple guidance:** the only documented trial pattern for non-subscription apps is the $0 "XX-day
Trial" non-consumable (Guideline 3.1.1, "may"). An automatic trial is allowed but not documented.
The documented building block it uses is `AppTransaction.originalPurchaseDate` (unchanged across
delete/reinstall; used in Apple's "Supporting business model changes" article).

**Acceptance criteria:**
1. **Trial start.** The trial starts automatically, with no agreement step, the first time the user
   arms a block by either "Start blocking" or "Restrict for next hour". The start date is stored once
   and never moved by normal use (invariant F9.1). The chip then shows the days left.
2. **Trial end.** The trial ends at the earlier of:
   - local midnight after the start day plus 7 full days (today's rule);
   - **in the real App Store only**, a ceiling: local midnight after the day of
     `AppTransaction.originalPurchaseDate` plus 14 full days (7-day trial + 7-day grace).
   Deleting and reinstalling restarts the app's own start date but never the ceiling, so it can't
   extend the trial past 14 days from the Apple ID's first download.
3. **No flash.** Once the app has stored any Apple-confirmed fact or a trial start, every launch shows
   the right state immediately from stored values. A user with nothing stored sees no chip until the
   first answer from Apple arrives, instead of a wrong one.
4. **Expiry without opening the app.** After expiry no new block starts, even if the app was never
   opened. A block already running at expiry finishes. With nothing stored at all, blocks apply.
5. **Unlock.** Buying the $4.99 unlock gives full access immediately; it is stored and survives a
   relaunch and an offline launch.
6. **Refunds.** Full access from a purchase is revoked only when Apple explicitly reports the newest
   lifetime purchase as refunded, at launch and while the app runs. An empty or failed StoreKit answer
   never revokes. A refund never removes grandfathered access.
7. **Grandfathering.** In the real App Store (`AppTransaction.environment == .production`), an Apple ID
   whose `originalPurchaseDate` predates the cutover gets full access, stored permanently. In
   TestFlight, sandbox, Xcode and App Review it never grandfathers.
   7b. **First arm needs Apple once.** On the first arm (either button), before starting the trial,
   the app gets `AppTransaction.shared`:
   - grandfathered → arm, no trial;
   - otherwise → store the trial start (now) and, in production, the ceiling → arm;
   - if `AppTransaction` fails (offline, not signed in to the App Store) → the app says it couldn't
     reach the App Store, and doesn't arm.
   A grandfathered buyer never sees a trial. After the first success, starting blocks offline works.
   Blocks armed in 1.2 keep running through the update, even offline.
8. **Offline.** Being offline never grants access Apple hasn't confirmed before. **One named
   exception:** when nothing is stored at all (a 1.2 upgrade, or an app-group container recreated by
   iOS), the extension applies blocks (criterion 4) until the next online refresh stores Apple's facts.
9. **Restore.** Restore Purchases brings back the unlock after a reinstall.
10. **No purchase mocking.** Nothing in the app overrides Apple's answers: no ignore switch, no
    entitlement pins, no QA banner, no `UNPLUG_SKIP_FC` refresh skip. The cutover is the real value in
    every build; the dev 2020 swap is gone. (The QA "expire trial now" button stays: it rewrites only
    the app's own trial start date, never Apple's data. QA builds only.)
11. **Automated QA.** Claude runs, unattended:
    - `swift test` — every access rule as pure functions with plain values (ceiling, grandfathering
      per environment, refunds, merge order, first-arm decision, extension gate);
    - the app unit tests through Xcode (`osascript` tells Xcode to run the scheme's tests; needs the
      macOS Automation permission), using `SKTestSession` against `StoreKit.storekit`: buy, cancel,
      refund, Ask to Buy, out-of-band purchase, restore. In this run a StoreKit test that finds no
      products **fails**; it never skips;
    - a simulator pass through the simulator MCP on an app **launched by Xcode** (`osascript` run), so
      `StoreKit.storekit` applies: first arm starts the trial, chip, expire-trial button → "Trial
      ended", paywall, buy, restore.
    All three pass before anything ships.

**Non-goals:** a $0 trial IAP; subscriptions; third-party SDKs; iOS 17 StoreKit views; price or
store-copy changes; `N5`, `N6`, `V07`, `V11`, `V12`; migrating trial data from dev builds 17–21 (no
customer has any); verifying the production ceiling or grandfathering on a device before release
(Apple returns a fake date outside production; unit tests cover both).

**Code path today:**
- `UnplugCore/Sources/UnplugCore/AccessControl.swift:62-92` — `AccessEvaluator` (trial end at local
  midnight, state, days remaining); `:94` `Grandfather.isGrandfathered`; `:19-45` `PricingConfig`
  (`cutoverDate` dev 2020, `trialDays` dev 1; the comment at `:28-30` calls erring late "the expensive
  direction", which is backwards).
- `ScreenTimeShield/Store.swift:59-68` — `refreshPurchasedState` sets `false` after an empty loop (the
  empty-answer revoke); `:71-82` no environment check; no `Transaction.updates` listener.
- `ScreenTimeShield/AccessController.swift:51` — `accessState` defaults to `.trial` (the flash);
  `startTrialIfNeeded()` writes the local `trial_start` on arm; `:147` writes `enforcement_allowed`;
  `updateTrialEndedNotification()`; QA presets and ignore switch.
- `ScreenTimeShield/ContentView.swift` — two arm paths: `start()` `:86-90` → `performArm()` `:92`;
  `restrictForNextHour()` `:116` → `performRestrictHour()` `:121`; both call `startTrialIfNeeded()`
  (`:93`, `:122`; also `applySchedule` `:71`). Refresh at launch `:270-276`; foreground
  `ScreenTimeShieldApp.swift:96-103`.
- `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:23-60` — raw string keys; reads
  `enforcement_allowed` (missing = allow) at `intervalDidStart`; refocus notifications (`:96`) ungated.
  The target links UnplugCore.
- `qa/invariants.md:62-73` — F9.1 (trial date written once), F9.2 and F9.12 name
  `enforcement_allowed` and the QA overrides.
- Tests: `ScreenTimeShieldTests/StoreTests.swift`, `StoreKitEdgeTests.swift` (SKTestSession; skip
  when no products; V15/V16/V18 written as failing tests). `SKTestSession` can't save its settings
  under command-line `xcodebuild` (SKInternalErrorDomain Code=3); it works when Xcode runs the tests.

**Reuse found:**
- `AccessEvaluator.trialEnd` — the midnight maths serves both the 7-day end and the 14-day ceiling.
  ~~`accessState` / `trialDaysRemaining` reused; extension gate = `accessState(...) != .expired`~~ →
  superseded: `AccessPolicy` and `AccessPolicy.extensionAppliesBlock` (v4/v5 build).
- ~~`startTrialIfNeeded()` / `trial_start`~~ → superseded by v5 #12: new key `trial_started_at`.
- `Grandfather.isGrandfathered` — keep; the environment check sits in front of it.
- `Store.purchase / restore / loadProduct` — unchanged product.
- `KeyValueStore` protocol (`AccessControl.swift:53`) / `AppGroupStore` — storage, injectable in tests.
- `updateTrialEndedNotification` — keep; it reads the capped end.
- `PaywallView`, `TrialChip`, the existing arm flow and alert.
- `StoreKitEdgeTests` V15/V16 — tests for the listener.

**Volume:** none. On-device state only.

**External APIs (StoreKit 2, iOS 16+):** `Product.purchase()`, `Transaction.all` (one pass: lifetime
owned / newest id / refunded), `Transaction.updates`, `AppTransaction.shared` (`environment`,
`originalPurchaseDate`; throws when unavailable or signed out; does not prompt — only `refresh()`
prompts, which the app never calls), `AppStore.sync()` (Restore only).

**Unknowns / [UNVERIFIED] claims:**
- [UNVERIFIED] `osascript` can make Xcode run the tests and launch the app unattended (Xcode's
  scripting dictionary has `run` and `test`). Verify in slice 0.
- [UNVERIFIED] `AppTransaction.shared` answers from a cache after the first success. Not relied on:
  the first success stores what's needed.
- [UNVERIFIED] App Review accepts an automatic, non-IAP trial (3.1.1 says "may"; many apps ship one).
  Review notes explain it.

**Open product questions:**
1. `V19` (expired but still looks armed): in scope or follow-up?
2. `trialDays` 7 in every build?
3. **Cutover:** release day **plus 14 days** (a late cutover only grandfathers a few free downloaders;
   a slip of under 2 weeks then needs no rebuild)? Needs the planned release date.
4. **`V21`** (buy after expiry mid-window: blocks don't come back until the next window): in scope or
   follow-up? Earlier decision was "fix".
5. **Refocus notifications after expiry:** gate them with the same rule as blocks?
6. **A user Apple can't answer for** (signed out of the App Store) can't make a first arm until they
   sign in. Accept, with the message?

**Options:**

### Option H — automatic trial, Apple-capped (picked model; recommended form)
Changes:
- **UnplugCore (pure, `swift test`):**
  - `StoredAccess` — stored facts: `purchased`, `grandfathered`, `trialStart: Date?` (the app's own,
    set once), `trialCeiling: Date?` (production only, from Apple), `newestLifetimeTransactionID`.
    Key names and read/write live here, shared by app and extension.
  - `StoreKitSnapshot` — plain values from Apple: lifetime transactions (id, revocation date);
    `AppTransaction` result (environment, `originalPurchaseDate`) or failure.
  - `StoredAccess.merged(with:cutover:)` — the only merge rule: grandfathered = stored OR (production
    AND date < cutover), never cleared; ceiling = from the production `originalPurchaseDate`, earliest
    wins, never cleared; purchased = true if any unrevoked lifetime transaction, false only if the
    newest lifetime transaction is revoked AND its id ≥ the stored newest id; an empty snapshot
    changes nothing; `trialStart` is never touched by a merge.
  - `FirstArm.decide(stored:, snapshot:) -> .arm | .startTrialThenArm | .unreachable`.
  - `AccessEvaluator` gains an optional `ceiling`: end = min(7-day end, ceiling). The extension gate
    is `accessState(...) != .expired` from `StoredAccess`.
- **Store (glue):** `snapshot()` (one `Transaction.all` pass + `AppTransaction.shared`);
  `purchase()`; `restore()`; `listenForUpdates()` → per verified transaction: snapshot, merge, apply,
  then `finish()`.
- **AccessController:** single writer of `StoredAccess`; `apply(snapshot)` re-reads and merges on the
  main actor (the id rule makes it order-independent). `init` reads `StoredAccess` synchronously → no
  flash. One arm gate `requestArm(.schedule | .hour)` for both buttons: if a trial start or an
  entitlement is stored → today's flow; else snapshot → `FirstArm.decide` → arm / store trial start
  then arm / "couldn't reach the App Store" toast. `KeyValueStore` injected; listener started from
  `ScreenTimeShieldApp`, never under XCTest. The QA "expire trial now" button sets `trialStart` back.
- **Extension:** read `StoredAccess`; gate as above.
- **UI:** chip hidden while nothing is stored and the first refresh hasn't finished; delete QA ignore
  switch, other trial presets, banner, `UNPLUG_SKIP_FC` refresh skip, dev cutover swap; reword the
  cutover comment. One new string ("Couldn't reach the App Store…") in 10 languages.
- **Tests:** UnplugCore unit tests for every rule (ceiling per environment, reinstall can't extend,
  grandfather never cleared, refund id race, empty snapshot, each `FirstArm` outcome, gate). SKTestSession
  tests for the glue with a per-test `UserDefaults` suite; "no products" fails; V18 test deleted (rule
  moves to UnplugCore). Scheme Test action: unit tests only. `qa/invariants.md` F9.1/F9.2/F9.8/F9.12
  rewritten.

Criterion mapping: 1 → `requestArm` + stored start; 2 → `trialEnd` + ceiling; 3 → synchronous init +
hidden chip; 4 → extension gate; 5, 6 → purchased rule + listener; 7, 7b → grandfather rule +
`FirstArm`; 8 → only Apple facts are stored, plus the named exception; 9 → `AppStore.sync` + snapshot;
10 → deletions; 11 → the three layers.

New moving parts: the `Transaction.updates` task (criterion 6 while running); the stored facts
(criteria 3, 4, 5, 7). Nothing else.

Risk and rollout: ships as 1.3. No new IAP. Rollback is a new build. Dev-build keys
(`enforcement_allowed`, `qa_*`, `trial_start`) are never read (v5 #12: the trial start moved to
`trial_started_at`).

Pre-mortem:
- Signed out of the App Store → first arm blocked with a message; 1.2 blocks already armed keep
  running (criterion 8 exception).
- Container recreated by iOS → nothing stored → blocks apply → next online refresh restores
  grandfathered/purchased and the ceiling; the trial start restarts but the ceiling caps it.
- Re-buy during a refresh that saw the old refund → id rule keeps `purchased`.
- A reinstall inside the 14-day window gives a fresh start capped at the ceiling: at most the grace,
  accepted.
- Clock changes → V23 (accepted won't-fix) still applies.
- Reviewer can't find the IAP → environment rule means the reviewer gets a normal trial and paywall;
  review notes say how to reach it.

### Option D — trial from download (not picked)
In production the trial runs from `originalPurchaseDate`; outside production the app's first-arm
date. Same code size as H (both need the local clock for test environments); starts the clock before
the user has set anything up.

**Recommendation:** H. Gate D: pending (fresh review of v3).

**Picked:** H (trial model), 2026-11-08. Implementation form pending gate D.

**Slices (commits to main, in order):**
0. QA setup: verify `osascript` can make Xcode run tests and launch the app; scheme Test action runs
   unit tests only; StoreKit tests fail instead of skip when no products. (Needs the Automation
   permission.)
1. UnplugCore: `StoredAccess`, `StoreKitSnapshot`, merge, ceiling, `FirstArm`, key names; tests.
2. Store + AccessController: snapshot, listener, apply, synchronous init, arm gate; SKTestSession tests.
3. Extension: `StoredAccess` gate.
4. UI + deletions + string + cutover comment + invariants + QA checklist.
5. Automated QA pass; results in `qa/README.md`.

**Slice 2 must also:** delete `AccessEvaluator.accessState` / `trialDaysRemaining` (keep `trialEnd`)
and port their tests (AccessControlTests trial cases, PricingBoundaryTests V23) to `AccessPolicy`, so
the compiler finds every old caller; re-read stored facts after every `await` before merging; on an
undecodable stored value keep the last known access, never demote.

**Follow-ups:** `V19` and `V21` unless taken into scope; `V20` closes with slice 3; `V23` stays
won't-fix.

**Known limits:**
- A device clock that stays set back revives an expired trial (V23, accepted won't-fix). Trigger: the
  user turns off automatic time and backdates the clock. Likelihood: low (deliberate effort for $4.99).
  Consequence: free use while the clock stays wrong. The download-date ceiling does **not** help: it is
  compared against the same backdated clock.
- Travel moves the trial end and the last start day, because both are local midnights recomputed in
  the current zone: the shift is the zone offset plus or minus up to a day. Likelihood: common for
  travellers. Consequence: the trial ends up to about a day earlier or later; near the last start day,
  travel can turn a trial start into the unlock screen or the reverse.
- A refresh that read `Transaction.all` before a refund can re-grant once. Trigger: a refund lands
  during a refresh. Likelihood: very low. Consequence: access until the next refresh.
- If `Transaction.all` ever lists a refunded purchase twice (revoked and not), access is kept.
  Likelihood: unknown; the slice 2 SKTestSession refund test shows the real shape. Consequence: a
  refunded user keeps access (lost revenue, no user harm).
- Corrupt stored facts: the extension applies blocks; the app keeps the last known access (slice 2).
  Likelihood: very low. Consequence: possibly a longer trial, never a lost purchase.
- The 2020 cutover placeholder is guarded only by release checklist step 2. The V22 tests do **not**
  guard it: they are marked expected-failure, so `swift test` stays green while the placeholder is in.
  Trigger: the final build is prepared without setting it. Likelihood: medium — this constant went
  stale twice before (`da16e73`, `af84448`). Consequence: every 1.2 buyer
  is treated as new and asked to pay. A late placeholder was considered and rejected: if it shipped,
  every new user would be grandfathered.
- [UNVERIFIED] App Store account switch on the device: `withAppTransaction` replaces the download date
  with each answer, while the granting purchase stays stored. If `AppTransaction.shared` follows the new
  account, grandfathering follows it too, and a purchase made on the old account stays on the device.
  Likelihood: low (shared or family devices). Consequence: access follows the device, not the account,
  until a refresh reads the new account's purchase history.
- A reinstall inside the 14-day start window clears the trial start and gives a fresh trial, capped
  at download + 21 days in production (unlimited outside production). Likelihood: low (deliberate).
  Consequence: up to about 3 weeks free instead of 1. Accepted with the cap decision.
