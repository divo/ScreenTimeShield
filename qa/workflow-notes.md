# Workflow notes — did the QA flow actually work?

A record of how the bug-finding process performed, kept separately from its output so the *method*
can be improved next time. The findings are in `qa/findings.md`; this file is about whether we
should trust them and whether the flow earned its cost.

## Design

Fanned out by **bug class**, not by feature — the shape Anthropic's own Code Review uses ("each
agent looks for a different class of issue, then a verification step checks candidates against
actual code behavior to filter out false positives"). The unit of work was a (feature × lens) cell.
Three stages, each a separate workflow so there was a human checkpoint between them:

| Stage | Agents | Output |
|---|---|---|
| W1 discover | 10 | 41 raw candidates |
| W2 verify | 39 | 19 confirmed, 3 uncertain, 1 refuted |
| W3 prove + critique | 7 | failing tests, coverage gaps, device matrix |

Total ≈ 56 agents, ~4.5M subagent tokens.

## The recall canary

Before any agent ran, 14 suspicious spots were noted by one careful human-style read of the
codebase and stored **outside the repo** (`scratchpad/canary.md`) so discovery ran blind. This is
the honest test of whether a 10-agent sweep beats one attentive reader.

| Canary | Sweep result | Verdict |
|---|---|---|
| C1 selection edit mid-block strands `inside_interval` | Found → **V08** | **REFUTED by verification.** The canary was wrong, or at least unproven |
| C2 `stop()` never stops `.hourly` | Found, as part of **V07** | Sweep found a *worse* mechanism than the canary described (see below) |
| C3 `dateAtMinute(1440)` → `?? Date()` | Found by **2 independent cells** → V01 | Confirmed |
| C4 24:00 → 00:00 collapse in `components(from:)` | Folded into V01 / V05 | Partial |
| C5 hardcoded `%02d:00` axis vs locale pills | Found → F3-TIME-03 | Nit, not verified this round |
| C6 drag-tick write / XPC storm | **Examined and correctly ruled out** — `disarmIfArmedInactive()` is idempotent, so only the first tick does work | **The canary was wrong and an agent caught it** |
| C7 sync `activities` read on main thread | Found → **V12** | Uncertain |
| C8 swallowed `startMonitoring` error | Not re-reported — already an open item in `status.md`, and agents were instructed not to re-report known bugs | Correctly suppressed |
| C9 no `Transaction.updates` listener | Found → **V15** | Confirmed |
| C10 `.pending` collapsed to `false` | Found → **V16** | Confirmed |
| C11 trial reset by reinstall | Found → **V25** | Uncertain |
| C12 grandfather demoted when offline | Found by **3 independent cells** → V18 | Confirmed |
| C13 expiry never stops the `.daily` schedule | Found → **V19** | Confirmed |
| C14 risk confirm can be stale by the time the alert is accepted | **Not reported** | Genuine miss |

**Recall: 12 of 14 canary items accounted for.** One canary item (C6) was itself wrong and the
sweep disproved it. One (C14) is a genuine miss — a real, if minor, gap in the lens set.

### What matters more than the recall number

The sweep found **14 confirmed or uncertain findings that were not on the canary at all**: V04, V05,
V06, V07 (new mechanism), V09, V11, V13, V14, V17, V20, V21, V22, V23, V24. The fan-out roughly
doubled the yield of one careful reader, and the two highest-consequence findings were both
sweep-only:

- **V07** — the canary guessed `stop()` forgetting `.hourly`. The sweep found something worse: the
  monitor extension's `intervalDidEnd` treats `daily` and `hourly` identically, so a one-hour quick
  block **ending** clears the shields of a concurrently active nightly block. Three cells reached
  this independently through different lenses.
- **V22** — `PricingConfig.cutoverDate` sitting a month in the past while the IAP build is
  unshipped, so anyone who paid $0.99 since 2026-06-25 will be asked to pay again. A pure
  release-sequencing bug that no amount of code-smell reading would surface; it needed someone to
  compare a constant against the calendar.

## Be skeptical of the 4% refutation rate

Only 1 of 23 clusters was refuted. That is the weakest number in this pass and it has two readings:

1. **The evidence bar worked.** W1 required a concrete failure trace before a candidate could be
   reported at all, so speculation was filtered before it reached verification. Supporting evidence:
   6 of 16 second opinions **disagreed** with the first verifier, so verifiers demonstrably were
   willing to contradict each other rather than rubber-stamp. Most disagreements downgraded an
   over-claimed frequency or split a finding into a common half and a rare half — exactly the
   correction a real skeptic makes.
2. **The verifiers were too agreeable.** Possible, and not ruled out by anything in this pass.

