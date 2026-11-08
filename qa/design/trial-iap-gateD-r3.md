# Gate D, review of v4 — verdict SHAKY (2026-11-08, round 3 = cap)

1. First-block decision leaves out purchasers (bought, never armed): unlock screen / trial notice /
   "can't reach" after paying. Check stored full access first, before any Apple call.
2. Paused state can drop the schedule: edits while armed-inactive call stop(). Lock schedule edits
   while expired; an active block wins over "paused" on banner and button.
3. Serialized refreshes + no timeout on refresh: one hang stalls every later refresh (incl. refund pass
   and the Screen Time re-read). Drop serialization (writes are idempotent) or time out refresh too.
4. Task-group timeout waits for a non-cancellable child; use an unstructured Task + one-shot continuation.
5. Nil start between download+14 and +21: screen says "trial, 7 days left" but arming is refused. For a
   nil start, end = last day a trial can start (same boundary as the first-block rule); chip and
   notification use the capped end.
6. App Review runs in `sandbox`, like TestFlight, so "QA menu only outside production" shows it to the
   reviewer (2.1/2.2 risk). Also undefined when nothing is stored.
7. Hidden-chip rule (no flash) missing from the v4 change list.
8. Buy-at-night re-apply belongs in ContentView: `onChange(accessState)` leaving `.expired` →
   existing `applySchedule()` (covers purchase, restore, listener, refresh; extension stays the single
   writer of inside_interval).
9. First block calls Apple even when a verified answer is stored; decide from stored facts first.
10. Whether a refresh grants access is undefined; revoked non-consumables in `Transaction.all` are
    undocumented — prove with an SKTestSession refund test; listener clears only on the granting id.
11. Separate keys can be read half-updated by the extension; store Apple facts as one Codable value.
12. V16 and V18 skips remain; delete V18, turn skips into failures; TestFlight run starts from a deleted app.
Risk under a settled decision: the reviewer can't arm if `AppTransaction` fails in the sandbox.
Scope cuts: move AppGroupStore into UnplugCore instead of a new store; drop serialized refreshes;
re-apply via onChange + applySchedule; one Codable value instead of separate keys.
