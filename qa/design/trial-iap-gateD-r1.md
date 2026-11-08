# Gate D, round 1 — verdict SHAKY (2026-11-08)

Fresh-context adversarial review of `trial-iap.md` (v1). Holes, condensed:

1. Trial date used `Transaction.purchaseDate` (can be the restore date) → new device can restart the
   trial. Use `originalPurchaseDate`, earliest wins, never cleared (agrees with invariant F9.1).
2. `Transaction.all` doesn't throw: empty means both "new user" and "offline/unsynced". 7b needs an
   explicit reachability probe (products load), and "trial product missing" as its own error.
3. "Restrict for next hour" (`ContentView.swift:116-128`) is a second arm path the doc ignored.
4. The "Start blocking?" alert only shows when `isRiskyToArm()` (`ContentView.swift:89`); the
   disclosure needs "unclaimed OR risky", merged copy, on both alert variants.
5. V18 test becomes a permanent silent skip once grandfathering is production-only.
6. Criterion 11 can be green with nothing exercised: SKTestSession tests `XCTSkipIf(products.isEmpty)`;
   no mechanism for Claude to run ⌘U; a simctl launch gets no StoreKit config.
7. Test isolation: stored verdict outlives `clearTransactions()`; listener in the test host finishes
   the tests' transactions. Inject a per-test KeyValueStore; no listener under XCTest.
8. (a) refund must clear only "purchased", never "grandfathered"; (b) stale refund snapshot across an
   `await` can overwrite a fresh re-buy; (c) key names/strings duplicated across processes; (d) the
   merge rules are pure but placed in AccessController — move to UnplugCore.
9. One always-failing input locks out every new user: $0 product missing in production, App Store
   signed out (`AppTransaction.shared` throws), a 1.2 buyer who edits the schedule can't re-arm.
10. V21 (buying mid-block re-applies nothing until tomorrow) silently dropped.
11. Criteria 4 and 8 conflict ("nothing stored → allow"); name the exception.
12. Cutover tied to an unknown release date; use a generous margin; fix the inverted comment at
    `AccessControl.swift:28-30`.
13. Refocus notifications ungated after expiry; invariants F9.2/F9.12 must be rewritten; criterion 3
    holds only once facts are stored; TestFlight can't show trial/expired screens after a claim.

Scope cuts proposed: `EnforcementGate` = existing `accessState(...) != .expired`; derive owned /
refunded / trial date from one `Transaction.all` pass; `.notStarted` case optional; and an unweighed
smaller option: anchor the trial to `AppTransaction.originalPurchaseDate` (no new IAP).

Confirmed: old code paths as described; extension can compute expiry from stored Apple dates;
running block finishes; environment gating covers TestFlight/App Review/Xcode; container wipe
self-corrects; listener semantics; `AppTransaction.shared` doesn't prompt (only `refresh()` does);
back-dating via `SKTestSession` exists (iOS 17+); dev-build keys are inert.