Anthropic's own guidance is explicit that "a reviewer prompted to find gaps will usually report
some, even when the work is sound." The mitigation used here was the evidence bar plus a
requirement to verify Apple API semantics against Apple's docs; one verifier went further and
*executed* `Calendar.date(bySettingHour: 24, ...)` in four time zones to confirm it returns nil.
That is the standard the whole pass should be held to.

**The remaining check is human:** spot-check three findings by reading the cited code. If any cannot
be reproduced from the trace, the bar was too low and W2 should be re-run with a stricter prompt.

## What the flow cannot see

Structural, not fixable by more agents:

- **Enforcement is unobservable off-device.** The simulator cannot authorize Family Controls, so
  every finding about shields actually appearing, `intervalDidStart/End` firing, and real app tokens
  is `needs-device`. Hence `qa/device-matrix.md`.
- **Feature 4 has almost no testable surface.** Its state machine lives in `ContentView.swift` view
  methods and its effects go through `DeviceActivityCenter`. No F4 finding could be proven by a unit
  test without first extracting a pure reducer. This was called out in the plan and remains true.
- **Three findings turn on undocumented Apple behaviour** (V12, V13, V25) and are marked UNCERTAIN
  rather than guessed at. The device matrix is designed to settle them.

## Lens performance

| Lens | Raw | Verdict quality |
|---|---|---|
| f9-datemath | 7 | Best yield: V18, V19, V22 all confirmed |
| f9-integrity | 6 | Strong: V20, V23, V24 confirmed |
| f3-time | 5 | V01, V02 confirmed; 3 nits |
| f9-storekit | 5 | V15, V16 confirmed |
| f4-statemachine | 4 | Found V07 |
| f4-crossprocess | 4 | Converged on V07/V11 independently |
| f4-hostile | 3 | Found V07 by a third route + V13, V14 |
| f3-mapping | 3 | V04 confirmed; found the same 24:00 bug as f3-time |
| f3-mode | 2 | V05 confirmed |
| f4-concurrency | 2 | Weakest — its two findings became V11 (dup) and V12 (uncertain) |

**Next time:** the three-way convergence on V07 and the duplicate 24:00 discovery show the lens set
overlaps more than intended for F4 — four F4 lenses produced substantial duplication. Three would
likely do. Add a lens for *confirmation-dialog and alert staleness* (would have caught C14). The
`f9-*` lenses were the highest-value cells and deserved the deepest budget, which they got.

## Verification of the flow's own claims

| Check | Result |
|---|---|
| `cd UnplugCore && swift test` | **At the end of the QA pass: 46 tests, 20 failures** — the proofs. Pre-existing suites untouched: `AccessControlTests` 18/18 pass, `ScheduleMathTests` 6/6 pass. New: `ScheduleMathBoundaryTests` 9 of 10 red, `PricingBoundaryTests` 11 of 12 red. **As of 2026-08-02, after the fix pass: 58 tests, 0 failures** |
| App still builds | `** BUILD SUCCEEDED **` |
| Production code untouched | `git status` shows only 3 new test files + 5 `qa/` docs. Zero production files modified |

One correction to the approved plan: its build command named `platform=iOS Simulator,name=iPhone 16`,
which does not exist on this machine (it has iPhone 16e, 17, 17 Pro, 17 Pro Max, Air). The first run
printed the destination list and **still exited 0**, which looks like a pass at a glance — worth
knowing, since an exit code alone would have wrongly certified the build. Verified against
`iPhone 17 Pro` instead.

## The two test-wiring gaps that nearly made this pass worthless

Found by the F9 completeness critic, and the most important process finding here:

1. **`UnplugCoreTests` is in no scheme's TestAction.** `ScreenTimeShield.xcscheme` lists only
   `ScreenTimeShieldTests` and `ScreenTimeShieldUITests`, so `xcodebuild test` and ⌘U **never run**
   the 20 red assertions written above. They only run via `swift test`. Any fix pass that trusts
   ⌘U will believe the bugs are fixed without ever executing their proofs.

   **Mitigated, not solved (`483675d`).** Adding a `TestableReference` for the package test target
   was tried first and Xcode rejects it — "UnplugCoreTests isn't a member of the specified test plan
   or scheme" — so ⌘U still silently skips these tests. What exists instead is a `fastlane test` lane
   running both suites, and a warning in `CLAUDE.md`. The hazard is documented rather than removed.
2. **`ScreenTimeShieldTests/StoreKitEdgeTests.swift` is not registered in `project.pbxproj`.** Still
   true as of 2026-08-02; scheduled to be done with the `V15`/`V16` fix. It is
   written and self-consistent, but not compiled, so V15/V16/V18 currently have **no executed
   proof**. Registration steps are in the W3 transcript; briefly: add the file to the
   `ScreenTimeShieldTests` target's Compile Sources, confirm `StoreKit.storekit` is still in Copy
   Bundle Resources, boot a simulator, then run the file. Expected on today's code: 4 failures.
   Deliberately not done here — editing `project.pbxproj` is project configuration, outside this
   pass's read-only-production boundary, and it cannot be verified without a simulator run.

## Round 2 backlog — surfaced by the completeness critics, NOT verified

**Status 2026-08-02: `R1` is fixed** (in `e508014`, alongside `V02`) — and it earned its place here,
because moving the schedule to minutes-of-day made midnight representable, which is exactly the
condition that turned `R1` from theoretical into reachable. The other nine remain unverified leads.
`R3` in particular is still the most promising explanation for the undocumented notifications bug in
`status.md`.

The three critics reported **28 coverage gaps**. These are the substantive ones: each is a specific
untraced path, none has been through refutation, and none should be treated as a confirmed bug.

| # | Where | Why it matters |
|---|---|---|
| R1 | `ScheduleRangeSlider.swift:134` — start-handle clamp `min(m, minutes(of: end) - minGap)` underflows when `end` is near midnight, clamping start to 0 | Yields `start == end == 00:00`, a degenerate interval handed straight to `DeviceActivitySchedule` — the exact case invariant F3.7 forbids. **All three F3 lenses unanimously ruled F3.3 safe using the same argument, and this is the boundary where that argument fails.** Unanimity read as strong evidence and was wrong |
| R2 | `performRestrictHour()` `ContentView.swift:105-110` computes `oneHourLater` as an absolute `Date`, which `Schedule.components(from:)` then reduces to bare hour/minute | The app's most-used action. If it can fail to register (e.g. wrapping past midnight), the user confirms an alert promising "can't be stopped" and gets no block at all — silent and total |
| R3 | `Schedule.setNotificationSchedule` `Schedule.swift:43-60` never validates its own interval length, and `startMonitoring`'s throw is swallowed at `:56-58` | Refocus notifications would silently never register for any user whose block leaves under 15 free minutes. The critic flags this as **a concrete candidate mechanism for the undocumented "Notifications bug"** open in `status.md` |
| R4 | `StopDebouncer.shouldCount` `AccessControl.swift:89-92` | Same unbounded signed clock-comparison shape as confirmed V23, on the counter behind the paywall's primary conversion claim ("Unplug stopped you N times") |
| R5 | `Store.refreshPurchasedState()` `Store.swift:59-66` sets `isPurchased = false` unconditionally after an empty entitlements loop | Structurally identical to confirmed V18 (fail-to-false → `.expired` → `enforcement_allowed = false`) but for the cohort that actually **paid** |
| R6 | `AccessController.updateTrialEndedNotification()` `:126-143` — three untraced branches | The only channel that tells an expired user their blocks stopped; both V19's and V20's traces assume the user is uninformed |
| R7 | `qaExpireTrial()` `AccessController.swift:162-166` leaves a backdated `trial_start` that nothing in the shipping app can clear | Same unclearable-QA-value mechanism as V24 but in the harmful direction, since `startTrialIfNeeded()` no-ops once the key is set |
| R8 | F9.8 (revocation) has no finding and no test; separately, `startTrialIfNeeded()` is only called from the three arm paths | A user who buys from the TrialChip without ever arming never gets a `trial_start` |
| R9 | Clock-**forward** escape for F4.13, deliberately deferred by the hostile lens | Asymmetric with confirmed V23 (clock-backward revives a trial): the pass already established this app trusts an attacker-controlled clock, so the forward direction deserves the same scrutiny |
| R10 | `ContentView.swift:248` is an unconditional **write** of `isArmed` from the daemon's activity list | The app's only reconciliation point for F4.1. If the daemon returns empty before authorization settles or after a reboot, it silently disarms the user |

Also worth noting: the F9 critic reported `qa/device-matrix.md` as missing. It ran concurrently with
the agent writing that file — a timing artefact of the workflow, not a real gap. The file exists.

## Honest limits of this pass

- **Feature 4 has no executed proof at all.** Every F4 finding is reasoned-or-device, because its
  state machine lives in `ContentView.swift` view methods and its effects go through
  `DeviceActivityCenter`. The F4 critic's blunt verdict: detection was good, disposition is the
  weakest of the three features. Closing it needs a pure `ArmState` reducer extracted into
  `UnplugCore` — a fix-pass decision, not something done silently here.
- **V01 and V04 — two 🔴 F3 findings, one of them "always" — have no test either**, and the critic
  notes the natural V01 fix (changing the `dateAtMinute` clamp ceiling) would leave them
  unregressable. They need the slider's minute↔pixel mapping extracted into `UnplugCore`.
- **Invariant F9.11 is now known to be mis-worded.** V19's verifier established the defect is not
  really "expiry lands mid-block"; anyone fixing F9.11 from the invariant text alone would write an
  unnecessary mid-block guard. See the note on that invariant.
