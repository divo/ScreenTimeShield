# Candidates — raw W1 discovery output

Unverified output of the blind discovery sweep: 10 (feature × lens) agents, no seed list, no
cross-talk. **Nothing here is confirmed.** Kept verbatim so W2's refutation rate is auditable
and so the panel judges what was actually claimed rather than a summary of it.

Expect a meaningful fraction to be refuted — that is the design working, not a failure. See
`qa/findings.md` for the verified set.

**41 raw candidates across 10 cells.**

| Cell | Lens | Raw | Important | Nit |
|---|---|---|---|---|
| `f3-time` | F3:time-calendar | 5 | 2 | 3 |
| `f3-mapping` | F3:interaction-mapping | 3 | 2 | 1 |
| `f3-mode` | F3:mode-inversion | 2 | 2 | 0 |
| `f4-statemachine` | F4:state-machine | 4 | 3 | 1 |
| `f4-concurrency` | F4:concurrency-ordering | 2 | 2 | 0 |
| `f4-crossprocess` | F4:cross-process | 4 | 3 | 1 |
| `f4-hostile` | F4:hostile-user | 3 | 3 | 0 |
| `f9-storekit` | F9:storekit | 5 | 4 | 1 |
| `f9-datemath` | F9:trial-grandfather-math | 7 | 5 | 2 |
| `f9-integrity` | F9:gate-integrity | 6 | 5 | 1 |

---

## F3 · F3:time-calendar

### `F3-TIME-01` — Dragging the end handle to 24:00 silently sets the end time to "now" (Calendar returns nil for hour 24, `?? Date()` fallback fires)

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F3.4 · **Needs device** no
- **Anchor** `ScreenTimeShield/ScheduleRangeSlider.swift:41`

**Mechanism**

`minute(forX:)` clamps to `totalMinutes` = 1440 (`ScheduleRangeSlider.swift:51`), and the axis explicitly renders a `24:00` tick at the right end (`:158-160`), so minute 1440 is a reachable, advertised value. The end-handle drag then calls `dateAtMinute(max(m, minutes(of: start) + minGap))` (`:136`). `dateAtMinute(1440)` computes `bySettingHour: 1440/60 = 24` (`:41`). Hour 24 is outside the Gregorian valid range, so `Calendar.date(bySettingHour:...)` returns nil and the `?? Date()` fallback substitutes the current instant. Three further invariants fall out of that one substitution: (a) the `minGap` floor is computed on the *minute* value and then discarded, so the resulting window can be shorter than 15 min or zero-length (F3.3, F3.7); (b) if `now < start`, `end < start`, and `Model.blockedInterval` (`Model.swift:36-38`) hands (start, end) straight to `DeviceActivitySchedule`, which per the comment at `Model.swift:34-35` treats start > end as wrapping midnight — a ~19–24 h block; (c) `fillBar(from: startX, to: endX)` uses `max(0, x1 - x0)` (`:101`), so that inverted window is drawn as *no fill at all* (F3.5).

**Failure trace**

Timezone Europe/Dublin, wall clock 10:04. User sets start = 15:00 and drags the end handle to the far right of the track, intending 24:00 (the axis label says 24:00). onChanged: `minute(forX:)` -> 1440 -> `dateAtMinute(1440)` -> `bySettingHour: 24` -> nil -> `Date()` = today 10:04:37. `model.end` didSet persists that instant (`Model.swift:51`). The end pill now reads "10:04" and the handle jumps to the left of the start handle; the gradient fill disappears entirely (width `max(0, endX-startX)` = 0) so the card shows an empty track. `blockedInterval` = (start: 15:00, end: 10:04); `freeMinutes(windowStart: 900, windowEnd: 604, blockOutsideWindow: false)` = 1440 - max(0, -296) = 1440, so `isRiskyToArm()` only trips via `windowContains(now: 604, start: 900, end: 604)` -> wrapping branch -> `604 >= 900 || 604 < 604` -> false. So no confirmation is shown at all. User taps "Start blocking" -> `Schedule.setSchedule(start: 15:00, end: 10:04)` -> DateComponents(hour:15) / DateComponents(hour:10) -> the system registers a wrapping interval and at 15:00 `intervalDidStart` sets `insideInterval = true`; the block runs until 10:04 the next morning (19 hours) and cannot be stopped (`primaryDisabled` on `insideInterval`, ContentView.swift:45). A same-minute variant (start 09:00, drag end at 09:00:30) yields end == start, i.e. `intervalStart == intervalEnd` handed to the system — the degenerate case F3.7 forbids.

**User impact**

The end handle cannot be set to midnight at all: it silently snaps to the current time. In the worst case the user is locked into a ~19-hour block they never configured, with a slider that shows an empty (apparently unset) window and with no risk confirmation shown.

**API semantics relied on**

Relied on: `Calendar.date(bySettingHour:minute:second:of:...)` returns nil for hour = 24. Verified against the swift-foundation implementation (Sources/FoundationEssentials/Calendar/Calendar.swift — no range check locally; it forwards DateComponents(hour:24) to `nextDate(after:matching:)`) and Calendar_Enumerate.swift, whose `_validate(for:)` rejects component values outside `validRange(for:)` and whose search otherwise gives up after 100 iterations and returns nil. Hedge: if a given OS instead normalised hour 24 to the next midnight, the bug does not go away — `end` would then read 00:00, `minutes(of: end)` = 0, the end handle would render at the left edge, and the next start-handle drag would compute `min(m, 0 - 15)` -> clamped to 0, producing start == end == 00:00 (still F3.3/F3.7). Also relied on: `DeviceActivitySchedule` with intervalStart > intervalEnd wraps midnight — this is the repo's own documented assumption (Model.swift:34-35), not independently confirmed from Apple docs.

### `F3-TIME-02` — Schedule window is persisted as an absolute Date but read as hour/minute in the current zone, so it silently shifts by one hour at every DST transition (and by the full offset on travel)

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F3.10 · **Needs device** no
- **Anchor** `ScreenTimeShield/Model.swift:41`

**Mechanism**

`start`/`end` are stored in the app group as absolute `Date` instants (`Model.swift:41-53`), created by `dateAtMinute` from *today's* date (`ScheduleRangeSlider.swift:41`). Every consumer then re-derives wall-clock fields from that instant with `Calendar.current`, i.e. the device's *current* UTC offset: `ScheduleRangeSlider.minutes(of:)` (`:34-37`) for the handle positions and pills, `Schedule.components(from:)` (`Schedule.swift:69-71`) for what is registered with `DeviceActivityCenter`, `ContentView.minutesOfDay` (`:114-117`) for the risk check, and `AccessController.updateTrialEndedNotification` (`:139`). Nothing ever re-normalises the stored instants (grep: the only writers are the two slider drags and `qaResetToFreshInstall` at `AccessController.swift:195-196`). So the moment the device's UTC offset changes, the same stored instant decodes to a different hour: (current offset − offset at creation). Because a repeating schedule already registered with the system carries bare hour/minute components, the enforced block keeps its original wall-clock hour while the app's displayed and re-registered window drifts — the two diverge. Aggravating variant: `start` and `end` are written by separate drags on separate days, so if they were last edited in different DST regimes the drift differs per handle, changing the window *length* by an hour and — for a window shorter than the offset delta — inverting it (end < start), which `freeMinutes` scores as `max(0, negative)` = 0 length -> "1440 free minutes" -> no risk confirmation, plus the same zero-width fill as the 24:00 bug.

**Failure trace**

Europe/Dublin. On 2026-07-25 (UTC+1) the user drags the window to 09:00–17:00; `dateAtMinute(540)` stores 2026-07-25T08:00Z, `dateAtMinute(1020)` stores 2026-07-25T16:00Z. They arm; `Schedule.setSchedule` registers DateComponents(hour: 9) / (hour: 17). On 2026-10-25 the clocks go back to UTC+0. Cold launch on 2026-10-26: `Model.start` decodes 2026-07-25T08:00Z, `minutes(of:)` under UTC+0 -> 480, so the slider now draws the handles at 08:00 and 16:00 and the pills read "08:00"/"16:00" — an hour earlier than the user ever chose — while the still-registered daily activity fires at 09:00/17:00. The user then adds one app: `onChange(of: model.selectionToRestrict)` -> `applySchedule()` (`ContentView.swift:228`, `:59-68`) -> `Schedule.setSchedule(start: 08:00, end: 16:00)`, silently moving the enforced block an hour earlier. The next morning they are shielded from 08:00 (an hour they did not pick) and unblocked at 16:00 (an hour of screen time they did not ask for).

**User impact**

Twice a year, and after any flight, the user's block window moves by the UTC-offset delta without them touching it: the app displays times that are not what they configured, and the next re-registration moves the actual enforcement to those wrong times. In the cross-DST-edit variant the window can invert and register an ~23-hour block with no risk confirmation and an empty-looking slider.

**API semantics relied on**

App-side mechanism needs no Apple semantics — it is `Calendar.current.dateComponents([.hour,.minute], from:)` on a fixed instant, whose result changes with the zone's UTC offset. Two claims about the system side are weaker and I could not confirm them from Apple documentation (fetch of developer.apple.com/documentation/deviceactivity/deviceactivityschedule returned no body; web search found only forum-level guidance): (a) that a `DeviceActivitySchedule` built from bare hour/minute DateComponents (no `timeZone`) is evaluated in the device's current zone and therefore keeps its original wall-clock hour across a DST change; (b) that an already-registered repeating schedule is not re-derived by the system. If (a)/(b) were false the UI-vs-configuration drift documented above still stands on its own.

### `F3-TIME-03` — Handle time pills use the locale's 12-hour clock while the hour axis is hardcoded 24-hour

- **Severity** Nit · **Confidence (self-reported)** high · **Invariant** F3.8 · **Needs device** no
- **Anchor** `ScreenTimeShield/ScheduleRangeSlider.swift:160`

**Mechanism**

`label(_:)` formats both handle pills and the "now" marker with `date.formatted(date: .omitted, time: .shortened)` (`:54-56`, used at `:118` and `:146`), which follows the locale's hour cycle — 12-hour with AM/PM for en-US, ko, and other h12 locales. The axis directly below is built with `String(format: "%02d:00", hour)` plus a literal `"24:00"` (`:160`), which is unconditionally 24-hour and also uses ASCII digits regardless of locale. The two label sets are drawn against the same track, so the same instant is spelled two different ways ~30pt apart.

**Failure trace**

Device locale en-US. User drags the end handle to 17:00. The pill above the handle renders "5:00 PM" while the axis tick immediately beneath it reads "18:00" and the one to its left "12:00". Same for the "now" marker during an active block ("1:36 PM" over a 24-hour axis).

**User impact**

A 12-hour user has to mentally convert to place the handle against the axis, and can misread a PM handle as an AM position; the schedule card looks inconsistent.

**API semantics relied on**

`Date.FormatStyle` `.shortened` time follows the locale's preferred hour cycle (12-hour for en-US, ko; 24-hour for en-GB, de, ja) — standard, well-documented Foundation behaviour; not separately fetched.

### `F3-TIME-04` — On a spring-forward day the handle cannot be placed in the skipped hour — `date(bySettingHour:)` substitutes the next existing time

- **Severity** Nit · **Confidence (self-reported)** medium · **Invariant** F3.4 · **Needs device** no
- **Anchor** `ScreenTimeShield/ScheduleRangeSlider.swift:41`

**Mechanism**

`dateAtMinute` calls `date(bySettingHour:minute:second:of: Date())` with the default `matchingPolicy: .nextTime` (`:41`). The swift-foundation implementation preserves `.nextTime` verbatim (`restrictedMatchingPolicy = matchingPolicy` when it is `.nextTime` or `.strict`) and searches forward from the start of *today*. On the local DST spring-forward date the requested wall-clock time inside the skipped hour does not exist, so `.nextTime` returns the next time that does. The returned Date's hour/minute (read back by `minutes(of:)`, `:34-37`) therefore differ from the minute the user's finger was on, and that substituted value is what `didSet` persists (`Model.swift:44`).

**Failure trace**

Locale America/New_York, app opened on 2027-03-14 (02:00 -> 03:00 skipped). User drags the start handle to 02:30: `minute(forX:)` = 150 -> `dateAtMinute(150)` -> `bySettingHour: 2, minute: 30` has no match on that date -> `.nextTime` yields the first existing instant at/after it (03:00-ish). `minutes(of: start)` now reports ~180, so the handle snaps forward roughly an hour ahead of the finger and the pill reads 03:00 instead of 02:30; every subsequent position inside the skipped hour behaves the same, so the handle appears stuck. The value persisted for all future days is 03:00, not the 02:30 the user was pointing at.

**User impact**

On one day a year (per DST-observing region) part of the slider is unreachable and the handle jumps ahead of the drag; a user configuring their schedule that day ends up with a block starting up to an hour later than they intended, on every subsequent day.

**API semantics relied on**

Relied on: `date(bySettingHour:minute:second:of:)` defaults to `matchingPolicy: .nextTime` and, for a time skipped by a DST transition, returns the next existing time rather than nil. Verified the default policy and its propagation from the swift-foundation source (Sources/FoundationEssentials/Calendar/Calendar.swift, quoted above); the precise instant `.nextTime` picks inside a skipped hour (03:00 vs 03:30) is not documented explicitly, hence medium confidence on the exact magnitude, not on the substitution itself.

### `F3-TIME-05` — The "now" marker on an active block is a snapshot from the last view update and does not advance

- **Severity** Nit · **Confidence (self-reported)** medium · **Invariant** F3.8 · **Needs device** no
- **Anchor** `ScreenTimeShield/ScheduleCard.swift:27`

**Mechanism**

`ScheduleCard` passes `now: model.insideInterval ? Date() : nil` (`ScheduleCard.swift:27`). `Date()` is evaluated during `body`, and nothing in the card or `ScheduleRangeSlider` drives a periodic invalidation (no `Timer`, no `TimelineView`; the slider just draws `nowMarker(at: x(for: minutes(of: now)))`, `:78-80`, `:141-153`). SwiftUI re-evaluates `body` only when observed state changes, and during an active block the observed values (`insideInterval`, `start`, `end`, selection) are by design frozen.

**Failure trace**

Block active 09:00–17:00. User foregrounds the app at 09:05; the card renders the marker at 09:05 with the pill "9:05 AM". They leave the app in the foreground (or return to it without any state change) and look again at 10:30: the vertical marker and its label are still drawn at 09:05, i.e. the app claims the current time is 85 minutes in the past.

**User impact**

During the one state where the marker exists — a locked, unstoppable block — it can show a stale time, so the user misjudges how much of the block is left.

**API semantics relied on**

Relied on: SwiftUI re-evaluates `body` only in response to observed-state or environment changes, so a bare `Date()` in `body` does not tick. Standard SwiftUI behaviour; not separately fetched. Medium confidence because incidental invalidations (scene phase, other @Published churn) will often refresh it before the user notices.

<details><summary>Ruled out by this lens</summary>

F3.1 minute<->pixel round-trip: I worked the algebra and it holds for every 5-minute value. `x(for:) = labelInset + usable*m/1440`, and `minute(forX:)` inverts it then snaps with `(raw/5).rounded()*5` (ScheduleRangeSlider.swift:44-52). The `Int(...)` truncation in `minute(forX:)` loses at most 1 minute, well inside the +/-2.5 min the 5-minute snap absorbs, so `minute(forX: x(for: m)) == m` for all m in {0,5,...,1440}; float error in `usable * m / 1440` is far smaller still. The only asymmetry is that truncation-before-rounding shifts snap thresholds by <1 minute (raw 2.9 -> 5 instead of 0), which is sub-pixel and not user-visible. Not a bug.

F3.3 minGap under normal drags: the `min(m, minutes(of: end) - minGap)` / `max(m, minutes(of: start) + minGap)` clamps at :134/:136 do hold for every drag order and speed, because each onChanged re-reads the *other* handle's live value rather than a gesture-start snapshot, and both handles write through the same 5-minute snap. Negative inputs are safe: `dateAtMinute` clamps with `max(0, min(1440, m))` (:40). The only way past the floor is the `?? Date()` fallback (candidate 1), so I report it there rather than as a separate slider bug.

Seconds/nanoseconds surviving into comparisons: ruled out. `dateAtMinute` passes `second: 0` (:41), and every consumer requests only `[.hour, .minute]` — ScheduleRangeSlider.minutes(of:) (:35), Schedule.components(from:) (Schedule.swift:70), ContentView.minutesOfDay (:115), AccessController:139. So even the `Date()` fallback's seconds/nanoseconds are dropped before any comparison or before reaching DeviceActivitySchedule. No sub-minute drift anywhere.

"of: Date()" producing tomorrow's date: I suspected `date(bySettingHour:)` might return the *next* occurrence (i.e. tomorrow 09:00 when called at 15:00), which would have made `dateAtMinute` day-inconsistent. Ruled out from the swift-foundation source: it searches from `dateInterval(of: .day, for: date).start - 0.5`, and re-searches only if the result precedes the start of that day — so it returns a time on the same day. And in any case only hour/minute are ever read back, so the day component is inert (except for the DST interaction I do report).

Force-unwrapped `?? Date()`-free `bySettingHour` sites: `Model.swift:42/49` (`bySettingHour: 9` / `17`, force-unwrapped) and `AccessController.swift:195-196` cannot produce nil or a wrong hour: hours 9 and 17 are always in range, and with `.nextTime` a DST-skipped 09:00/17:00 would still return an existing instant rather than nil. No crash path, no fallback path there.

`ScheduleMath.windowContains` (ScheduleMath.swift:16-24): correct for both same-day and wrapping intervals and correctly half-open; the `start == end` guard makes zero-length empty. Matches the tests at ScheduleMathTests.swift:7-27. `freeMinutes` (:29-32) is correct for any well-ordered same-day window in both modes (the F3.6 complement holds because `blockedInterval` swaps the pair rather than recomputing). Its only defect is the unguarded `windowEnd - windowStart` for a *reversed* window, which is unreachable except through the two mechanisms I report, so I folded it into those traces instead of claiming an independent bug.

F3.2 handle/track/axis coordinate alignment: all four elements go through the same `x(for:)` on the same `[labelInset, width - labelInset]` inset space; the handle offsets by `cx - thumbSize/2` on a `thumbSize`-wide circle and the axis labels by `cx - labelInset` on a `2*labelInset`-wide frame, i.e. both centred on `cx`. The slider and the axis are separate GeometryReaders but sit in the same VStack with identical width, so `w` matches. No misalignment found (the only cross-element inconsistency is the label *format*, candidate 3).

F3.9 lock-out of editing while active: `locked: model.insideInterval` removes the gesture entirely (`.gesture(locked ? nil : ...)`, :129) and the mode Picker is `.disabled(model.insideInterval)` (ScheduleCard.swift:21), so no write to start/end can occur while a block is active. Nothing in my lens defeats it.

Timezone handling of the *quick-hour* path and of `setNotificationSchedule` I deliberately did not chase — see outsideLensNotes.

</details>

<details><summary>Noted outside lens (uninvestigated)</summary>

- ContentView.swift:105-110 `performRestrictHour` builds start = now / end = now + 1h and hands them to `Schedule.setSchedule(..., repeats: false)`, where `components(from:)` throws away the day (Schedule.swift:69-71). Started at 23:30 that becomes intervalStart 23:30 > intervalEnd 00:30, i.e. an interval the app itself documents as "wrapping midnight" (Model.swift:34-35), and the `.hourly` activity is never stopped by `stop()` (ContentView.swift:84 stops only `.daily` and `.notificationSchedule`). Arm/disarm lens.
- `Schedule.setNotificationSchedule` (Schedule.swift:43-60) is fed the *already inverted* `blockedInterval`, so in allow-only mode the notification interval equals the picked (allowed) window rather than its complement — worth a look from the arm/notification lens; it also inherits the same `components(from:)` hour/minute-only representation.
- Schedule.swift:37-39 / :56-58 still swallow `startMonitoring` errors with `print` (already recorded in status.md as open).
- AccessController.swift:132-141 reuses the same drifting `"start"` Date for the trial-ended `UNCalendarNotificationTrigger`, so the DST drift in candidate 2 also moves that daily reminder — trial/paywall lens.
- `ScheduleRangeSlider`'s doc comment (:8-10) still says "Same-day window for now — overnight (end < start) is a known follow-up", while `Model.blockedInterval` and the allow-only mode now depend on end < start being meaningful; stale-intent risk, not investigated.

</details>

---

## F3 · F3:interaction-mapping

### `F3-MAP-01` — Dragging the end handle to the right edge (labelled "24:00") silently sets the end time to *now* instead of midnight

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F3.4 · **Needs device** no
- **Anchor** `ScreenTimeShield/ScheduleRangeSlider.swift:41`

**Mechanism**

The pixel→minute mapping has domain [0, 1440] — `minute(forX:)` clamps with `min(totalMinutes, snapped)` where `totalMinutes = 24*60` (ScheduleRangeSlider.swift:24, :51) — but `dateAtMinute(_:)` can only represent [0, 1439]: for m = 1440 it calls `Calendar.current.date(bySettingHour: 1440/60 = 24, minute: 0, second: 0, of: Date())`, which returns nil (hour 24 is not a valid hour component), so the `?? Date()` fallback on :41 hands back **the current wall-clock time**. The value 1440 is reachable by construction, not just by overshoot: `x(for: 1440, width:)` == `width - labelInset`, i.e. exactly the right end of the track, and *any* finger position at or past that x clamps to 1440 (verified: `minute(forX: 26, width: 40)` and the full 5-minute round-trip sweep both land on 1440). The end handle is the only one that can reach it, via :136 `end = dateAtMinute(max(m, minutes(of: start) + minGap))`. The hour axis explicitly prints "24:00" under that exact x (:158-160), so the UI invites the drag. I reproduced the Foundation behaviour by running the file's own three functions verbatim under Swift 6.2/Foundation: `dateAtMinute(1440)` returned `2026-07-25 18:53:33 +0000` (i.e. `Date()`, minute-of-day 1193) while `dateAtMinute(1435)` correctly returned 23:55.

**Failure trace**

Mode "Block these hours", window 20:00–22:00, current time 19:53, not armed. (1) User drags the right handle all the way to the right edge to mean "block until midnight". (2) `handle(...).onChanged` (:130-137) computes m = 1440, `max(1440, 1200+15)` = 1440, `dateAtMinute(1440)` → nil → `Date()` → `end` = 19:53. (3) `Model.end.didSet` (Model.swift:50-52) persists 19:53 into the `group.screentimeshield` app group. (4) UI: the end pill flips to "7:53 PM", the end handle jumps to the *left* of the start handle, and `fillBar(from: startX, to: endX)` renders `max(0, x1-x0)` = 0 → the highlighted window disappears entirely. minGap is now violated in the negative direction: start (1200) > end (1193), so F3.3 is broken too. (5) User taps "Start blocking". `isRiskyToArm()` (ContentView.swift:124-133) computes `freeMinutes(windowStart: 1200, windowEnd: 1193, blockOutsideWindow: false)` = 1440 − max(0, −7) = **1440 free minutes**, and `windowContains(now: 1193, start: 1200, end: 1193)` = false (1193 >= 1200 false, 1193 < 1193 false) → **no risk confirmation is shown**. (6) `performArm()` → `applySchedule()` → `Schedule.setSchedule(start: 20:00, end: 19:53, repeats: true)` registers `DeviceActivitySchedule(intervalStart: 20:00, intervalEnd: 19:53)`. (7) At 20:00 `intervalDidStart` sets `inside_interval` and applies the shields; because intervalStart > intervalEnd the system treats it as a wrapping interval (per the app's own claim, Model.swift:34-35), so the block runs ~23h53m instead of the 4h the user picked — with the CTA disabled the whole time (ContentView.swift:44-46).

**User impact**

A user aiming for "…until midnight" gets their end time silently replaced by the current time. Best case the window collapses to nothing and the picked schedule is not what was displayed; worst case (start later in the day than the current time) the window inverts and arms as a near-24-hour unstoppable block, and the risk confirmation that exists precisely to warn about this is bypassed because `freeMinutes` clamps the negative length to 0 and reports 1440 minutes free.

**API semantics relied on**

(a) `Calendar.date(bySettingHour:minute:second:of:)` returns nil for hour 24 — verified empirically by running the file's own `dateAtMinute` under Swift 6.2 Foundation (returned `Date()` for 1440, correct value for 1435), and consistent with Apple's docs ("returns nil if a valid date could not be found"). (b) The *worst-case* consequence in step 7 depends on `DeviceActivitySchedule` treating intervalStart > intervalEnd as wrapping past midnight. I could NOT confirm that in Apple's documentation (the init docs and forum threads do not state it); the repo asserts it at Model.swift:34-35. If the system instead rejects or truncates such a schedule, steps 1-6 still stand (wrong persisted end time, empty displayed window, confirmation bypassed) and the arm error would be swallowed by Schedule.swift:36-38.

### `F3-MAP-02` — At short windows the start handle is completely covered by the end handle, so the window's start time cannot be edited at all

- **Severity** Important · **Confidence (self-reported)** medium · **Invariant** NEW · **Needs device** no
- **Anchor** `ScreenTimeShield/ScheduleRangeSlider.swift:83`

**Mechanism**

Both handles are 28pt circles (`thumbSize`, :26) centred on their value's x, and the end handle is added to the ZStack *after* the start handle (:82-83), so it is frontmost and wins hit-testing wherever the two overlap. The separation between them is `usable * gap / 1440`. On an iPhone 16: screen 393 − 2×16 outer padding (ContentView.swift:207) − 2×16 card padding (ScheduleCard.swift:42, `Style.Spacing.md` = 16) = 329pt slider width, so `usable(329)` = 329 − 2×24 = 281pt and 1pt ≈ 5.1 minutes. At the enforced `minGap` of 15 minutes (:23) the centres are 281×15/1440 = **2.9pt** apart, so the end handle covers all but a 2.9pt strip of the start handle's 28pt hit area — far below any usable touch target. And because the end handle's own drag clamps with `max(m, minutes(of: start) + minGap)` (:136), dragging that accidentally-grabbed handle leftwards recomputes the identical value every frame: nothing moves. There is no z-order flip, no `zIndex`, and no widened hit region for whichever handle the finger is closest to.

**Failure trace**

Not armed, allow-only mode, user has set "allow only 09:00–09:15" (reachable by dragging the end handle left until it stops at start+minGap, and persisted across launches via Model.swift:44/:51). (1) User now wants the allowed window earlier, so presses the visually-left handle and drags left. (2) The touch lands inside the end handle's frame (it spans cx_start−11.1 … cx_start+16.9 while the start handle spans cx_start−14 … cx_start+14, leaving a 2.9pt sliver), so `edge == .end`. (3) `onChanged` computes m for the leftward finger position, e.g. 480, then `end = dateAtMinute(max(480, 540+15))` = 09:15 — unchanged. `Model.end.didSet` rewrites the same value, the view re-renders identically. (4) Nothing on screen moves for the entire drag; repeated attempts behave the same. The only escape is to drag the same handle *rightwards* (lengthening the window past ~28pt ≈ 143 minutes) before the start handle becomes reliably grabbable again — the opposite of what the user wants. The two time pills are also drawn on top of each other 2.9pt apart, so the labels are illegible in this state.

**User impact**

With any window shorter than roughly two hours the start time becomes progressively unreachable, and at the 15-minute minimum it is frozen: the slider looks broken (drags do nothing) and the user cannot move an allow-only window to an earlier time without first making it much longer.

**API semantics relied on**

Relies on SwiftUI hit-testing the frontmost sibling in a ZStack first, and on `.offset` moving a view's interactive area with its rendering (both standard SwiftUI behaviour, no doc lookup performed). The geometry numbers are computed from the constants in the file plus the padding chain in ScheduleCard.swift:42 and ContentView.swift:207.

### `F3-MAP-03` — Handle drags are mapped absolutely, so the handle teleports up to ~70 minutes to the finger the moment a drag begins

- **Severity** Nit · **Confidence (self-reported)** high · **Invariant** NEW · **Needs device** no
- **Anchor** `ScreenTimeShield/ScheduleRangeSlider.swift:131`

**Mechanism**

`onChanged` converts the *absolute* touch location into a value — `minute(forX: value.location.x, width: width)` (:131) — without ever recording the offset between the touch-down point and the handle's centre at gesture start. Since the gesture is attached only to the 28pt handle (:129), not to the track, tap-to-position is not the intended interaction; the handle should track the finger's *movement*. Instead, the first `onChanged` snaps the value to wherever the finger is. On an iPhone 16 the usable track is 281pt (see the geometry chain in the previous finding), i.e. 1pt ≈ 5.1 minutes, so a touch landing at the edge of the 14pt handle radius displaces the value by up to 14 × 5.1 ≈ 71 minutes — despite the slider advertising 5-minute precision via `snapMinutes` (:22) and the time pill.

**Failure trace**

Not armed, window 09:00–17:00. (1) User presses the start handle slightly left of centre (a normal thumb landing) and drags right by the 10pt that `DragGesture`'s default `minimumDistance` requires. (2) The first `onChanged` fires with `value.location.x` = touch point + 10pt, which is (offset within the handle) + 10pt away from the handle centre; `minute(forX:)` returns e.g. 08:00 → `start = dateAtMinute(480)`. (3) The pill jumps from "9:00 AM" to "8:00 AM" in one frame even though the finger moved 10pt, and `Model.start.didSet` persists it. The user can drag back to correct it within the same gesture, but every grab starts with a jump of tens of minutes in an arbitrary direction.

**User impact**

Setting an exact time is fiddly and feels unpredictable: touching a handle to nudge it by 5 minutes first throws it up to an hour away. Combined with the previous finding, a touch aimed at a nearly-buried start handle both grabs the wrong handle and jumps its value.

**API semantics relied on**

`DragGesture`'s default `minimumDistance` is 10pt (Apple's `DragGesture.init(minimumDistance:coordinateSpace:)` default) and `DragGesture.Value.location` is the current touch location in the given coordinate space, not a delta — both from the DragGesture API surface; no live doc fetch performed. The named-coordinate-space plumbing itself is correct (see ruledOut), so the reported displacement is purely the missing grab-offset.

<details><summary>Ruled out by this lens</summary>

Coordinate-space plumbing (F3.2) — checked and clean. `Self.trackSpace` is declared on the frame-wrapped ZStack *inside* the GeometryReader (:85-86); GeometryReader places its content at its own top-leading with the proposed size, and `.frame(height:)` does not change width, so the named space's origin x == 0 == the origin used by `x(for:width: geo.size.width)`. The drag's `value.location.x` therefore lives in the same space as every `cx`. ZStack is `.leading`-aligned and the track Capsule uses `.padding(.horizontal, labelInset)` so it spans [24, w−24]; `fillBar` uses `.offset(x: x0)` with width `x1−x0`, handles use `.offset(x: cx − thumbSize/2)`, and `nowMarker` uses `cx − 1` for its 2pt width — all four agree on the same [labelInset, w−labelInset] mapping. The hour axis is a second GeometryReader in the same VStack, so it receives the same proposed width, and its `.frame(width: 2*labelInset).offset(x: cx − labelInset)` centres each label exactly on `x(for: hour*60)` (hour 0 → frame [0,48], centre 24 = labelInset). No misalignment found.

Round-trip / rounding (F3.1) — I ran the file's `x(for:)`, `minute(forX:)`, `usable()` verbatim under Swift and swept every 5-minute value 0…1440 at widths 358, 310, 300, 393, 250.5, 200, 48 and 40: zero round-trip failures, including both extremes. The `Int()` truncation in `minute(forX:)` (:49) does bias the raw value down by <1 minute before snapping, which shifts the 5-minute snap boundary by ~0.5 min (≈0.1pt) — invisible, and the subsequent `.rounded()` absorbs the float error, so I am not reporting it. `minute(forX:)` also handles px < labelInset correctly (negative raw truncates toward zero, snaps to −0, clamps to 0), and `dateAtMinute(0)` is a valid midnight.

minGap (F3.3) via normal drags — holds. Start clamps to `min(m, minutes(of: end) − minGap)`, end to `max(m, minutes(of: start) + minGap)`, both recomputed from the live binding on every `onChanged`, so drag speed and dragging past the other handle cannot violate it (each event is an absolute position, not an accumulated delta — there is no state to get out of sync). The only reachable violations run through the 1440→`Date()` path in candidate 1 (which can also make end < start, or leave end < minGap so that a subsequent start drag clamps to 0 and yields a sub-15-minute or zero-length window). `minutes(of: start) + minGap` can only exceed 1440 if start > 1425, which itself requires end == 1440, i.e. candidate 1 again.

Narrow widths / `usable()` clamping to 1 — the clamp triggers only below 48pt of slider width. The slider's width comes from ContentView's 16pt page padding plus ScheduleCard's 16pt card padding (≈329pt on an iPhone 16, ≈281pt usable), and Dynamic Type does not shrink it, so I could not construct a reachable path to width < 48. Mathematically the mapping still round-trips at usable == 1 (verified), so I found nothing user-visible here and am not reporting it.

Locking (F3.9) — `.gesture(locked ? nil : DragGesture(...))` (:129) removes the gesture entirely while `model.insideInterval`, and ScheduleCard disables the mode Picker (:21), so no write to start/end is reachable while a block is active. The now-marker Rectangle is drawn before the handles and carries no gesture, so it never steals touches.

Gesture attachment order — the `.gesture` is applied after `.offset(x:)`, so the interactive area travels with the drawn handle; the floating time pill is an overlay (does not grow the layout frame) and is not required for hit-testing correctness.

</details>

<details><summary>Noted outside lens (uninvestigated)</summary>

- ScheduleRangeSlider.swift:160 hardcodes the axis as `%02d:00`/"24:00" (24h) while the handle pills and now-marker use locale-aware `.shortened` (:54-56) — a US user sees "9:00 AM" pills over an "18:00" axis. This is F3.8 and I left it to whichever lens owns display conventions.
- dateAtMinute also misbehaves on the DST spring-forward day: with Europe/Dublin and 2026-03-29 I measured `date(bySettingHour: 1, minute: 0/30, ...)` both returning 02:00, so on that day every drag position inside the missing hour silently resolves to 02:00 (handle sticks, persisted value differs from the pill the user aimed for). Same `dateAtMinute` line as candidate 1 but a different mechanism; F3.4/F3.10 territory.
- `labelInset` is a fixed 24pt "half the widest hour-axis label", but the axis Text and the handle pills use `.fixedSize()` and are centred on their x; at large Dynamic Type they overflow past the slider's leading/trailing edge and get cut by ScheduleCard's `.clipShape(RoundedRectangle...)` (ScheduleCard.swift:44). Cosmetic clipping only — I did not measure it.
- Once end < start (via candidate 1), `ScheduleMath.freeMinutes` clamps the negative length to 0 and reports the whole day free, and `blockedInterval` can produce start == end, which `windowContains` treats as empty while the system may not (F3.7/F3.11). Worth a look by the schedule-math lens.

</details>

---

## F3 · F3:mode-inversion

### `F3-MODE-01` — Risk gate and slider fill use non-wrapping window math while the registered interval wraps midnight, so a wrapping window arms a near-permanent block with no confirmation and no visible fill

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F3.11 · **Needs device** no
- **Anchor** `ScreenTimeShield/ContentView.swift:129`

**Mechanism**

Two different interval models are used for the same schedule. The *enforced* interval comes from `Model.blockedInterval` (Model.swift:36-38) and is explicitly wrapping-capable (`start > end` = spans midnight), and the app's own "am I active now" check is wrapping-aware (`ScheduleMath.windowContains`, ScheduleMath.swift:16-24, called at ContentView.swift:126-128 on the *inverted* interval). But the free-time half of the same risk check (ContentView.swift:129-131) passes the *un-inverted* window into `ScheduleMath.freeMinutes`, whose body is `let windowLength = max(0, windowEnd - windowStart)` (ScheduleMath.swift:30) — it cannot express a wrapping window. Whenever `minutesOfDay(model.start) > minutesOfDay(model.end)`, windowLength collapses to 0 and freeMinutes returns the two maximally wrong answers: 1440 in Block mode (app believes nothing is blocked) and 0 in Allow-only (app believes everything is blocked). Verified numerically: freeMinutes(1320, 360, false) == 1440 while the real free time is 960; freeMinutes(1320, 360, true) == 0 while the real free time is 480. `ScheduleRangeSlider` shares the same non-wrapping assumption: `fillBar` uses `.frame(width: max(0, x1 - x0))` (ScheduleRangeSlider.swift:101), so with endX < startX the Block-mode fill collapses to zero width (nothing drawn) and in Allow-only the two flanking bars (ScheduleRangeSlider.swift:71-76) overlap to cover the whole track. Three reachable ways to get start > end, none of them normalized anywhere (ContentView.onAppear:245-255 only reloads the selection and resyncs isArmed; Model.swift:41-53 loads the raw persisted Dates): (a) UPGRADE — the shipped pre-redesign UI had two unconstrained `DatePicker`s bound straight to `$model.start`/`$model.end` with no ordering check (`git show 8c5aca7^:ScreenTimeShield/ContentView.swift` lines 109-113) and registered `Schedule.setSchedule(start: model.start, end: model.end, …)` directly (line 39), writing the same app-group "start"/"end" keys, so an overnight window such as 22:00→06:00 is an ordinary legacy configuration that survives into v1.3 verbatim; (b) IN-APP — `dateAtMinute(1440)` calls `Calendar.current.date(bySettingHour: 24, …)` which returns nil, so the `?? Date()` fallback (ScheduleRangeSlider.swift:41) sets `end` to *now* (I ran the exact expression: hour 24 -> nil), and m=1440 is what any drag past the right end of the track produces (`minute(forX:)` clamps to 1440, and x(1440) = width − labelInset); (c) a DST/timezone shift of an absolute persisted Date across midnight. `ScheduleRangeSlider.swift:9-10` states the same-day assumption ("overnight (end < start) is a known follow-up"), but nothing enforces or normalizes it before the risk gate or the fill.

**Failure trace**

Legacy path: user on the shipped version sets Schedule Start 22:00 / Schedule End 06:00 (a nightly block; the old DatePickers allow it and the old code registered it as-is). They update to v1.3. -> On launch Model reads the persisted Dates unchanged; ScheduleCard renders the slider with handle pills "22:00" and "06:00" but `max(0, endX - startX)` == 0, so **no blocked region is drawn at all** — the schedule looks empty. -> User taps "Start blocking" at, say, 12:00. `isRiskyToArm()`: activeNow = windowContains(720, 1320, 360) = false (correct), free = freeMinutes(1320, 360, false) = 1440 -> not risky -> **no confirmation alert**. `performArm()` sets isArmed = true and `applySchedule()` registers DeviceActivitySchedule(intervalStart: 22:00, intervalEnd: 06:00, repeats: true). -> At 22:00 the extension's `intervalDidStart` writes inside_interval = true (DeviceActivityMonitorExtension.swift:63) -> the CTA becomes "Blocking" and `primaryDisabled` is true (ContentView.swift:45) for 8 hours. The user was shown an empty schedule, given no warning, and is locked out.
Worse variant via path (b), which defeats the free<=30 gate outright: it is 08:45, window is the default 09:00-17:00, Block mode, armed-inactive. User drags the END handle to the right edge of the track meaning "until midnight". -> `minute(forX:)` returns 1440 -> `dateAtMinute(1440)` returns nil -> `end` := Date() = 08:45. -> Slider now shows end pill "08:45" and zero fill. -> Tap "Start blocking": activeNow = windowContains(525, 540, 525) = false, free = freeMinutes(540, 525, false) = 1440 -> **no confirmation**. -> Registered: DeviceActivitySchedule(09:00, 08:45, repeats: true) = 23h45m blocked every day; real free time is 15 minutes/day. -> From 09:00 the user is shielded, `insideInterval` locks the CTA and the picker (ScheduleCard.swift:21, ScheduleRangeSlider.swift:129), and the only window in which "Stop blocking" is even tappable is 08:45-09:00 the next morning, every day, indefinitely.

**User impact**

A user can arm an effectively permanent daily block (23h45m/day, or an unannounced 8h nightly block after upgrading) without ever seeing the risk confirmation that F4.11 requires, while the slider shows either no blocked region at all (Block mode) or a fully-covered track (Allow-only) — i.e. the picture and caption contradict what is enforced.

**API semantics relied on**

Depends on DeviceActivitySchedule treating intervalStart > intervalEnd as wrapping midnight. Apple's docs do NOT state this explicitly: I fetched developer.apple.com JSON for DeviceActivitySchedule, intervalStart, intervalEnd and init(intervalStart:intervalEnd:repeats:warningTime:) — they only say the components are used to compute nextInterval.start/end and that intervalDidStart fires immediately "if the current date falls in between intervalStart and intervalEnd". Wrapping/overnight schedules are the standard community pattern, are what the shipped version already registered, and the repo asserts the behaviour (Model.swift:34-35) — allow-only mode is built entirely on it. Note the finding does not hinge on it: if instead the system rejects the components (DeviceActivityCenter.MonitoringError.invalidDateComponents, "start or end date components don't match any future dates" — confirmed in the docs), then because Schedule.swift:38 swallows the throw the UI shows "Stop blocking" with nothing registered. Either way freeMinutes/fill disagree with what is enforced. The freeMinutes arithmetic itself I verified by running it (no API involved), and Calendar.date(bySettingHour: 24, …) == nil I verified by running it on this machine (Europe/Dublin).

### `F3-MODE-02` — Allow-only mode can hand DeviceActivity a blocked interval shorter than the documented 15-minute minimum; the throw is swallowed and the UI still claims the block is armed

- **Severity** Important · **Confidence (self-reported)** low · **Invariant** F3.7 · **Needs device** yes
- **Anchor** `ScreenTimeShield/Model.swift:37`

**Mechanism**

`ScheduleRangeSlider`'s `minGap = 15` (ScheduleRangeSlider.swift:23, enforced at :134-136) constrains only the *picked window* — which is exactly the interval registered in Block mode. In Allow-only mode the registered interval is the complement, `blockedInterval` = (start: end, end: start) (Model.swift:37), whose length is 1440 − windowLength, and nothing anywhere checks it: `applySchedule()` passes it straight to `Schedule.setSchedule` (ContentView.swift:62-63) -> `DeviceActivitySchedule` -> `center.startMonitoring` (Schedule.swift:36). Apple documents `DeviceActivityCenter.MonitoringError.intervalTooShort` — "The minimum interval length for monitoring device activity is fifteen minutes" (fetched from developer.apple.com). The throw is caught and only printed (Schedule.swift:37-39), and `performArm()` has already set `model.isArmed = true` (ContentView.swift:78) before dispatch, so the failure is invisible. The risk gate does not catch it either: in Allow-only mode `freeMinutes` returns the window length (ScheduleMath.swift:31), which for a near-all-day window is ~1440 -> far above the 30-minute threshold -> no confirmation.

**Failure trace**

User upgrading from the shipped version with a persisted "block essentially all day" window — start 00:00, end 23:59, which the old unconstrained DatePickers allowed (git show 8c5aca7^:ScreenTimeShield/ContentView.swift:109-113) and which the old code registered as a valid 1439-minute interval. -> In v1.3 they tap "Allow only these hours" (ScheduleCard.swift:16-19). `onChange(of: model.blockOutsideWindow)` -> `disarmIfArmedInactive()` -> stop(). Caption reads "Blocking all day except this window". -> They tap "Start blocking": free = freeMinutes(0, 1439, true) = 1439 -> not risky -> no confirm -> `performArm()` sets isArmed = true, then registers DeviceActivitySchedule(intervalStart: 23:59, intervalEnd: 00:00) — a 1-minute interval. -> `startMonitoring` throws intervalTooShort; Schedule.swift:38 prints it and returns. -> The CTA reads "Stop blocking", StatusBanner reads "Block inactive", no `.daily` activity exists, `intervalDidStart` never fires and nothing is ever shielded. On the next cold launch `model.isArmed = DeviceActivityCenter().activities.contains(.daily)` (ContentView.swift:248) silently flips the button back to "Start blocking". Reachability caveat: within v1.3's own slider this needs an Allow-only window of 23h45m+ — `end` values of 23:50/23:55 sit in a ~2pt band at the right edge of the track (anything further right hits the `dateAtMinute(1440)` -> now fallback), so the legacy-window and "near-midnight now" routes are the realistic ones.

**User impact**

The app reports an armed block ("Stop blocking") while nothing is registered and no app is ever shielded — the user believes they are protected and is not, and the state silently reverts on the next launch.

**API semantics relied on**

DeviceActivityCenter.MonitoringError.intervalTooShort with a documented 15-minute minimum interval, confirmed from Apple's documentation JSON (developer.apple.com/documentation/deviceactivity/deviceactivitycenter/monitoringerror/intervaltooshort: "The minimum interval length for monitoring device activity is fifteen minutes"). What I could not confirm is exactly how the system measures the length of a wrapping/near-zero component pair, i.e. whether a (23:59, 00:00) pair is rejected as intervalTooShort, as invalidDateComponents, or accepted as a 1-minute interval — hence the reduced confidence. All three outcomes violate F3.7 (a degenerate interval is handed to the system unchecked); only the observable symptom differs.

<details><summary>Ruled out by this lens</summary>

Inversion correctness itself: `Model.blockedInterval` (Model.swift:36-38) IS the exact complement of the picked window, including for wrapping windows — swapping the endpoints of a half-open interval [wStart, wEnd) yields [wEnd, wStart), and their union is the whole day with no overlap or gap at the boundary minutes. Checked the concrete cases: 09:00-17:00 allow-only -> blocked (17:00, 09:00) = [17,24)+[0,9); window starting at 00:00 -> blocked (X, 00:00) still correct under wrapping; legacy 22:00-06:00 allow-only -> blocked (06:00, 22:00), correct. `components(from:)` (Schedule.swift:69-70) drops seconds, which is harmless since handle values are 5-minute snapped.
`ScheduleMath.windowContains` (ScheduleMath.swift:16-24): correct for both orderings and correctly treats start == end as empty; the `activeNow` half of `isRiskyToArm` therefore behaves correctly in both modes, including the allow-only wrapping interval. The bug is confined to the freeMinutes half.
`freeMinutes` per mode for well-formed windows: Block -> 1440 − windowLength, Allow-only -> windowLength; both correct, and the mode argument is not inverted (verified against the unit tests at UnplugCoreTests/ScheduleMathTests.swift:31,36). So the \"uninverted window + inverted interval\" split in ContentView.swift:125-131 is deliberate and right — it only fails on the wrapping precondition.
`confirmMessage` (ContentView.swift:135-148) in Allow-only mode: `bi.end` == model.start, i.e. the time the allow window opens = the time the block ends, so \"can't be stopped until <time>\" is the correct time in both modes.
Notification schedule under inversion (Schedule.swift:43-50): it re-inverts `blockedInterval`, so in Allow-only mode the notification interval is exactly the allow window and in Block mode exactly the complement — non-overlapping with the block in both modes, and with minGap = 15 the window side never goes under the API's 15-minute minimum (only the complement side does — finding 2).
The `minGap` window itself, exactly 15 minutes: Block -> 15-minute block + 1425-minute notification interval; Allow-only -> 1425-minute block + 15-minute notification interval. Both sides legal.
Caption/fill for well-formed windows: the inverted fill (ScheduleRangeSlider.swift:71-76) draws [0, startX) + [endX, width) which is exactly the registered complement, and \"Blocking all day except this window\" matches. Only the endX < startX case is wrong.
StatusBanner (StatusBanner.swift) no longer prints any times (\"Times live on the slider only\"), so there is no mode-dependent time text to get wrong there — the times the b3a7d21 commit message mentions were removed in a94003e.
Torn/stale start-end pair from the per-property `didSet` writes (Model.swift:43-52): each `didSet` writes its own key synchronously on the main thread, both keys are read independently at Model init, and nothing else writes them (grep: only ScheduleCard's bindings and AccessController's QA reset). The extension never reads \"start\"/\"end\" (DeviceActivityMonitorExtension.swift reads only the selection, inside_interval, notifications_enabled, enforcement_allowed), so there is no cross-process read of a half-updated pair. Drag-time writes are per-touch-move but only a perf concern.
@AppStorage-inside-ObservableObject not publishing (would have made the mode picker's write invisible to the caption/fill and to `onChange(of: model.blockOutsideWindow)`): I could not substantiate it and there is direct counter-evidence — status.md line 16 records that *toggling Block/Allow* previously started a block via that onChange, i.e. the write does invalidate ContentView's body in practice. Dropped rather than reported.

</details>

<details><summary>Noted outside lens (uninvestigated)</summary>

ScheduleRangeSlider.swift:39-42 (F3.4, slider-math lens): `dateAtMinute(1440)` is nil-producing — I ran `Calendar.current.date(bySettingHour: 24, minute: 0, second: 0, of: Date())` and it returns nil, so the `?? Date()` fallback silently sets the handle to the current time. Because x(1440) = width − labelInset, any drag to/past the right end of the track produces m = 1440, making 23:55/24:00 effectively unreachable and \"drag to midnight\" a data-corrupting gesture. This is the root cause of one reachable path in my finding 1 but should be owned by the slider lens.
ScheduleRangeSlider.swift:134 (F3.3): a legacy overnight pair also breaks minGap — with end = 06:00 persisted, touching the start handle clamps start to min(m, 345), i.e. <= 05:45, silently destroying a 22:00 start with no undo.
Schedule.swift:34-39 (F4.6/F4.8 lens): `stopMonitoring` runs before `startMonitoring`, so when the start throws the *previous* schedule has already been torn down — an edit while armed can end enforcement entirely rather than leaving the old block in place.
AccessController.swift:191 (QA only): `UserDefaults.standard.removePersistentDomain(forName: \"group.screentimeshield\")` does not clear an app-group suite (it must be removed through a UserDefaults instance for that suite), so \"reset to fresh install\" likely leaves the shared defaults intact.

</details>

---

## F4 · F4:state-machine

### `F4-STATE-01` — intervalDidEnd for the one-hour quick block tears down an in-progress daily block: shields cleared and insideInterval reset until the next day

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F4.13 · **Needs device** yes
- **Anchor** `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:74`

**Mechanism**

`intervalDidEnd(for:)` treats `.daily` and `.hourly` as one thing: `if activity.rawValue == "daily" || activity.rawValue == "hourly"` then unconditionally `model.clearRestrictions(); model.insideInterval = false` (DeviceActivityMonitorExtension.swift:74-78). There is no check for whether the *other* activity's interval is still running, and both activities write the same single `inside_interval` flag and the same `ManagedSettingsStore`. The two activities can legitimately overlap because quick-restrict is only gated on `insideInterval` (`isQuickRestrictDisabled`, ContentView.swift:32) — i.e. it is *enabled* right up to the second before the daily interval starts, and `performRestrictHour()` (ContentView.swift:105-110) registers `.hourly` for now→now+1h with no awareness of the armed daily window it will straddle. `intervalDidStart` for `.daily` (line 47-64) is the only thing that ever re-applies the shields, and it will not fire again for that interval.

**Failure trace**

1. User has apps selected and taps "Start blocking" with the default window 09:00–17:00, Block-these-hours mode. `performArm()` sets `is_armed = true` and registers `.daily` for 09:00→17:00 (ContentView.swift:76-80 → Schedule.swift:25-41).
2. At 08:30 `insideInterval == false`, so "Restrict for next hour" is enabled (ContentView.swift:31-33). User taps it, confirms the alert, and `performRestrictHour()` registers `.hourly` for 08:30→09:30 (ContentView.swift:109).
3. Monitor: `intervalDidStart(.hourly)` → `setRestrictions()`, `inside_interval = true`. Shields up.
4. 09:00: `intervalDidStart(.daily)` → `setRestrictions()`, `inside_interval = true` (idempotent).
5. 09:30: `intervalDidEnd(.hourly)` → matches the `"hourly"` branch at DeviceActivityMonitorExtension.swift:74 → `clearRestrictions()` (shield.applications/applicationCategories/webDomains = nil) and `inside_interval = false`.
6. Persisted state: `is_armed = true`, `inside_interval = false`, `.daily` still registered in DeviceActivityCenter, ManagedSettingsStore empty.
7. What the user sees: at 09:30, halfway into the workday block they armed until 17:00, every restricted app opens normally. Unplug's StatusBanner reads "Block inactive" (StatusBanner.swift:33), the primary CTA reads "Stop blocking" and is enabled (ContentView.swift:39, :46), and the schedule slider unlocks (ScheduleCard.swift:21-29). Nothing re-applies the shields until 09:00 the next day.

**User impact**

An armed, active, unbypassable block silently ends early and stays off for the rest of its window — the exact opposite of the product promise. Reachable without any intent to cheat (use the quick hour block shortly before your scheduled block starts), and trivially repeatable as a deliberate bypass: quick-restrict an hour that ends inside the daily window and the daily block dies with it.

**API semantics relied on**

Only relies on the framework behaviour the app already depends on for its core feature: `DeviceActivityMonitor.intervalDidEnd(for:)` is delivered when a scheduled interval reaches its end (Apple docs for intervalDidEnd(for:) — "called when the interval ends"), and that two DeviceActivity activities can be monitored concurrently (the app registers `.daily`, `.hourly` and `.notificationSchedule` under distinct names; DeviceActivityCenter permits multiple activities, erroring only with `.excessiveActivities`). No exotic semantic needed.

### `F4-STATE-02` — Adding an app during an active block re-registers .daily mid-interval; nothing then guarantees insideInterval is ever cleared or the shield restored

- **Severity** Important · **Confidence (self-reported)** medium · **Invariant** F4.3 · **Needs device** yes
- **Anchor** `ScreenTimeShield/Schedule.swift:34`

**Mechanism**

`inside_interval` is written to `true` only by `intervalDidStart` and back to `false` only by `intervalDidEnd` (DeviceActivityMonitorExtension.swift:63, :77). The only production code that can remove `.daily` while `insideInterval == true` is `Schedule.setSchedule`, which does `center.stopMonitoring([.daily])` immediately followed by `center.startMonitoring(.daily, during: schedule)` (Schedule.swift:34-36) — and that runs while a block is active, because `.onChange(of: model.selectionToRestrict)` calls `applySchedule()` (ContentView.swift:228) and `applySchedule()`'s guard only requires `isArmed && !isExpired && !isEmpty` (ContentView.swift:60), not `!insideInterval`. Adding apps mid-block is a deliberately supported action (`openPicker()` is gated only on `isExpired`, ContentView.swift:95-98; F4.4 permits growth). Both possible framework behaviours are unhandled:
(a) if `stopMonitoring` delivers `intervalDidEnd`, the extension clears the shields and sets `inside_interval = false` mid-block, and the app has a window in which the CTA is live;
(b) if it does not, and the re-registered schedule is treated as "next occurrence" rather than "already in progress", no `intervalDidEnd` arrives until the *following* day's 17:00, leaving `inside_interval == true` with the CTA permanently disabled (ContentView.swift:45) and the schedule locked (ScheduleCard.swift:21). Nothing in the shipping app can clear that flag — `qaResetToFreshInstall` (AccessController.swift:199) is the only other writer and its entry point is commented out in SettingsView.swift.

**Failure trace**

Branch (a) — early unlock:
1. Armed, window 09:00–17:00. 12:00: `intervalDidStart(.daily)` already ran, shields up, `inside_interval = true`, CTA reads "Blocking" and is disabled.
2. User taps the app card (allowed: ContentView.swift:95) and *adds* one more app. `.onChange(of: model.selectionToRestrict)` fires; `model.validateRestriction()` passes because the token set only grew (Model.swift:74-81); `saveSelection()`; `applySchedule()` (ContentView.swift:221-228).
3. `Schedule.setSchedule` → `center.stopMonitoring([.daily])` (Schedule.swift:34). If that delivers `intervalDidEnd(.daily)`, the extension runs `clearRestrictions()` and `inside_interval = false`.
4. Picker sheet dismissal re-evaluates ContentView, which re-reads `inside_interval` from the app group → StatusBanner flips to "Block inactive" and the primary CTA becomes an enabled "Stop blocking".
5. User taps it: `stop()` sets `is_armed = false`, `stopMonitoring([.daily, .notificationSchedule])`, `clearRestrictions()` (ContentView.swift:82-86). The block is over at 12:00 instead of 17:00.
Branch (b) — lock-out:
3'. `stopMonitoring` delivers nothing; `startMonitoring(.daily, during: 09:00→17:00)` at 12:00 is resolved as starting at 09:00 *tomorrow*. `inside_interval` stays `true` and the shields stay applied.
4'. Persisted state: `is_armed = true`, `inside_interval = true`, `.daily` registered for tomorrow. The user sees "Blocking" with a disabled CTA and a locked schedule, and every selected app stays shielded, from 12:00 today until 17:00 tomorrow — ~29 hours. No in-app action escapes it (the CTA is disabled, the slider is locked, and the QA reset is unreachable in production); the only exit is deleting the app.

**User impact**

Either a supported action (adding an app to an active block) ends the block early — a bypass — or it strands the user in the lock-out state F4.3 exists to forbid, with restrictions enforced roughly a day past their scheduled end and no way out short of deleting the app.

**API semantics relied on**

Apple's docs for `DeviceActivityCenter.stopMonitoring(_:)` and `DeviceActivityMonitor.intervalDidEnd(for:)` say nothing about whether stopping monitoring delivers `intervalDidEnd`; I could not confirm it from Apple. Two conflicting non-Apple sources: general reading of the docs ("intervalDidEnd is called when the scheduled interval ends") implies NOT delivered, while a practitioner write-up (habitdoom.com/blog/apple-screen-time-api-guide) states "When you call center.startMonitoring() for a DeviceActivityName that is already being monitored, it first calls stopMonitoring() internally. This triggers intervalDidEnd" and reports it re-blocking apps mid-session in production. Nor could I confirm whether `startMonitoring` with a schedule whose DateComponents interval already contains "now" is treated as in-progress (Apple forum threads 726331 / 729841 suggest the system does resolve to the *previous* matching components, which would favour self-healing). Because the code handles neither answer, one of the two branches above holds regardless — but which one, and therefore the exact consequence, is unverified. Confidence lowered to medium accordingly; on-device observation of the extension logs would settle it.

### `F4-STATE-03` — Removing every selected app while armed leaves .daily registered, so the block activates, locks the whole UI for the full window, and enforces nothing

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** NEW · **Needs device** yes
- **Anchor** `ScreenTimeShield/ContentView.swift:60`

**Mechanism**

`applySchedule()` returns early when the selection is empty (`guard model.isArmed, !isExpired, !model.isEmpty()`, ContentView.swift:60) and no other path disarms on an empty selection — `disarmIfArmedInactive()` is only wired to `model.start`/`model.end`/`model.blockOutsideWindow` (ContentView.swift:233-235), not to `model.selectionToRestrict`. So `is_armed` stays true and the previously-registered `.daily` schedule stays live. On the extension side `intervalDidStart` has no emptiness check: it calls `model.loadSelection()` then `model.setRestrictions()`, which sets every shield to `nil` for an empty selection (Model.swift:95-97), and then sets `model.insideInterval = true` unconditionally (DeviceActivityMonitorExtension.swift:60-63). `insideInterval == true` is what locks the entire UI (CTA disabled ContentView.swift:45, mode picker disabled ScheduleCard.swift:21, slider gestures removed ScheduleRangeSlider.swift:129), so the app locks itself down around a block that shields nothing. Adding apps back during that window does not help either: nothing in the main app calls `setRestrictions()` — only the extension does, at interval start, which has already passed.

**Failure trace**

1. User is armed for 09:00–17:00 with 4 apps; `is_armed = true`, `.daily` registered.
2. At 08:00 (inactive) the user opens the picker and deselects all 4 apps, intending to reconfigure later. `.onChange(of: model.selectionToRestrict)` → `insideInterval` is false so the removal guard is skipped → `saveSelection()` writes the empty selection → `applySchedule()` returns immediately at the `!model.isEmpty()` guard (ContentView.swift:60). `.daily` is still registered; `is_armed` is still true.
3. User leaves the app.
4. 09:00: `intervalDidStart(.daily)` → `loadSelection()` (empty) → `setRestrictions()` sets shield.applications / applicationCategories / webDomains all to nil → `inside_interval = true`.
5. Persisted state: `is_armed = true`, `inside_interval = true`, `.daily` registered, ManagedSettingsStore empty.
6. What the user sees, 09:00 to 17:00: StatusBanner "Block active", the primary CTA reads "Blocking" with a padlock and is disabled, the schedule card shows "Schedule locked while a block is active", and the app card header reads "Restricted" over an empty list. Every app on the phone is usable. The user cannot stop it, cannot change the window, and cannot make the block actually protect anything for the next 8 hours.

**User impact**

An eight-hour "Block active" state that enforces nothing while locking the user out of every control that could fix it. Worst case it is also a bypass recipe: clear the selection before the window opens and you get the appearance of a block with zero enforcement.

**API semantics relied on**

None beyond the app's own core reliance on `intervalDidStart` firing at the registered interval start. `ManagedSettingsStore.shield.applications = nil` clearing the shield is the same call `clearRestrictions()` (Model.swift:100-104) already uses as the teardown, so the no-op-enforcement half needs no new assumption.

### `F4-STATE-04` — Toggling refocus notifications on while nothing is armed registers the notification schedule, so nag notifications fire with no block in existence

- **Severity** Nit · **Confidence (self-reported)** high · **Invariant** F4.12 · **Needs device** yes
- **Anchor** `ScreenTimeShield/ContentView.swift:236`

**Mechanism**

`.onChange(of: model.notificationsEnabled)` registers `.notificationSchedule` whenever the toggle goes true and the selection is non-empty — the condition is `if newValue && !model.isEmpty()` (ContentView.swift:237), with no `model.isArmed` check, unlike `applySchedule()` which does guard on it (ContentView.swift:60). The schedule it registers is derived from `model.blockedInterval` (ContentView.swift:238-240 → Schedule.swift:43-60) as the inverse window, so it is live for most of the day. The extension's `eventDidReachThreshold` only checks the activity name and the `notifications_enabled` flag (DeviceActivityMonitorExtension.swift:96) — never whether a block exists — so it will fire the 5/10/…/50-minute refocus notifications.

**Failure trace**

1. User selects apps but never taps "Start blocking" (or arms and later taps "Stop blocking", which does clear `.notificationSchedule` at ContentView.swift:84). `is_armed = false`, nothing registered.
2. User opens the gear → Settings and toggles "Send refocus notifications" off, then back on (SettingsView.swift, `Toggle(isOn: $model.notificationsEnabled)`).
3. `.onChange` fires with `newValue == true` and a non-empty selection → `Schedule.setNotificationSchedule(restrictionStart: 09:00, restrictionEnd: 17:00, events: model.notificationEvents())` registers `.notificationSchedule` for 17:00→09:00 with ten thresholds (Model.swift:126-139).
4. Persisted state: `is_armed = false`, `.notificationSchedule` registered and outliving any block.
5. That evening the user spends 5 minutes in a selected app and gets "You've been using a restricted app for 5 minutes, tap here to regain focus", then more at 10, 15… minutes (4-minute cooldown, DeviceActivityMonitorExtension.swift:89-105) — while they have no block armed and the app's own banner says "Block inactive".

**User impact**

Recurring guilt-trip notifications about "restricted" apps for a user who has explicitly not armed a block, with no visible cause in the app and no way to correlate them to anything on screen. Toggling the switch off clears it again, so the user's escape is non-obvious.

**API semantics relied on**

Relies on `DeviceActivityMonitor.eventDidReachThreshold` being delivered for a registered activity independently of any other activity — the mechanism the refocus feature is built on and which the app already ships. No unverified semantic.

<details><summary>Ruled out by this lens</summary>

Enumerated the reachable (isArmed, insideInterval, registered-activities) combinations and cleared the following:

- **@AppStorage not publishing (would have made every state write invisible to the UI):** ruled out. Apple documents @AppStorage as triggering `objectWillChange` inside an ObservableObject from iOS 14.5+ (confirmed via fatbobman.com/en/posts/appstorage), so `model.isArmed = true` at ContentView.swift:78 and the extension-owned flags do invalidate views on same-process writes, and the `.onChange(of: model.start/end/blockOutsideWindow/notificationsEnabled)` handlers at ContentView.swift:233-244 do fire. Cross-process writes (extension → `inside_interval`) are picked up on the next body evaluation because AppStorage reads UserDefaults on `get`, and foregrounding forces one via `ScreenTimeShieldApp.swift:95-103` → `refreshAccess()` → `@Published accessState`. Not a defect I can trace.
- **stop() reachable while a block is active:** unreachable. `primaryDisabled` returns true on `insideInterval` (ContentView.swift:45), `PinnedActions` applies `.disabled` (PinnedActions.swift:37), and `onPrimary()` early-returns anyway (ContentView.swift:51). The only way into `stop()` mid-block is via a stale `insideInterval == false`, which is candidates 1 and 2.
- **F4.9 start/stop reordering and XPC storms:** fine. `ScheduleRangeSlider` writes `start`/`end` continuously during a drag (ScheduleRangeSlider.swift:130-137), but `disarmIfArmedInactive()` is idempotent — the first fire sets `isArmed = false` (ContentView.swift:91 → :83), so at most one `stop()` and one queued XPC pair per drag; snapping to 5-minute steps also throttles the writes. `Schedule.queue` is a private serial queue (Schedule.swift:23) and `isArmed` is written synchronously on main before the async dispatch, so a rapid Stop→Start cannot land inverted.
- **The onAppear resync when only `.hourly` is registered:** correct as written. `model.isArmed = DeviceActivityCenter().activities.contains(.daily)` (ContentView.swift:248) yields false, which matches reality — `performRestrictHour()` never sets `isArmed` (ContentView.swift:105-110) — and `.hourly`'s own `intervalDidEnd` clears `inside_interval`, so a cold launch mid-hour-block shows "Blocking" and recovers on time. Its bad interaction is with a concurrent `.daily`, which is candidate 1.
- **`stop()` not stopping `.hourly` (F4.7 literal gap at ContentView.swift:84):** could not build a trace. `.hourly` is registered with `repeats: false` and `intervalStart = components(from: Date())`, i.e. the current hour:minute, so its interval is in progress from registration and it cannot sit dormant waiting to re-apply restrictions after a Stop; and while it is active the primary CTA is disabled. Reporting it would be inference from the name of the missing element, not a failure.
- **Arm failure leaving the UI claiming armed (F4.6):** real but already recorded as open in status.md:8 ("`Schedule` still swallows `startMonitoring` errors (`catch { print }`)"), and `Schedule.swift:37-39` is unchanged. The only wrinkle I found beyond the record is that `performArm()` calls `access.startTrialIfNeeded()` (ContentView.swift:77) *before* the throwing registration, so a failed arm still starts the 7-day trial clock — not enough of a new consequence to re-report.
- **`AccessController` as an escape from the lock-out:** it is not one. `qaResetToFreshInstall()` (AccessController.swift:186-205) is the only non-extension writer of `inside_interval`, and its entry point is the commented-out QA Section in SettingsView.swift, so in a production build nothing in the app can clear a stranded `insideInterval`. This is why candidate 2's branch (b) has no in-app exit.
- **Expiry-time teardown:** `refreshAccess()`/`recomputeAccessState()` only flip the cached `enforcement_allowed` gate (AccessController.swift:112-120); they never stop monitoring, and `intervalDidEnd` is ungated (DeviceActivityMonitorExtension.swift:68-79), so an expiry mid-block still clears `inside_interval` at the natural end rather than stranding it. Left to the F9 lens.

</details>

<details><summary>Noted outside lens (uninvestigated)</summary>

- `Model.saveSelection()` sets `hasSelection = true` unconditionally (Model.swift:89), including for an empty selection. Emptying the selection therefore reproduces the "App selection was reset, please re-select apps" toast that status.md:7 records as fixed: next cold launch `loadSelection()` leaves `hasSelection` true, `selectionIsInvalidated()` returns true (Model.swift:106-108), and ContentView.swift:249-254 shows the sticky (duration 0) toast. Selection-state lens, not investigated further.
- `performRestrictHour()` passes only hour/minute DateComponents with `repeats: false` (ContentView.swift:107-109 → Schedule.swift:26-29). At 23:30 the hour block becomes intervalStart 23:30 / intervalEnd 00:30, i.e. start > end with repeats false — schedule-math lens (F3.7), not investigated.
- `applySchedule()` and the selection `onChange` never call `model.setRestrictions()`; only the extension does, at interval start (DeviceActivityMonitorExtension.swift:62). So an app *added* to an already-active block is saved and displayed as "Restricted" (AppCard.swift:27) but is not actually shielded for the remainder of that block. That is F4.4 (enforced token set), someone else's cell.
- `Schedule.setNotificationSchedule` builds the inverse window as intervalStart = restrictionEnd, intervalEnd = restrictionStart (Schedule.swift:48-50). In allow-only mode `blockedInterval` is already inverted (Model.swift:36-38), so the notification schedule becomes the picked window itself; whether that is degenerate for near-24h windows is F3 territory.

</details>

---

## F4 · F4:concurrency-ordering

### `F4-CONC-01` — Nothing in the app observes the extension's `inside_interval` write, so the "locked while a block is active" state never engages (or never releases) while the app stays in the foreground

- **Severity** Important · **Confidence (self-reported)** medium · **Invariant** F4.5 · **Needs device** yes
- **Anchor** `ScreenTimeShield/Model.swift:25`

**Mechanism**

`insideInterval` is the app's only signal that a block is live, and it is written by a *different process*: `DeviceActivityMonitorExtension.intervalDidStart` sets it true (CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:63 → setter at :34-38) and `intervalDidEnd` sets it false (:77). The app side is `@AppStorage("inside_interval", store: UserDefaults(suiteName: "group.screentimeshield"))` declared on `Model`, an `ObservableObject` — ScreenTimeShield/Model.swift:25. Two independent invalidation gaps stack: (a) `@AppStorage` observation is built on `UserDefaults.didChangeNotification`, which Apple documents as not firing for changes made by another process, so nothing tells the app the extension wrote; (b) `@AppStorage` is a `DynamicProperty` — on a class it does not go through SwiftUI's dependency/`objectWillChange` machinery, so even a same-process write to `inside_interval` publishes nothing (unlike `start`/`end`/`selectionToRestrict`, which are `@Published`, Model.swift:40-53). ContentView observes only `model` and `access` (ContentView.swift:18-19) and there is no timer, `TimelineView` or publisher on the screen (StatusBanner.swift has only a local `withAnimation` on `@State isPulsing`, which does not re-evaluate any body). So between the extension's write and the next unrelated invalidation of ContentView, every consumer of `insideInterval` renders the pre-boundary value: the banner (StatusBanner.swift:26,33,41), the mode Picker's `.disabled` and the slider's `locked`/gesture removal (ScheduleCard.swift:21,26 → ScheduleRangeSlider.swift:129), the primary CTA title/disabled (ContentView.swift:38,45), and `isQuickRestrictDisabled` (ContentView.swift:32). The screen is stale for as long as the user stays in it — the only routine refresh is a background→foreground trip, which republishes `access.accessState` (ScreenTimeShieldApp.swift:101-103 → AccessController.swift:112-113).

**Failure trace**

Setup: apps selected, armed for 09:00–17:00 (`isArmed` true, `.daily` registered). 08:58 the user opens Unplug and keeps it on screen. 09:00 the monitor extension (separate process) runs `intervalDidStart(.daily)` → `setRestrictions()` + `insideInterval = true` + `synchronize()` (DeviceActivityMonitorExtension.swift:62-63, 34-38); shields are live — restricted apps are now blocked. The app receives no notification and re-renders nothing, so on screen: "Block inactive", an unlocked draggable slider, an enabled "Allow only these hours" segmented Picker, an enabled "Stop blocking" button and an enabled "Restrict for next hour". (1) The user taps the mode Picker: `$model.blockOutsideWindow` is also `@AppStorage` (Model.swift:29), so the tap writes the new mode straight into the app group with no publish — persisted state now says the block is the *complement* of the window (`blockedInterval`, Model.swift:36-38) while the registered `.daily` schedule and the running block are still 09:00–17:00. Because ContentView is never re-evaluated, `.onChange(of: model.blockOutsideWindow)` → `disarmIfArmedInactive()` (ContentView.swift:235, 90-92) never even runs, so nothing disarms and nothing re-registers. The segmented control also does not visibly move (same missing invalidation), so the user taps it again and again. (2) The user taps "Stop blocking": `onPrimary()` re-reads `model.insideInterval` through the property getter, gets the fresh `true`, and returns silently (ContentView.swift:50-51) — an enabled button that does nothing, with no feedback. Mirror case at the other boundary: the user waits out the block with the app open; at 17:00 the extension clears the shields and writes `inside_interval = false` (:76-77) — apps work again, but the app still shows "Block active", a locked slider and a greyed, non-interactive "Blocking" CTA (ContentView.swift:38,45) for the rest of the foreground session, i.e. exactly the lock-out presentation of F4.3, and the user cannot re-arm or edit until they background/relaunch the app.

**User impact**

The block-active lock is not applied when a block starts while the app is open: the user can change the schedule window and flip Block/Allow-only during an active block, persisting a configuration that no longer matches what is being enforced (and, because `onChange` never fires, without the disarm that is supposed to accompany an edit). "Stop blocking" is a dead enabled button. At the end boundary the app is stuck showing "Block active" with a disabled "Blocking" CTA after the block has actually ended, which is indistinguishable from a permanent lock-out. The stale `isQuickRestrictDisabled` also leaves "Restrict for next hour" tappable during an active block, which stacks a `.hourly` activity whose `intervalDidEnd` clears the shared shields mid-daily-block (see outsideLensNotes).

**API semantics relied on**

Relied on: (1) `UserDefaults.didChangeNotification` does not fire for writes made by another process, and `@AppStorage`'s observation is built on it — confirmed by Apple's documentation for that notification and by the swift-composable-architecture write-up of the identical failure (github.com/pointfreeco/swift-composable-architecture issues #3439 / discussions #3459: "it's using UserDefaults.didChangeNotification to observe changes … this notification is documented to not work across processes"; their fix was to switch to KVO). (2) `@AppStorage` inside an `ObservableObject` does not reliably drive view updates — corroborated by multiple Apple Developer Forums threads (658569, 652384) and dimillian's "The sad state of @AppStorage"; the documented workaround is an explicit `objectWillChange.send()`. NOT verified: whether the *value* read at tap time is read-through-fresh (which yields the dead-button outcome I describe) or cached inside the property wrapper (in which case `stop()` would run and tear down the live block instead — a worse outcome, a genuine bypass). Either way the render staleness stands; the device check should establish which of the two tap outcomes occurs.

### `F4-CONC-02` — `DeviceActivityCenter().activities` is still read synchronously on the main thread on the launch path — the one DeviceActivityCenter call the arm-stall fix did not move off-main

- **Severity** Important · **Confidence (self-reported)** medium · **Invariant** F4.10 · **Needs device** yes
- **Anchor** `ScreenTimeShield/ContentView.swift:248`

**Mechanism**

`Schedule` exists specifically because `DeviceActivityCenter` calls are synchronous XPC round-trips to the system daemon that are "slow enough to stall the UI" (ScreenTimeShield/Schedule.swift:18-23); every start/stop was moved onto the private serial queue (Schedule.swift:32, 51, 64). The `activities` read was missed: `model.isArmed = DeviceActivityCenter().activities.contains(.daily)` runs inline on the main thread inside `ContentView.onAppear` (ContentView.swift:248), i.e. during the first appearance of the root view, before the app is interactive. It is the same daemon round-trip as the calls that were moved, and it is the only remaining production caller of `DeviceActivityCenter` outside the serial queue (grep for `DeviceActivityCenter` gives Schedule.swift, this line, and `AccessController.swift:188` which is QA-only and unreachable with the QA entry commented out at SettingsView.swift:26-29). Being off the serial queue also means this read is unordered with respect to any queued start/stop, so its result is whatever the daemon has committed at that instant rather than the app's last intended state.

**Failure trace**

Cold launch (worst case: first launch after a reboot, or a launch that coincides with the monitor extension being spun up at an interval boundary — the daemon is then busy servicing the extension) → SwiftUI builds ContentView → `.onAppear` runs on the main thread → line 248 blocks the main thread on a synchronous IPC to the DeviceActivity daemon → no frame is produced: the user sees the gradient background with no content and cannot interact. If the daemon is wedged the block is unbounded — this exact call is reported as deadlocking from app code on iOS 18 (Apple Developer Forums thread 761299 / FB14664238) — and the launch watchdog terminates the app (0x8badf00d), which the user experiences as "the app crashes when I open it". In the ordinary case it is a launch hitch proportional to the daemon round-trip, on the critical path of every launch.

**User impact**

Launch-time freeze or, when the DeviceActivity daemon is slow/wedged, a watchdog kill that looks like a crash-on-open — the same class of stall that was already fixed once for the arm/confirm path, on a path every user hits on every launch.

**API semantics relied on**

Relied on: `DeviceActivityCenter` calls are synchronous cross-process calls — asserted by the repo's own comment (Schedule.swift:18-21) and by status.md's fixed "Arm-confirm UI stall" entry, which is direct evidence for start/stop. Apple's docs for `DeviceActivityCenter.activities` say nothing about cost or threading, so the transfer of that property to `activities` is by construction (same class, same daemon), supported by Apple Developer Forums thread 761299 (FB14664238) where a developer reports "My application code … seems to deadlock on calling DeviceActivityCenter.activities" on iOS 18 (not reproducible on 17.6). I could not confirm a documented cost bound, hence medium confidence; the on-device check is a launch-time main-thread trace in Instruments.

<details><summary>Ruled out by this lens</summary>

CONCURRENCY OF THE `Schedule` QUEUE — clean, no bug found. All three entry points dispatch onto the single static serial queue (`Schedule.swift:23`; used at `:32`, `:51`, `:64`), and every Model-derived value is computed on the calling (main) thread before the dispatch: the `DeviceActivitySchedule` is built at `:26-28`/`:48-50` outside the closure, and `model.activityEvent()` / `model.notificationEvents()` are evaluated at the call sites (`ContentView.swift:63`, `:65-66`, `:109`, `:239-240`). So the comment's claim ("nothing here touches Model off-main") holds, and no `Model` state is read from the queue.

ORDERING UNDER RAPID INTERACTION (F4.9) — holds. Every mutation path goes through the same FIFO queue, so tap order is preserved: `performArm()` sets `isArmed = true` then enqueues (stop `.daily`, start `.daily`) (`ContentView.swift:76-80` → `Schedule.swift:32-40`); `stop()` sets `isArmed = false` then enqueues stop of `[.daily, .notificationSchedule]` (`ContentView.swift:82-86`). arm→disarm→arm therefore lands as start,stop,start and the terminal daemon state agrees with the terminal flag — no last-write-loses, no reordering. `applySchedule()`'s two enqueues (daily then notification) are also ordered relative to each other.

SLIDER-DRAG STORM — not a storm. `ScheduleRangeSlider` assigns `start`/`end` on every touch event (`:134-136`), but `.onChange(of: model.start)` only fires on an actual value change (5-minute snap at `:50`), and the first change calls `stop()`, which clears `isArmed`; `disarmIfArmedInactive()` is guarded on `model.isArmed` (`ContentView.swift:90-92`), so subsequent 5-minute steps in the same drag are no-ops. A drag therefore enqueues at most one stop, not one per step. The per-touch-event `UserDefaults` write in `Model.start.didSet` (`Model.swift:43-45`, plus a fresh `UserDefaults(suiteName:)` each time) is real churn but these are in-memory writes with a coalesced flush; I could not construct a user-visible stall trace, so I am not reporting it.

SELECTION-EDIT STORM — not a storm. `.onChange(of: model.selectionToRestrict)` → `applySchedule()` enqueues 4 XPC calls plus a main-thread PropertyList encode and `defaults.synchronize()` (`ContentView.swift:218-229`, `Model.swift:83-90`), which would be unbounded if the picker updated its binding per tap — but `.familyActivityPicker(isPresented:selection:)` (`AppCard.swift:68`) commits the selection once when the picker is dismissed, not per tap (Apple docs for `familyActivityPicker(isPresented:selection:)`; corroborated on Apple Developer Forums thread 702260). So N app taps = one re-register.

MAIN-THREAD ManagedSettingsStore WRITES — examined, not reported for lack of evidence. `stop()` calls `model.clearRestrictions()` on the main thread (`ContentView.swift:85` → `Model.swift:100-104`, three `store.shield.*` setters), reachable mid-gesture via `disarmIfArmedInactive()`. I could find no Apple documentation or credible report that these setters are slow enough to stall a frame, so per the evidence bar I am not claiming it.

@MainActor BOUNDARIES — no cross-process actor hazard. `AccessController` is `@MainActor` (`AccessController.swift:18`) and is only touched from main-thread view callbacks (`ContentView.swift:61, 77, 106, 261`, `ScreenTimeShieldApp.swift:102`); the extension never links it and reads only the plain cached `enforcement_allowed` bool (`DeviceActivityMonitorExtension.swift:42-44`), so there is no shared mutable StoreKit state across the process boundary. The extension does mutate `Model`'s `@Published selectionToRestrict` from a non-main DeviceActivity callback (`:61` → `Model.swift:59-64`), but that process has no SwiftUI observers, so there is no user-visible consequence.

QA PATH — `AccessController.qaResetToFreshInstall()` calls `DeviceActivityCenter().stopMonitoring()` on the main actor, bypassing the serial queue (`AccessController.swift:188`), but the only entry point is commented out (`SettingsView.swift:26-29`) and status.md records that as the accepted production posture, so I am not reporting it.

APP-SUSPENSION WINDOW — considered and dropped as unfalsifiable from source: `setSchedule` does stop-then-start inside one queue block (`Schedule.swift:34-36`), so a suspension landing between the two calls would leave `.daily` unregistered, but the two calls are back-to-back and the state self-heals on the next foreground, and I cannot evidence the suspension timing.

</details>

<details><summary>Noted outside lens (uninvestigated)</summary>

`.hourly` and `.daily` share one `insideInterval` flag and one `ManagedSettingsStore`, so an hourly quick block that overlaps a daily block silently ends it: tap "Restrict for next hour" at 08:50 with a 09:00–17:00 block armed → at 09:50 `intervalDidEnd(.hourly)` runs `clearRestrictions()` + `insideInterval = false` (DeviceActivityMonitorExtension.swift:74-78) while the daily interval is still running and nothing re-applies the shields → full bypass for the rest of the day (F4.13). Reachable with no concurrency involved.
`ContentView.onAppear` → `loadSelection()` (:246) mutates `selectionToRestrict`, which fires `.onChange` (:218) → `applySchedule()`, so every cold launch with a saved selection does an unconditional stop+start of `.daily` — including mid-active-block — with `startMonitoring` errors swallowed (Schedule.swift:37-39); a failed re-register strands `insideInterval == true` with nothing registered (F4.3/F4.6/F4.8).
`stop()` stops only `[.daily, .notificationSchedule]` (ContentView.swift:84) — an active or armed `.hourly` survives "Stop blocking" (F4.7).
`.onChange(of: model.notificationsEnabled)` (ContentView.swift:236-243) registers the notification schedule whenever the refocus toggle goes on and apps are selected, even when nothing is armed, so that activity can exist with no block (F4.12).
`SettingsView.swift:19` binds a `Toggle` to `$model.notificationsEnabled` (`@AppStorage` on a class) — same missing-invalidation mechanism as my first finding: the toggle may not visibly move, and ContentView's `.onChange` for it only runs when something else re-renders ContentView (e.g. the sheet dismissing).
`ScheduleCard.swift:27` passes `now: Date()` captured at render time, so the "now" marker on the locked slider never advances during a session.

</details>

---

## F4 · F4:cross-process

### `F4-XPROC-01` — Re-registering .daily while a block is running makes the extension tear the block down (reachable by a cold launch during a block)

- **Severity** Important · **Confidence (self-reported)** medium · **Invariant** F4.8 · **Needs device** yes
- **Anchor** `ScreenTimeShield/ContentView.swift:228`

**Mechanism**

`applySchedule()` (ContentView.swift:59-68) always goes through `Schedule.setSchedule`, whose first act is `center.stopMonitoring([activityName])` (Schedule.swift:34) before `startMonitoring`. Apple documents that stopping monitoring of an activity **with an ongoing interval** ends the activity, i.e. it delivers `intervalDidEnd`. In the extension process, `intervalDidEnd` is a global teardown: for `daily`/`hourly` it calls `model.clearRestrictions()` (nils every shield in the shared unnamed `ManagedSettingsStore`, Model.swift:100-104) and writes `inside_interval = false` (DeviceActivityMonitorExtension.swift:74-78). The app side has no idea this happened — it still holds `is_armed = true` and treats the stop→start pair as a harmless re-registration. There is no ownership/refcount tying the shared store + `inside_interval` flag to the activity that set them. The trigger is not exotic: `applySchedule()` is called from `.onChange(of: model.selectionToRestrict)` (ContentView.swift:218-229), and `onAppear` assigns `selectionToRestrict` via `model.loadSelection()` (ContentView.swift:246) — the singleton starts each process with an empty `FamilyActivitySelection` (Model.swift:40), so the first load is always a value change and always fires that onChange. `isArmed` is synced to true one line later (ContentView.swift:248) and onChange bodies run after that body pass, so the `guard model.isArmed` at ContentView.swift:60 passes.

**Failure trace**

User arms a 20:00–22:00 daily block. At 20:00 the extension applies the shields and writes inside_interval=true. At 20:30 the user (blocked out of Instagram) opens Unplug — cold launch. onAppear -> loadSelection() assigns the saved selection over the empty in-memory default -> @Published change -> .onChange(of: model.selectionToRestrict) fires -> validateRestriction() passes (saved == new) -> saveSelection() -> applySchedule() -> Schedule.setSchedule -> center.stopMonitoring([.daily]) on an ongoing interval -> extension process gets intervalDidEnd(.daily) -> clearRestrictions() + inside_interval=false. Persisted state: is_armed=true, inside_interval=false, ManagedSettingsStore empty, .daily re-registered for tomorrow. What the user sees: Instagram opens with no shield for the rest of the 20:30–22:00 window, and the CTA reads "Stop blocking" instead of "Blocking". Same trace with no launch needed: while blocked, tap "Add" on the app card (deliberately enabled during a block, AppCard.swift:36-42), add one app, Done -> same onChange -> same teardown, so the action that is supposed to only *grow* the enforced set empties it.

**User impact**

The unbypassable block ends early. Opening the app during a block (or adding an app to it) clears every shield for the remainder of the window — the core product promise fails, and it fails for the exact user who is most motivated to open the app mid-block.

**API semantics relied on**

Verified against Apple docs for DeviceActivityMonitor.intervalDidEnd(for:) (fetched via developer.apple.com JSON doc endpoint): "An activity ends when someone first uses the device outside the activity's scheduled time interval **or when your app stops monitoring an activity with an ongoing interval**. In other words, the system only invokes this method when the device is in use." The device is in use in this trace (the user just launched the app), so the callback is delivered. NOT confirmed: whether the immediately following `startMonitoring` re-delivers `intervalDidStart` when now is already inside the schedule. intervalDidStart's doc says "An activity starts when someone first uses the device within the activity's scheduled time interval", which reads as boundary-triggered; Apple forum answers say the system classifies such a schedule as already "ongoing". Worst case the shields stay off until 22:00; best case they are reapplied after a gap and `inside_interval` still flaps false->true. Callback ordering between the stop and the start is also unguaranteed. Confidence lowered to medium for that reason.

### `F4-XPROC-02` — The one-hour quick block's intervalDidEnd clears a concurrently-active scheduled block

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F4.13 · **Needs device** yes
- **Anchor** `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:74`

**Mechanism**

`intervalDidEnd` treats `daily` and `hourly` identically (DeviceActivityMonitorExtension.swift:74-78): either one clears the whole shared `ManagedSettingsStore` and writes `inside_interval = false`. The two activities are independent registrations (Schedule.swift:29 picks the name purely off `repeats`) and can be monitored at the same time — nothing in the app prevents registering `.hourly` while `.daily` is armed: `isQuickRestrictDisabled` (ContentView.swift:31-33) only blocks quick-restrict when `insideInterval` is already true, which is false while the daily block is armed-but-not-yet-active, and `performRestrictHour` (ContentView.swift:105-110) does not consult `isArmed`. So the hourly block's end becomes an unconditional disarm of whatever else was enforcing.

**Failure trace**

User has a daily block armed for 20:00–22:00. At 19:30 they tap "Restrict for next hour" and confirm -> .hourly registered 19:30–20:30; extension: intervalDidStart(.hourly) -> shields on, inside_interval=true. At 20:00 intervalDidStart(.daily) -> shields on, inside_interval=true. At 20:30 intervalDidEnd(.hourly) fires (or fires the next time the device is used) -> activity.rawValue == "hourly" -> clearRestrictions() + inside_interval=false. Persisted state: is_armed=true, inside_interval=false, empty ManagedSettingsStore, .daily still registered (its intervalDidEnd only comes at 22:00). What the user sees: from 20:30 to 22:00 every restricted app opens normally, and the app shows "Stop blocking" / "Block inactive" instead of "Blocking".

**User impact**

A determined user has a repeatable, one-tap way to punch a hole through their own scheduled block: fire a one-hour quick block that ends inside the scheduled window and the scheduled block dies with it. Users can also hit it accidentally by using quick-restrict shortly before their scheduled block starts.

**API semantics relied on**

Relies on (a) DeviceActivityCenter supporting concurrent named activities — documented (stopMonitoring takes an array of names; `activities` is a list, as ContentView.swift:248 itself assumes), and (b) intervalDidEnd firing at the end of a non-repeating hourly interval — documented for DeviceActivityMonitor.intervalDidEnd(for:), with the caveat "the system only invokes this method when the device is in use", which only delays the teardown to the user's next pickup (still inside the daily window in this trace).

### `F4-XPROC-03` — The app never observes the extension's inside_interval write, so a block starting under a foregrounded app leaves the UI unlocked and lying

- **Severity** Important · **Confidence (self-reported)** medium · **Invariant** F4.5 · **Needs device** yes
- **Anchor** `ScreenTimeShield/Model.swift:25`

**Mechanism**

`insideInterval` is `@AppStorage("inside_interval", store: app-group defaults)` on the shared `Model` singleton (Model.swift:25). `Model.swift` is compiled into both the app and the monitor extension (project.pbxproj:590, :652), so each process has its own instance and only the extension ever writes the flag (DeviceActivityMonitorExtension.swift:34-37). @AppStorage's change observation is built on `UserDefaults.didChangeNotification`, which is documented not to be posted for changes made outside the current process — so the extension's write never fires `Model.objectWillChange` in the app process. Every gate that protects an active block in the UI is a value captured during the *previous* body pass: `ScheduleCard` passes `locked: model.insideInterval` into `ScheduleRangeSlider`, where `locked` decides whether the drag gesture exists at all (`.gesture(locked ? nil : DragGesture...)`, ScheduleRangeSlider.swift:129), and `.disabled(model.insideInterval)` on the mode Picker (ScheduleCard.swift:21); `PinnedActions` gets `primaryDisabled`/`primaryTitle` as plain parameters (ContentView.swift:199-205). With no re-render, all of them stay in their "inactive" configuration for the whole foreground session.

**Failure trace**

User arms a 20:00–22:00 block at 19:55 and keeps the app open. At 20:00 the extension applies the shields and sets inside_interval=true in the app-group defaults. No didChangeNotification crosses the process boundary, so the app's body is never re-evaluated: StatusBanner still shows the grey dot and "Block inactive" (StatusBanner.swift:26-33), AppCard still says "Will be restricted", ScheduleCard still shows no lock caption, the mode Picker is still enabled and the slider handles still carry live drag gestures, and the CTA still reads "Stop blocking" and is enabled. The user drags a handle -> `model.start` (a genuine @Published, Model.swift:41-46) is written and persisted mid-block, violating "while insideInterval the schedule window cannot change"; the registered .daily schedule keeps the old interval, so the window the app displays no longer matches what is enforced. They tap the enabled "Stop blocking" button -> `onPrimary` (ContentView.swift:50-53) re-reads the flag and silently returns, so the button looks alive and does nothing.

**User impact**

During the window a block starts while the app is on screen, the user is told "Block inactive", can edit a schedule that is supposed to be frozen, and gets a dead-feeling primary button. If @AppStorage also caches its value in the long-lived singleton (unverified), the same stale read reaches `disarmIfArmedInactive()` (ContentView.swift:90-92) and a single slider drag calls `stop()` — clearing the shields and unregistering .daily mid-block, i.e. a full early exit from a block that is advertised as unstoppable.

**API semantics relied on**

Confirmed: `UserDefaults.didChangeNotification` is documented as not posted for changes made outside the current process, and @AppStorage/shared-appStorage is known to miss cross-process writes for exactly that reason (pointfreeco/swift-composable-architecture discussion #3459 / issue #3439, which quote the doc and switched to KVO to fix it). Confirmed the other way: @AppStorage declared in an ObservableObject *does* drive objectWillChange for same-process writes (fatbobman, "UserDefaults and Observation in SwiftUI"), which is why the in-app writes work and only the cross-process one is missed. NOT confirmed: whether AppStorage's internal storage caches, i.e. whether a *read* in the app process returns the extension's fresh value. That determines whether the consequence is only the stale/unlocked UI (certain) or also the `disarmIfArmedInactive()` -> `stop()` early exit (possible). Needs a device: foreground the app across an interval start.

### `F4-XPROC-04` — The refocus notification schedule can be registered while nothing is armed, and then outlives every block

- **Severity** Nit · **Confidence (self-reported)** medium · **Invariant** F4.12 · **Needs device** yes
- **Anchor** `ScreenTimeShield/ContentView.swift:236`

**Mechanism**

The notification schedule is only ever torn down by `stop()` (ContentView.swift:82-86) or by switching the toggle off (ContentView.swift:242). But the register branch at ContentView.swift:236-241 is gated on `newValue && !model.isEmpty()` only — it never checks `model.isArmed`, unlike `applySchedule()` which does (ContentView.swift:60). So flipping "Send refocus notifications" on while disarmed registers a `.notificationSchedule` whose interval is derived from a block window that is not registered with the system, together with the 10 usage-threshold events (Model.swift:126-139). The extension then fires the refocus notifications from `eventDidReachThreshold` (DeviceActivityMonitorExtension.swift:96-107), which checks `notificationsEnabled` but has no way to know no block exists. Nothing in the app ever stops it again unless the user re-toggles the setting or arms and then stops.

**Failure trace**

User selects apps, arms a block, later taps "Stop blocking" -> stop() stops [.daily, .notificationSchedule]; the user is now fully disarmed. They open Settings and toggle refocus notifications off, then on again (SettingsView.swift:19 writes model.notificationsEnabled) -> .onChange(of: model.notificationsEnabled) -> newValue true and selection non-empty -> Schedule.setNotificationSchedule(restrictionStart: 20:00, restrictionEnd: 22:00, events: 10 thresholds) -> .notificationSchedule registered for 22:00->20:00 daily. Persisted state: is_armed=false, no .daily registered, but .notificationSchedule live. What the user sees: "You've been using a restricted app for 5 minutes, tap here to regain focus" push notifications every day, indefinitely, for apps that are not blocked and a schedule they explicitly stopped.

**User impact**

Nagging refocus notifications from a block that no longer exists, with no obvious way to make them stop (the primary CTA won't clear it — only re-toggling the setting will). This is a concrete mechanism for the undocumented "Notifications bug" open in status.md.

**API semantics relied on**

Assumes DeviceActivity keeps a registered repeating activity alive across launches until stopMonitoring — the app's own `onAppear` resync (`DeviceActivityCenter().activities.contains(.daily)`, ContentView.swift:248) depends on that same property. Also assumes @AppStorage-in-ObservableObject fires objectWillChange for the same-process toggle write so ContentView's `.onChange` runs (confirmed above); if it did not, the register branch simply never runs and this finding collapses.

<details><summary>Ruled out by this lens</summary>

Ruled out inside the cross-process lens:

- **Extension calling `loadSelection()` before `setRestrictions()` (DeviceActivityMonitorExtension.swift:60-62)** — correct as written: the extension's `Model` singleton starts empty in its own process, so the reload is required, and `savedSelection()` reads the app-group defaults each time (Model.swift:66-71). The one real wart is that `loadSelection()` also *writes* `has_selection = true` (Model.swift:61-63) from the extension, resurrecting the flag ContentView deliberately cleared at :253 — but the toast is gated on `selectionIsInvalidated()` (`hasSelection && isEmpty()`), and in the path where the extension sets it the selection is non-empty, so no user-visible consequence. Not reported. The related "tokens decode empty -> extension applies nil shields while writing inside_interval=true" case needs an invalidated-token device state I can't demonstrate from source, so I left it out rather than guess.
- **`saveSelection()`/`insideInterval` write visibility (synchronize)** — `saveSelection` (Model.swift:83-90) and the extension's setter (DeviceActivityMonitorExtension.swift:35-36) both call `synchronize()`; the AppStorage-backed booleans don't, but on modern iOS `synchronize()` is a no-op for durability and does not affect cross-process read freshness, so I found no defect attributable to the mixed usage itself (the defect is the *notification*, reported as candidate 3).
- **Two `Model` singletons with separate `@Published selectionToRestrict`** — the divergence is benign: the app is the only writer (`saveSelection`), and the extension re-reads from defaults on every `intervalDidStart`. The extension never persists `selectionToRestrict`.
- **`onAppear` arm resync (ContentView.swift:248)** — `DeviceActivityCenter().activities.contains(.daily)` is a same-process query of the system daemon, not app-group state, so it is immune to the cross-process staleness in candidate 3, and it correctly re-derives F4.1 on launch. It is also what makes candidate 1's `guard model.isArmed` pass, but that is a consequence, not a defect here.
- **`.hourly` never appearing in any `stopMonitoring` list** (`stop()` only stops `[.daily, .notificationSchedule]`, ContentView.swift:84) — I looked for a trace where a stranded `.hourly` re-applies restrictions after a disarm. Every path I could build requires the user to tap "Block for an hour" and then "Stop blocking" inside the DeviceActivity callback latency window (quick-restrict is disabled once `insideInterval` is true), i.e. two contradictory taps seconds apart, and the outcome ("you get the hour you just asked for") isn't clearly wrong. I could not write an honest failure trace, so not reported.
- **`stop()` never writing `insideInterval = false` (ContentView.swift:82-86)** — looks like a latent lock-out (F4.3: `inside_interval` true with nothing registered to clear it), but Apple documents that stopping monitoring of an activity with an ongoing interval ends the activity, so the extension's `intervalDidEnd` clears the flag for us. Fragile (it relies on an undocumented-in-stopMonitoring behaviour plus "only when the device is in use") but I could not turn it into a reproducible lock-out, so it stays as an observation rather than a finding.
- **Notification-schedule register/stop churn in `Schedule.setNotificationSchedule`** — the same stop→start pattern as candidate 1, but the extension's `intervalDidEnd` ignores any activity that isn't `daily`/`hourly` (DeviceActivityMonitorExtension.swift:74), so tearing down `.notificationSchedule` has no effect on enforcement.
- **`Schedule`'s serial queue (Schedule.swift:23-40)** — start/stop ordering within the app process is genuinely preserved and off-main; the ordering problem I did find is between the *extension's* callbacks and the app's writes, which no app-side queue can fix (folded into candidate 1).

</details>

<details><summary>Noted outside lens (uninvestigated)</summary>

- F9 lens: trial expiry only flips the cached `enforcement_allowed` gate (AccessController.swift:118). Nothing calls `stopMonitoring`, so an expired user's `.notificationSchedule` keeps firing refocus notifications for apps that are no longer blocked, and `.daily` keeps firing `intervalDidStart` (harmlessly skipped at DeviceActivityMonitorExtension.swift:56-59) — "armed but silently unenforced" plus nagging, which is the F9.11 shape.
- F4.6 (known-open in status.md): `Schedule` swallowing `startMonitoring` errors is worse than "a block silently fails to register" — since the throw happens *after* `stopMonitoring` (Schedule.swift:34-39), a throw during a mid-block re-register leaves nothing registered while the app still shows armed.
- F3 lens: `performRestrictHour` (ContentView.swift:105-110) passes absolute dates through `components(from:)` (hour/minute only), so a 23:30 quick block becomes intervalStart 23:30 / intervalEnd 00:30 with `repeats: false` — worth someone checking what a non-repeating wrapping interval does.
- F3 lens: `dateAtMinute`'s `?? Date()` (ScheduleRangeSlider.swift:41) and the `%02d:00` hour axis vs locale-aware handle pills (ScheduleRangeSlider.swift:54-56 / :160) are the F3.4 / F3.8 items, uninvestigated.

</details>

---

## F4 · F4:hostile-user

### `F4-HOSTILE-01` — "Restrict for next hour" kills the nightly block: the hourly activity's intervalDidEnd clears the shared shield store while the daily block is still in progress

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F4.13 · **Needs device** yes
- **Anchor** `CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:74`

**Mechanism**

`.daily` and `.hourly` are two separately-registered DeviceActivity activities (ScreenTimeShield/Schedule.swift:29 picks the name from `repeats`), and `performRestrictHour()` (ScreenTimeShield/ContentView.swift:105-110) registers `.hourly` without touching `.daily`. Quick-restrict is only gated on `insideInterval`, not on `isArmed` (ScreenTimeShield/ContentView.swift:31-33), so it is tappable while a daily schedule is armed but not yet active. Both activities are served by the same extension, which holds a single **unnamed** `ManagedSettingsStore()` (CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:24, ScreenTimeShield/Model.swift:18) — the store is shared app-wide, so there is one shield set, not one per activity. `intervalDidEnd` then unconditionally wipes it and clears the global flag for *either* name: `if activity.rawValue == "daily" || activity.rawValue == "hourly" { model.clearRestrictions(); model.insideInterval = false }` (CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:74-78). There is no per-activity bookkeeping and nothing in the main app ever re-applies shields — `Model.setRestrictions()` has exactly one caller, `intervalDidStart` (CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:62) — so once cleared, the daily block stays unenforced until the *next* day's intervalStart.

**Failure trace**

Nightly block armed for 22:00–07:00 (`isArmed == true`, `.daily` registered, `insideInterval == false`). At 21:30 the user taps "Restrict for next hour" (enabled: ContentView.swift:31-33 only blocks on insideInterval/expired/no-apps), confirms the alert (ContentView.swift:271-284) → `performRestrictHour()` registers `.hourly` for 21:30→22:30 (ContentView.swift:107-109). 21:30 `intervalDidStart(.hourly)` → setRestrictions + `inside_interval = true`; user is shielded. 22:00 `intervalDidStart(.daily)` → same shields re-applied, flag already true. 22:30 `intervalDidEnd(.hourly)` fires → Extension:74-78 runs `clearRestrictions()` (shield.applications/webDomains/applicationCategories = nil, Model.swift:100-104) and writes `inside_interval = false`. Persisted state: `is_armed = true`, `inside_interval = false`, `.daily` still registered, **shield store empty**. What the user sees: from 22:30 to 07:00 every "blocked" app opens normally; the app's banner reads "Block inactive" (StatusBanner.swift:33) and the primary CTA is the enabled "Stop blocking" (ContentView.swift:39, :46), so they can also disarm outright. Repeatable every night: trade one hour of blocking for the whole rest of the night.

**User impact**

The core product promise is defeated by a documented, one-tap, in-app sequence — tap the quick action shortly before your scheduled block, sit out one hour, and the scheduled block is silently dead for the remainder of the day. Also hits non-hostile users by accident (default 09:00–17:00 schedule + quick-restrict at 08:45 kills the whole workday block at 09:45), and they get no indication their block stopped enforcing.

**API semantics relied on**

Relies on (a) `ManagedSettingsStore()` (unnamed) being one shared store across app + DeviceActivityMonitor extension, so clearing it in one activity's callback removes the shields applied for another — confirmed by Apple's guidance that from iOS 16 the unnamed store is shared between app and extension and that you must use `ManagedSettingsStore(named:)` to keep multiple activities' settings distinct (Apple Developer Forums thread 726494, summarized via search); (b) DeviceActivityCenter monitoring two differently-named activities concurrently and delivering intervalDidStart/intervalDidEnd per activity — this is what the code itself assumes (daily + notificationSchedule are co-registered) and matches the DeviceActivityCenter docs. Residual risk: Apple Developer Forums thread 820956 reports intervalDidEnd sometimes not firing for *non-repeating* schedules; if it never fires, this exact trace is replaced by the opposite defect (the hourly block never ends and `inside_interval` stays stuck true). Either way the collision is unhandled. Device confirmation recommended.

### `F4-HOSTILE-02` — Revoking Screen Time access mid-block permanently bricks the app: `inside_interval` stays true forever and no code path can ever clear it

- **Severity** Important · **Confidence (self-reported)** medium · **Invariant** F4.3 · **Needs device** yes
- **Anchor** `ScreenTimeShield/ContentView.swift:45`

**Mechanism**

`inside_interval` is written only by the monitor extension (CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:63 sets it, :77 clears it). The main app never clears it: `stop()` (ScreenTimeShield/ContentView.swift:82-86) writes `isArmed = false`, stops monitoring and clears shields but leaves the flag alone, and `onAppear` re-syncs only `isArmed` from `DeviceActivityCenter().activities` (ScreenTimeShield/ContentView.swift:246-254) — it never reconciles `insideInterval` against reality. The one other clearer, `qaResetToFreshInstall()` (ScreenTimeShield/AccessController.swift:199), is unreachable in production because its only entry point is commented out (ScreenTimeShield/SettingsView.swift:25-29). Meanwhile every control is gated on that stale flag: `primaryDisabled` returns true on `insideInterval` *before* it looks at `isArmed` (ScreenTimeShield/ContentView.swift:45), `onPrimary` early-returns (:51), quick-restrict is disabled (:32), and the schedule card + slider gestures are dead (ScreenTimeShield/ScheduleCard.swift:21, ScreenTimeShield/ScheduleRangeSlider.swift:129). So if the extension's `intervalDidEnd` never runs, the app has no way back: no activity can be registered, therefore no intervalDidEnd, therefore the flag is true forever.

**Failure trace**

23:00, block active (`inside_interval = true`, shields applied). User goes Settings → Unplug → toggles off Screen Time access (Face ID / passcode). iOS revokes the app's FamilyControls authorization: all restrictions the app applied are removed and its monitoring is torn down — apps open immediately (escape #1, platform-level). The extension is never invoked again for this interval, so `inside_interval` is left `true` in group.screentimeshield. User re-enables Screen Time access (or just relaunches Unplug) → `onAppear` sets `isArmed = DeviceActivityCenter().activities.contains(.daily)` (ContentView.swift:248) and leaves `inside_interval` alone. Persisted state: `inside_interval = true`, no daily/hourly activity registered, shield store empty. What the user sees, forever: StatusBanner "Block active", app card header "Restricted" (AppCard.swift:27), a locked, greyed-out "Blocking" button (PinnedActions.swift:22-35), "Restrict for next hour" greyed out, and "Schedule locked while a block is active" — while nothing whatsoever is enforced. No sequence of taps recovers; only deleting and reinstalling the app does.

**User impact**

A single Settings toggle (the obvious escape a motivated user reaches for) both frees their apps and permanently disables the product: the app can never arm again and shows a fake "Block active" state indefinitely. Any legitimate user who turns Screen Time off for an unrelated reason is bricked the same way, and the false "Blocking" display means they believe they are protected when they are not.

**API semantics relied on**

Depends on user-initiated revocation of individual FamilyControls authorization from Settings (a) existing and (b) removing the app's applied restrictions and stopping its DeviceActivity monitoring. Apple Developer Forums thread 727291 confirms a per-app Screen Time toggle in Settings gated only by Face ID/passcode and that disabling it immediately drops all restrictions imposed by the third-party app; thread 746701 confirms the per-app toggle exists and that `authorizationStatus` reporting after it is inconsistent (may still read `.approved`). I could not fetch the `revokeAuthorization` docs text to confirm monitoring is also cancelled — if monitoring survives, the daily interval's intervalDidEnd would eventually clear the flag and the lockout is temporary rather than permanent (hence medium confidence). Note this also contradicts status.md line 6 ("There is no per-app Screen Time toggle in iOS Settings"), which is why the lockout consequence is not recorded as known: the existing status.md entry only covers showing PermissionDeniedView, not the stranded `inside_interval`.

### `F4-HOSTILE-03` — The disarm lock trusts a cross-process flag instead of the clock, so "Stop blocking" stays live after the block's start instant — and the stop path leaves `inside_interval` stuck true

- **Severity** Important · **Confidence (self-reported)** medium · **Invariant** F4.13 · **Needs device** yes
- **Anchor** `ScreenTimeShield/ContentView.swift:43`

**Mechanism**

Whether the block is locked is decided purely by `model.insideInterval` (ScreenTimeShield/ContentView.swift:43-53), which is only ever written by the out-of-process monitor extension at `intervalDidStart` (CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:63). The app never derives activeness from the schedule itself even though it already has the exact helper and uses it two functions later: `ScheduleMath.windowContains(now:start:end:)` handles wrapping windows and is called for the risk confirm at ScreenTimeShield/ContentView.swift:126-128. So between the scheduled start instant and the system actually launching the extension, the app believes no block is active and `stop()` is fully reachable: it de-registers `.daily` (ScreenTimeShield/ContentView.swift:84) and clears shields (:85). Two aggravating factors: (1) `insideInterval` is `@AppStorage` on a plain `ObservableObject` (ScreenTimeShield/Model.swift:25) — not `@Published`, so the extension's write publishes nothing and the foreground UI is never invalidated; the button keeps rendering the enabled "Stop blocking" (:39, :46) until some unrelated state change forces a re-render. (2) `stop()` never writes `insideInterval = false` (:82-86) — the design assumes it can't run while true, so if it does, the flag is stranded true with nothing registered to clear it (same dead-end as F4.3).

**Failure trace**

Daily block armed 22:00–07:00. At 21:55 the user opens Unplug and leaves it foregrounded; the CTA renders "Stop blocking", enabled. 22:00:00 the daily interval begins; iOS has not yet launched the DeviceActivityMonitor extension, so `inside_interval` is still false and no shields are applied. The UI does not refresh at 22:00 either (Model.swift:25 publishes nothing). User taps the still-enabled "Stop blocking" → `onPrimary` (:50-53) sees `insideInterval == false`, `isArmed == true` → `stop()` → `isArmed = false`, `Schedule.stopMonitoring([.daily, .notificationSchedule])` (Schedule.swift:63-67), `clearRestrictions()`. Outcome A (stop lands before the callback): `.daily` is gone, nothing is applied, tonight's block simply never happens — UI shows "Start blocking" / "Block inactive", and the user's apps stay open all night. Outcome B (the callback lands after the stop): the extension re-applies shields and writes `inside_interval = true`, but `.daily` is no longer monitored so `intervalDidEnd` never comes — shields stay applied past 07:00 and the app is stuck showing a locked "Blocking" CTA with no way to register anything that could clear it.

**User impact**

A motivated user can cancel a block after its scheduled start time by keeping the app open at the boundary and tapping Stop — the lock is only as prompt as the extension launch, and the UI actively invites the tap because it never refreshes at the start instant. In the losing branch the same tap strands the user shielded and locked out indefinitely instead.

**API semantics relied on**

Depends on intervalDidStart delivery latency after the scheduled start (out-of-process extension launch, not instantaneous; Apple Developer Forums threads 819224 and 724437 report delayed or missing intervalDidStart). Also assumes `@AppStorage` in a non-View class provides no cross-process change publishing (documented SwiftUI behaviour: AppStorage is a DynamicProperty designed for View invalidation, and UserDefaults change notifications are not delivered across processes) — the getter itself does read through to the shared suite, so the guard is value-correct but only as fresh as the extension's write. Window length needs on-device measurement.

<details><summary>Ruled out by this lens</summary>

Shield buttons — CustomShieldAction/ShieldActionExtension.swift:14-56: all three overloads (application, webDomain, category) answer `.close` for both primary and secondary; the only bypass line (`ManagedSettingsStore().shield.applications = nil`) is commented out in all three. No escape.

Removing apps from an active block — ContentView.swift:218-229 + Model.validateRestriction() (Model.swift:74-81): a removal fails the subset check and is reverted from the persisted copy with a toast. The guard compares against `savedSelection()`, which during a block is always a superset-or-equal of what is enforced (adds are persisted immediately at :226, the extension only ever reads the same store), so it is strictly conservative — I could not construct a removal that passes. Removing *all* apps also fails (empty intersection). Defeated.

Editing the window/mode during a block — ScheduleCard.swift:21 disables the mode picker and ScheduleRangeSlider.swift:129 sets the drag gesture to `nil` when `locked`, so no write to model.start/end is reachable; and even if one were, `disarmIfArmedInactive()` (ContentView.swift:90-92) no-ops while insideInterval, and start/end changes never re-register `.daily` (applySchedule is not called from :233-235). Defeated.

Force-quit / relaunch during a block — ContentView.swift:245-255 re-derives only `isArmed`; `inside_interval` survives in the app group (Model.swift:25) so the CTA stays locked, and shields live in ManagedSettings independent of the app process. No escape (but see candidate 2 for the flip side of never reconciling that flag).

Cancelling "Restrict for next hour" — once `inside_interval` flips, both the primary CTA (ContentView.swift:45, :51) and the quick action (:32) are disabled, and `stop()` is the only clearRestrictions caller in the app. Not cancellable by any tap. Noted but not reported: `stop()` stops only `[.daily, .notificationSchedule]` (ContentView.swift:84) and never `.hourly`, so a pending hourly still lands after a Stop — that direction only makes the block stronger.

Toggling refocus notifications mid-block — ContentView.swift:236-244 only touches `.notificationSchedule`, and the extension's interval callbacks ignore that name (Extension:53, :74), so it can neither apply nor clear shields. Defeated.

Offline / airplane mode — enforcement reads the cached `enforcement_allowed` gate which defaults to `true` when absent (Extension:42-44) and is only rewritten by `recomputeAccessState()` (AccessController.swift:117-118). No network dependency in the arm/enforce path. Defeated.

Trial expiry mid-block — the gate is checked only in `intervalDidStart` (Extension:56-59); `intervalDidEnd` is ungated, and nothing in the app clears shields on expiry, so an in-progress block runs to its natural end. Expiring the trial (even by clock-forwarding) does not end the current block.

QA overrides — `qaResetToFreshInstall()` / `QAMenuView` are only reachable from the commented-out Section at SettingsView.swift:25-29, and `UNPLUG_SKIP_FC` is scheme-only. Not a production vector.

Delete-and-reinstall — deleting the app removes its ManagedSettings and app-group container, so the block dies; this is platform-inherent for `.individual` FamilyControls (no code path could preserve it) and leaves no inconsistent state, so I treated it as an unavoidable escape hatch rather than a bug.

Device clock / timezone changes — `Schedule.components(from:)` (Schedule.swift:69-71) hands the system only hour+minute in the current calendar, so the schedule is pure local wall-clock with no absolute anchor, and nothing in the app re-validates an absolute end time. Moving the clock past intervalEnd plausibly makes the daemon fire intervalDidEnd early (a full escape), but I could not confirm how DeviceActivity re-evaluates in-progress intervals across a manual time/timezone change from Apple docs, and I refuse to report an escape whose decisive step I can only attribute to the daemon. Not reported; worth a device test (set clock forward 12h mid-block and see whether shields drop).

</details>

<details><summary>Noted outside lens (uninvestigated)</summary>

F4.8: adding an app during an active block calls `applySchedule()` (ContentView.swift:228) which does `stopMonitoring([.daily])` + `startMonitoring(.daily)` mid-interval (Schedule.swift:32-40) — if re-registering inside an in-progress interval does not schedule an intervalDidEnd for it, the block never ends and `inside_interval` stays true (same dead-end as candidate 2). Uninvestigated.
F4.6: `performRestrictHour` after 23:00 hands a non-repeating schedule with intervalStart > intervalEnd (e.g. 23:15 → 00:15, Schedule.swift:26-29); if the system rejects a wrapping non-repeating schedule the throw is swallowed at Schedule.swift:37-39, so the confirmed "blocks everything for the next hour" tap silently does nothing at exactly the late-night hour the product targets.
F4.4: adds made during an active block are persisted but never enforced until the next intervalDidStart, since `setRestrictions()` is only called there (Extension:62) — the token set grows on disk, not in the shield.
F3.11: `ScheduleMath.freeMinutes` uses `max(0, windowEnd - windowStart)` (ScheduleMath.swift:30), which is wrong for a wrapping window (end < start yields 0 → block mode reports 1440 free minutes), so the risk confirm can mis-fire.
Threat model: status.md line 6 asserts "There is no per-app Screen Time toggle in iOS Settings" — Apple Developer Forums threads 727291 and 746701 say there is one, gated only by Face ID/passcode, and that flipping it drops all of the app's restrictions. That assumption underpins several design decisions and is worth correcting.

</details>

---

## F9 · F9:storekit

### `F9-SK-01` — No Transaction.updates listener: transactions created outside the foreground buy call are never finished, and are only noticed on the next foreground

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F9.7 · **Needs device** no
- **Anchor** `ScreenTimeShield/Store.swift:13`

**Mechanism**

`Store` has no `init` and nowhere in the target is there a `Task` iterating `Transaction.updates` or `Transaction.unfinished` (grep for `Transaction.updates` across the repo returns zero hits). The single `transaction.finish()` call in the app is inside the foreground buy path at ScreenTimeShield/Store.swift:41, reachable only from `product.purchase()` returning `.success(.verified)`. Every other way a transaction can arrive — Ask-to-Buy approval (ScreenTimeShield/Store.swift:44 maps `.pending` to `false` and then forgets about it), an interrupted purchase completed later, a purchase made in the same account on another device, an offer-code redemption — produces a transaction that this app never sees in-process and therefore never finishes. The only entitlement recovery path is the periodic re-query `refreshPurchasedState()` (ScreenTimeShield/Store.swift:58-67) driven by scenePhase `.active` (ScreenTimeShield/ScreenTimeShieldApp.swift:101-102) and ContentView's `.task` (ScreenTimeShield/ContentView.swift:256-262). That re-query grants access but never finishes anything, so the transaction stays unfinished permanently. The repo's own test demonstrates the shape: ScreenTimeShieldTests/StoreTests.swift:68-74 simulates an out-of-app purchase with `session.buyProduct` and asserts `isPurchased`, with no finish anywhere.

**Failure trace**

Child device with Ask to Buy enabled. User taps "Unlock forever (€4.99)" -> PaywallView.buy() (ScreenTimeShield/PaywallView.swift:132-142) -> Store.purchase() -> `product.purchase()` returns `.pending` -> Store.swift:44-45 returns false -> spinner stops, paywall unchanged, no message. Parent approves 30s later while the app is still in the foreground -> StoreKit emits the transaction on `Transaction.updates` (documented) -> nothing is listening -> `isPurchased` stays false, `accessState` stays `.expired`, `enforcement_allowed` stays false in the app group (AccessController.swift:118). The user stares at the paywall with access already paid for until they background and re-foreground the app, which triggers refreshAccess(). Even after that, the transaction is never finish()ed, so StoreKit re-emits it as unfinished on every subsequent launch and continues to treat the content as undelivered.

**User impact**

A paid-for entitlement that arrives out-of-band is invisible until the app is backgrounded and re-foregrounded (on the paywall, the user has no idea the purchase went through), and the transaction is left permanently unfinished — the state Apple explicitly tells apps not to leave transactions in.

**API semantics relied on**

Verified against Apple docs: `Transaction.updates` — "receives transactions that occur outside of the app, such as Ask to Buy transactions, offer code redemptions, and purchases that customers make in the App Store. It also emits transactions that customers complete in your app on another device… Create a Task to iterate through the transactions from the listener as soon as your app launches. If your app has unfinished transactions, the Transaction.updates listener receives them once, immediately after the app launches. Without the Task to listen for these transactions, your app may miss them." And `Product.PurchaseResult.pending`: "If a pending purchase succeeds, StoreKit delivers the resulting Transaction in the transaction updates." I did not find an Apple statement about the concrete consequence of never finishing a non-consumable, so the impact I claim is limited to what is documented (undelivered content + repeated re-emission) plus the invariant F9.7 violation itself.

### `F9-SK-02` — purchase() collapses .pending and .success(.unverified) into a bare `false`, and the paywall renders `false` as "nothing happened" with no message

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F9.6 · **Needs device** no
- **Anchor** `ScreenTimeShield/Store.swift:40`

**Mechanism**

`Store.purchase()` returns `Bool`: ScreenTimeShield/Store.swift:40 turns a *successful charge that failed JWS verification* into `false`, and Store.swift:44 turns `.pending` (Ask to Buy / SCA awaiting approval) into the same `false`, indistinguishable from `.userCancelled`. In ScreenTimeShield/PaywallView.swift:136-141 `errorMessage` is only assigned in the `catch` branch; a returned `false` does nothing at all — no dismiss, no text, no state change. For the unverified case the state is also unrecoverable on that device: `refreshPurchasedState()` skips unverified results too (ScreenTimeShield/Store.swift:61 `guard case .verified … else { continue }`), so neither the foreground refresh nor Restore Purchase will ever grant access, and the transaction is never finished (the only finish() is Store.swift:41, which is skipped by the guard at :40).

**Failure trace**

Case 1 (pending): user taps "Unlock forever" -> Apple's "Ask Permission" sheet -> taps Ask -> sheet dismisses -> `purchase()` returns false -> `purchasing` flips back to false, `errorMessage` remains nil -> paywall looks exactly as before the tap. The user concludes the button is broken and taps it again (each tap re-issues an approval request). Case 2 (unverified): `product.purchase()` returns `.success(.unverified(...))`; the customer has been charged; Store.swift:40 returns false; PaywallView shows no error; `Transaction.currentEntitlements` yields the same unverified result which Store.swift:61 skips, so `isPurchased` stays false and `accessState` stays `.expired`; tapping Restore Purchase then displays "No previous purchase found." (PaywallView.swift:151).

**User impact**

An Ask-to-Buy user gets zero feedback that their purchase request was submitted; a user whose transaction fails verification is charged, permanently denied access on that device, and told they never bought anything.

**API semantics relied on**

Apple docs for `Product.PurchaseResult.pending`: "The purchase is pending, and requires action from the customer" (Ask to Buy). `VerificationResult.unverified` means StoreKit could not verify the JWS signature — the purchase itself still completed. `Transaction.currentEntitlements` emits `.verified`/`.unverified` results, so filtering to `.verified` is the correct revenue-integrity choice but leaves the user with no path and no explanation.

### `F9-SK-03` — Restore Purchase asserts "No previous purchase found." when AppStore.sync() actually failed (offline, or the user cancelled the Apple-ID prompt)

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F9.5 · **Needs device** no
- **Anchor** `ScreenTimeShield/Store.swift:53`

**Mechanism**

`Store.restore()` calls `try? await AppStore.sync()` (ScreenTimeShield/Store.swift:53) — the `try?` discards every error, including "no network" and "user cancelled the App Store authentication prompt that sync() presents". It then calls `refreshPurchasedState()`, which on a device whose local transaction cache is empty (fresh install / restored-from-backup device) finds nothing and sets `isPurchased = false` (Store.swift:66). `AccessController.restore()` (AccessController.swift:107-110) recomputes state and returns void — the failure is not propagated anywhere. PaywallView.restore() (ScreenTimeShield/PaywallView.swift:144-153) has only two branches: `hasFullAccess` -> dismiss, else -> `errorMessage = "No previous purchase found."`. A failed sync therefore renders as a positive factual claim about the user's purchase history.

**Failure trace**

Paid user reinstalls Unplug (or gets a new phone) while on a flaky connection or in Airplane Mode, is shown the paywall because `currentEntitlements` is empty locally, taps "Restore Purchase" -> `AppStore.sync()` throws -> error swallowed at Store.swift:53 -> `refreshPurchasedState()` finds no entitlement -> `hasFullAccess` false -> paywall displays "No previous purchase found." in the error colour. Same trace if the user dismisses the Apple-ID authentication sheet that sync() presents.

**User impact**

A customer who has already paid is told, definitively, that they have no purchase — the most likely reactions are buying again or filing a refund/support complaint, rather than retrying with a connection.

**API semantics relied on**

Verified against Apple docs: `AppStore.sync()` is `static func sync() async throws`, "displays a system prompt that asks users to authenticate with their App Store credentials", and should be called only in response to explicit user action. So it does throw on failure and can be interrupted by the user, and `try?` erases both cases.

### `F9-SK-04` — An unavailable/unverified AppTransaction silently demotes a grandfathered user to .expired and writes enforcement_allowed=false, so the DeviceActivity extension stops enforcing their block

- **Severity** Important · **Confidence (self-reported)** medium · **Invariant** F9.4 · **Needs device** yes
- **Anchor** `ScreenTimeShield/Store.swift:78`

**Mechanism**

`refreshGrandfatheredState` (ScreenTimeShield/Store.swift:70-81) claims in its catch comment to "leave prior value untouched", but the prior value at every cold launch is the declaration default `isGrandfathered = false` (ScreenTimeShield/Store.swift:17) — nothing persists it (grep: `isGrandfathered` appears only in Store.swift and the pure-logic helper; there is no app-group key for it, unlike `enforcement_allowed`). The `.unverified` branch at Store.swift:73 does the same thing via a bare `return`. So a failed or unverified AppTransaction read is indistinguishable from "not grandfathered". `AccessController.refreshAccess()` (AccessController.swift:93-99) then calls `recomputeAccessState()`, which for a grandfathered user whose `trial_start` is older than 7 days yields `.expired` and — the escalation — writes `kv.setBool(false, forKey: enforcement_allowed)` at AccessController.swift:118. The monitor extension reads exactly that key (CustomDeviceActivityMonitor/DeviceActivityMonitorExtension.swift:42-44) and returns early from `intervalDidStart` without applying restrictions (:56-59). Note that grandfathered users do get a trial clock: `performArm()` calls `access.startTrialIfNeeded()` unconditionally (ScreenTimeShield/ContentView.swift:77, also :61 and :106), regardless of access state.

**Failure trace**

Grandfathered user (original download before cutoverDate) updates to the IAP build, arms a daily block -> `trial_start` is written (ContentView.swift:77 -> AccessController.swift:84-90). Eight days later they cold-launch the app in Airplane Mode / with the Apple ID signed out / on a device where the app transaction isn't cached (e.g. after a reinstall) -> ContentView `.task` -> `refreshAccess()` -> `refreshPurchasedState()` finds nothing (they never purchased; correct) -> `refreshGrandfatheredState()` -> `try await AppTransaction.shared` throws -> catch, `isGrandfathered` stays false -> `recomputeAccessState()` -> `accessState = .expired` -> `enforcement_allowed = false` persisted in group.screentimeshield. User sees "Trial ended · Unlock Unplug" (TrialChip.swift) and the primary CTA now routes to the paywall (ContentView.swift:71). At the next schedule start the extension's `intervalDidStart` hits the `guard enforcementAllowed` at DeviceActivityMonitorExtension.swift:56 and returns, so no shields are applied and `inside_interval` is never set: StatusBanner still reads "Block inactive" and the restricted apps open normally.

**User impact**

A user promised permanent free access is shown a paywall and, worse, has their armed block silently not enforced for the duration of the outage — the exact failure F9.3/F9.4 were written to prevent, and a direct hit on the "cannot be bypassed" promise (deliberately going offline is a bypass).

**API semantics relied on**

Verified against Apple docs for `AppTransaction.shared`: "This property throws an error if the AppTransaction isn't available or if the user isn't authenticated with the App Store. Getting an AppTransaction may require network connectivity" (docs also point to `AppTransaction.refresh()` as the recovery path — the app never calls it). What I could not confirm from docs is how often the on-device cache is actually cold in the field, so the frequency (not the mechanism) is uncertain; hence medium confidence.

### `F9-SK-05` — If product loading fails, the paywall shows a permanently disabled buy button with no error and no retry

- **Severity** Nit · **Confidence (self-reported)** high · **Invariant** NEW · **Needs device** no
- **Anchor** `ScreenTimeShield/PaywallView.swift:102`

**Mechanism**

`loadProduct()` swallows its error into a `print` (ScreenTimeShield/Store.swift:23-29) and leaves `product == nil`. The paywall's only load attempt is `.task { await access.storeKit.loadProduct() }` (ScreenTimeShield/PaywallView.swift:117-119), and the buy button is `.disabled(purchasing || product == nil)` (:102) with the fallback title "Unlock forever" and no price (:125-130). No `errorMessage` is ever set for a load failure, and there is no retry affordance; the guard at ScreenTimeShield/Store.swift:34-35 that would re-load is unreachable because the button can't be tapped.

**Failure trace**

Expired user on a captive-portal / flaky network taps the trial chip -> paywall appears -> `Product.products(for:)` throws -> `product` stays nil -> the primary CTA renders greyed-out and unresponsive with no price and no explanation. The only escape is dismissing the paywall (which drops them back into an app whose blocks are gated off) and re-opening it to re-run `.task`.

**User impact**

A customer who wants to pay is presented with a dead button and no diagnosis; the app looks broken rather than offline.

**API semantics relied on**

`Product.products(for:)` is a throwing network call; no exotic semantics relied on.

<details><summary>Ruled out by this lens</summary>

Revocation/refund (F9.8): `refreshPurchasedState` checks `revocationDate == nil` (Store.swift:62) and Apple's docs for `Transaction.currentEntitlements` confirm "Products that the App Store has refunded or revoked don't appear in the current entitlements", so the check is redundant-but-correct and a refund does drop access at the next foreground refresh (ScreenTimeShieldApp.swift:101-102). Not reported — the only gap is the same missing-updates-listener latency already covered by candidate 1.

Double-finish / finish-more-than-once: the only `finish()` call site is Store.swift:41 and it is guarded by the `.success(.verified)` case, so no path finishes the same transaction twice. The "exactly once" half of F9.7 that fails is "at least once", which is candidate 1.

Purchase -> UI propagation: I checked whether a successful purchase can fail to reach the UI. `Store.purchase()` calls `refreshPurchasedState()` before returning (Store.swift:42), `AccessController.purchase()` recomputes state (AccessController.swift:101-105), the nested-ObservableObject forwarding at AccessController.swift:42-44 makes `Store`'s @Published changes re-render views observing AccessController, and PaywallView dismisses both on `ok` (PaywallView.swift:138) and on `accessState == .fullAccess` (PaywallView.swift:120-122). One theoretical hole: `purchase()` returns `true` from the verified transaction while the *entitlement* comes from a second async `currentEntitlements` re-query, so if that re-query were momentarily stale the paywall would dismiss into a still-expired app. Apple's own sample code does exactly this refresh-after-finish, and I could not find documentation that `currentEntitlements` lags a finished transaction, so I could not write an honest trace and did not report it.

`Transaction.currentEntitlements` for a paid (non-grandfathered) user offline: this is served from locally-signed transactions and has no error channel, so I could not evidence a transient-empty result for a real purchaser; I therefore scoped candidate 4 to the AppTransaction/grandfather branch, where the failure is documented to throw and the code visibly attempts (and fails at) a "keep prior value" mitigation.

Restore path mechanics: calling `AppStore.sync()` only from an explicit "Restore Purchase" tap matches Apple's guidance, and `restoring` correctly disables the button during the call. The defect is only the swallowed error (candidate 3).

Buy-button disabled condition: `.disabled(purchasing || product == nil)` (PaywallView.swift:102) cannot be tapped with a nil product, so the `if product == nil { await loadProduct() }` retry inside `Store.purchase()` (Store.swift:34) is dead code rather than a race; the user-visible part is the nit (candidate 5).

Trial-start and QA overrides (F9.1, F9.12), the cutover boundary maths (F9.13, unit-tested in UnplugCore/Tests/UnplugCoreTests/AccessControlTests.swift:88-105) and `trialDaysRemaining` (F9.10) are outside this StoreKit-correctness lens and were not investigated.

</details>

<details><summary>Noted outside lens (uninvestigated)</summary>

- Grandfathered users have a trial clock started for them at all (ContentView.swift:77 -> startTrialIfNeeded), which is what makes several entitlement-failure paths degrade to .expired rather than staying .trial. Arguably an arm-path/state-machine issue rather than StoreKit.
- `qaForceFullAccess` is read from the app group by `hasFullAccess` (AccessController.swift:69) in release builds, i.e. a value written by a QA build persists across upgrades in group.screentimeshield and grants full access; F9.12 is someone else's lens but worth a look.
- `updateTrialEndedNotification()` reads the raw key "start" (AccessController.swift:132) rather than an AppGroupKeys constant — a rename in Model would silently disable the reminder.
- The paywall's close button (PaywallView.swift:36-43) always dismisses into the expired app state; no bug found in the StoreKit plumbing there, but the expired-and-armed UX (armed schedule with enforcement gated off) belongs to the F9.11 lens.

</details>

---

## F9 · F9:trial-grandfather-math

### `F9-DATE-01` — Grandfathered access is derived state that is never persisted, so one failed AppTransaction fetch downgrades a grandfathered user to `.expired` and switches the extension's enforcement gate off

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F9.4 · **Needs device** yes
- **Anchor** `ScreenTimeShield/Store.swift:78`

**Mechanism**

`Store.isGrandfathered` is a plain in-memory `@Published` that starts `false` on every fresh `Store` instance (`Store.swift:17`), i.e. on every cold launch, and it is the *only* representation of grandfathering — nothing writes it to the app group (`AppGroupStore.swift:12-19` holds only `trial_start`, `times_stopped`, `enforcement_allowed`, `qa_force_full_access`). `refreshGrandfatheredState` (`Store.swift:70-81`) is the sole writer and its `catch` returns without touching the value; the comment "leave prior value untouched" (`Store.swift:78`) is only true within a process — across a cold launch the "prior value" is `false`. The failure is then amplified by `trial_start` being written for *every* user who ever arms, including full-access ones: `performArm()` calls `access.startTrialIfNeeded()` unconditionally (`ContentView.swift:77`, and again at `:61`), and `startTrialIfNeeded` has no `hasFullAccess` check (`AccessController.swift:84-90`). So a grandfathered user carries a `trial_start` that is weeks old. When `refreshAccess()` runs (`AccessController.swift:93-99`) and `refreshGrandfatheredState` throws, `hasFullAccess` is false and `AccessEvaluator.accessState` returns `.expired` (`AccessControl.swift:55-57`), and `recomputeAccessState` then writes `enforcement_allowed = false` into the app group (`AccessController.swift:118`) — which the monitor extension reads and obeys (`DeviceActivityMonitorExtension.swift:42-59`). Note the asymmetry with `refreshPurchasedState`, which also unconditionally assigns `isPurchased` (`Store.swift:66`) — same fail-open-to-`false` shape.

**Failure trace**

Grandfathered user (first downloaded before the cutover) updates to the IAP build with network → AppTransaction verifies → `isGrandfathered = true`, no trial chip. They tap "Start blocking" for a 22:00–07:00 daily block → `startTrialIfNeeded()` writes `trial_start = today` even though they have full access. Three weeks later they sign out of the App Store in Settings (or cold-launch with no connectivity): app becomes active → `ScreenTimeShieldApp.swift:101` → `refreshAccess()` → `Transaction.currentEntitlements` yields no lifetime purchase (they never bought), `try await AppTransaction.shared` throws ("isn't available or the user isn't authenticated with the App Store") → `catch` at `Store.swift:77-80` leaves `isGrandfathered` at its fresh-instance `false` → `accessState = .expired` → `enforcement_allowed = false` persisted to `group.screentimeshield`. UI immediately shows `TrialChip` "Trial ended · Unlock Unplug" (`TrialChip.swift:19-22`) and `start()` now routes to the paywall (`ContentView.swift:71`). At 22:00 the still-registered `.daily` interval starts, the extension's `guard enforcementAllowed` fails (`DeviceActivityMonitorExtension.swift:56-59`) and returns → no shields applied, `inside_interval` stays false. The false gate stays in the app group until the app is next foregrounded *with* App Store connectivity, so subsequent nights are also unenforced if the app isn't opened again.

**User impact**

A user promised permanent free access is told his trial has ended and is asked to pay, and — worse — that night's block silently does not happen even though the app shows the block as armed. Being signed out of the App Store or launching offline is enough to trigger it; no user action can recover it except relaunching while online.

**API semantics relied on**

Apple docs for `AppTransaction.shared` (developer.apple.com/documentation/storekit/apptransaction/shared, fetched): "This property throws an error if the AppTransaction isn't available or if the user isn't authenticated with the App Store. Getting an AppTransaction may require network connectivity." So the `catch` branch is reachable in production, not just on simulators. Also verified from the iOS 26.2 SDK `StoreKit.swiftinterface` line 973 that `AppTransaction.originalPurchaseDate` is non-optional `Foundation.Date`, so the nil branch of `Grandfather.isGrandfathered` is unreachable from this call site — the failure mode is the thrown error, not a nil date. I did not confirm whether StoreKit caches a previously fetched app transaction well enough to survive an offline cold launch; the signed-out case does not depend on that.

### `F9-DATE-02` — Nothing tears down the registered `.daily` schedule when the trial expires, so the app sits "armed" forever while the extension refuses to enforce — the "gate-and-drain" claim has no drain

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F9.11 · **Needs device** yes
- **Anchor** `ScreenTimeShield/AccessController.swift:118`

**Mechanism**

`recomputeAccessState()` (`AccessController.swift:112-120`) is the only thing that runs at expiry and it does exactly two things: publish `accessState` and cache `enforcement_allowed`. It never calls `Schedule.stopMonitoring` and never clears `Model.isArmed`. The only teardown path is the user-initiated `stop()` (`ContentView.swift:82-86`); `applySchedule()`'s `!isExpired` guard (`ContentView.swift:60`) only prevents *re-registration*, it cannot unregister what is already registered. `Model.isArmed` is persisted in the app group (`Model.swift:32`) and is resynced on launch from `DeviceActivityCenter().activities.contains(.daily)` (`ContentView.swift:248`), which still contains `.daily`, so the armed UI survives relaunch. Meanwhile the extension hard-returns before applying anything (`DeviceActivityMonitorExtension.swift:56-59`). The comment at `DeviceActivityMonitorExtension.swift:54-55` ("The app also stops scheduling on expiry (gate-and-drain)") describes behaviour that does not exist anywhere in the codebase (grep for `stopMonitoring`: only `ContentView.stop()`, the notifications toggle at `:242`, and `qaResetToFreshInstall`).

**Failure trace**

Day 1: user selects apps, taps "Start blocking" for 22:00–07:00 → `.daily` registered, `is_armed = true`, `trial_start = day 1`. Day 8: trial lapses; next time the app becomes active `refreshAccess()` → `accessState = .expired` → `enforcement_allowed = false`. UI state now: `StatusBanner` "Block inactive", `primaryTitle` = "Stop blocking" because `model.isArmed` is true (`ContentView.swift:37-41`) and `primaryDisabled` = false (`:43-48`) — i.e. the app claims a block is set up and offers to stop it. 22:00: `intervalDidStart(for: .daily)` fires in the extension, `guard enforcementAllowed` fails → returns → no shields, `inside_interval` untouched. 07:00: `intervalDidEnd` clears nothing. This repeats every night indefinitely: registered, armed, unenforced.

**User impact**

Exactly the state F9.11 forbids: "armed but silently unenforced". The primary CTA reads "Stop blocking", implying a live block, while restricted apps open freely every night. (Partly mitigated by the daily "Your blocks are off" local notification from `AccessController.swift:126-143`, but only if notification permission was granted, and the main screen keeps contradicting it.)

**API semantics relied on**

Relies only on `DeviceActivityCenter.activities` continuing to report a registered repeating activity, and on the extension being launched for interval callbacks — both already load-bearing for the app's normal operation. No new Apple semantics assumed.

### `F9-DATE-03` — The enforcement gate is only recomputed while the app is foregrounded, so a user who simply never reopens the app keeps unlimited enforcement after the trial ends

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F9.2 · **Needs device** yes
- **Anchor** `ScreenTimeShield/ScreenTimeShieldApp.swift:101`

**Mechanism**

`recomputeAccessState()` — the only writer of `enforcement_allowed` (`AccessController.swift:118`) — is reachable only from `refreshAccess()` (called at `ScreenTimeShieldApp.swift:101-103` on `scenePhase == .active` and `ContentView.swift:261`), `startTrialIfNeeded()`, `purchase()`, `restore()` and the QA hooks. There is no timer, no background task, and no expiry evaluation anywhere in the extension: the extension only reads the cached boolean (`DeviceActivityMonitorExtension.swift:42-43`) and it defaults to `true` when absent. `trial_start` and `PricingConfig.trialLength` are both available to the extension through the app group, but the extension never computes expiry itself. So after the last foreground while still in trial, the cached value is `true` and stays `true` forever.

**Failure trace**

Day 1: user arms a 22:00–07:00 daily block. Last foreground is day 1, at which point `refreshAccess()` writes `enforcement_allowed = true` (state `.trial`). The user never opens the app again — there is no reason to, the block is automatic and unskippable. Day 8 onwards: the trial has lapsed, but nothing recomputes; `.daily` is still registered; `intervalDidStart` passes the gate (`DeviceActivityMonitorExtension.swift:56`), `model.setRestrictions()` applies the shields and `inside_interval = true` (`:60-63`). The paid feature keeps working indefinitely, at full fidelity, for free.

**User impact**

Revenue integrity: the lifetime unlock is bypassable by a client-side action any normal user can take — not launching the app (F9.9). Conversely, an honest user's expiry is never communicated at the moment it happens, only on the next foreground.

**API semantics relied on**

Assumes the monitor extension keeps receiving `intervalDidStart` for a registered repeating `DeviceActivitySchedule` without the containing app ever running — the documented model for `DeviceActivityMonitor` (extension process launched by the system) and the premise of the whole app. `intervalDidStart` docs confirm delivery is tied to device use inside the interval, not to the app being alive.

### `F9-DATE-04` — Buying the unlock during a block window that already started while expired does not restore enforcement until the next interval — the user pays and stays unblocked for the rest of the night

- **Severity** Important · **Confidence (self-reported)** medium · **Invariant** F9.11 · **Needs device** yes
- **Anchor** `ScreenTimeShield/AccessController.swift:103`

**Mechanism**

`AccessController.purchase()` (`:101-105`) and `restore()` (`:107-110`) only call `recomputeAccessState()`, which publishes `.fullAccess` and flips `enforcement_allowed` back to `true` (`:118`). Neither re-registers the schedule nor applies restrictions. `PaywallView.buy()` just dismisses (`PaywallView.swift:136-142`), and `ContentView` has no `onChange(of: access.accessState)` that would re-arm — the only writers of shields are the extension's `intervalDidStart` (`DeviceActivityMonitorExtension.swift:60-63`) and `Model.setRestrictions()` called from there. Because the interval's `intervalDidStart` already fired earlier in the evening and returned early on the gate, and `.daily` is never re-registered (`applySchedule()` runs only from the selection `onChange` and `performArm`, `ContentView.swift:59-68`), nothing applies shields for the remainder of the current window.

**Failure trace**

Expired user still has `.daily` registered for 22:00–07:00 and `is_armed = true` (see the no-drain candidate). 22:00: `intervalDidStart` fires, gate is false, returns — no shields. 22:30 the user notices apps aren't blocked, opens the app, taps the trial chip, buys the lifetime unlock → `accessState = .fullAccess`, `enforcement_allowed = true`, paywall dismisses (`PaywallView.swift:120-122`, `:138`). Main screen: "Stop blocking" + "Block inactive". Nothing calls `setRestrictions()`, and the system will not re-deliver `intervalDidStart` for an interval that already started. Restricted apps stay open until 22:00 the following day.

**User impact**

A customer pays specifically to get tonight's block back and gets nothing until tomorrow night, with no explanation and with the UI showing the block as armed.

**API semantics relied on**

Depends on `intervalDidStart(for:)` not being re-delivered later within the same interval occurrence. Apple's docs (developer.apple.com/documentation/deviceactivity/deviceactivitymonitor/intervaldidstart(for:), fetched) say only "An activity starts when someone first uses the device within the activity's scheduled time interval… the system only invokes this method when the device is in use" — consistent with once-per-occurrence but not an explicit guarantee, hence medium confidence. Re-registering the schedule mid-window *does* fire it (that is how the app's risky-arm-now path works), which is why the missing re-register is the defect.

### `F9-DATE-05` — `PricingConfig.cutoverDate` (2026-06-25) is already a month in the past while the IAP build is still unshipped, so everyone who bought the app in that window will not be grandfathered

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F9.4 · **Needs device** no
- **Anchor** `UnplugCore/Sources/UnplugCore/AccessControl.swift:27`

**Mechanism**

`cutoverDate = Date(timeIntervalSince1970: 1_782_345_600)` is exactly 2026-06-25 00:00 UTC (verified by conversion), and `Grandfather.isGrandfathered` grants permanent access only when `originalPurchaseDate < cutoverDate` (`AccessControl.swift:74-77`). The constant is meant to be the *actual* IAP go-live moment ("Keep in sync with the actual App Store release; adjust if the release date slips", `:26`; `status.md:28` repeats the warning). The release has slipped: today is 2026-07-25, `MARKETING_VERSION` is still 1.3 with 1.3 never released (`status.md:33`), the lifetime IAP is only "Ready to Submit" and must ship with a build (`status.md:2`), and the last commit is 2026-06-19. Every download that has happened since 2026-06-25 — of the currently live, pre-IAP, paid build — therefore records an `originalPurchaseDate` after the cutover and evaluates to not-grandfathered. This is a stale-constant defect, not a boundary-arithmetic one: the strict `<` and the nil case are both well defined (nil is unreachable, `AppTransaction.originalPurchaseDate` is non-optional in the SDK).

**Failure trace**

A user pays $0.99 for Unplug on 2026-07-01 (pre-IAP build, no trial, no paywall — full app). Whenever 1.3 ships, they auto-update. First launch → `refreshAccess()` → `refreshGrandfatheredState(cutoverDate: 2026-06-25)` → `originalPurchaseDate (2026-07-01) < cutoverDate` is false → `isGrandfathered = false`, no lifetime entitlement → `accessState = .trial`. They arm a block, `trial_start` is written, and 7 days later `accessState = .expired`, `enforcement_allowed = false`: the paid app they already own stops blocking and shows "Trial ended · Unlock Unplug" asking for another $4.99.

**User impact**

Every customer who bought the app between 2026-06-25 and the actual 1.3 release loses functionality they paid for and is asked to pay again — an App Store review risk and a refund/1-star magnet. The affected cohort grows every day the release slips further.

**API semantics relied on**

`AppTransaction.originalPurchaseDate` is the date the customer originally obtained the app (non-optional `Foundation.Date`, confirmed at line 973 of the iOS 26.2 SDK `StoreKit.swiftinterface`) and is not reset by app updates — which is precisely why the code chose it over `originalAppVersion`. The claim that the release has not happened is evidenced from `status.md:2,33` and git history, not from the App Store.

### `F9-DATE-06` — Trial chip shows a full 7-day countdown before any trial has started

- **Severity** Nit · **Confidence (self-reported)** high · **Invariant** F9.10 · **Needs device** no
- **Anchor** `UnplugCore/Sources/UnplugCore/AccessControl.swift:64`

**Mechanism**

`trialDaysRemaining` returns `ceil(trialLength / secondsPerDay)` = 7 when `trialStart` is nil (`AccessControl.swift:63-65`), and the trial only actually starts on the first arm (`AccessController.swift:84-90`, called from `ContentView.swift:77`). `TrialChip` renders that number unconditionally whenever `accessState != .fullAccess` (`ContentView.swift:186-188`, `TrialChip.swift:19-22`), and for a never-armed user `accessState` is `.trial` (`AccessControl.swift:56`).

**Failure trace**

Fresh install, user grants Screen Time but doesn't set up a block. Chip reads "7 days left in trial · Unlock". They come back on day 3 and day 10 without arming: the chip still reads "7 days left in trial" (nothing has started, nothing decrements). A user who believes the clock is running either rushes or, later, distrusts the counter when it fails to move.

**User impact**

Misleading countdown — F9.10 explicitly names "a count before the trial has started". Cosmetic but it undermines the paywall's own urgency mechanic.

### `F9-DATE-07` — The post-expiry "Your blocks are off" reminder fires at the wrong time of day in Allow-only mode

- **Severity** Nit · **Confidence (self-reported)** high · **Invariant** NEW · **Needs device** no
- **Anchor** `ScreenTimeShield/AccessController.swift:132`

**Mechanism**

`updateTrialEndedNotification` schedules the daily reminder from the app-group `"start"` key (`AccessController.swift:132,139`), documented as "the user's habitual block-start time — the moment they'd normally be protected" (`:124-125`). But `"start"` is the *picked window* start (`Model.swift:41-45`), and in Allow-only mode the blocked interval is the inverse: `blockedInterval` returns `(start: end, end: start)` (`Model.swift:36-38`). So for allow-only users the reminder is scheduled at the moment the block would have *ended*.

**Failure trace**

User sets Allow-only with window 09:00–17:00 (blocked 17:00 → 09:00 next day) and arms; `"start"` = 09:00. Trial expires → `recomputeAccessState()` → `updateTrialEndedNotification()` reads `"start"` = 09:00 → `UNCalendarNotificationTrigger(hour: 9, minute: 0, repeats: true)`. Every morning at 09:00 — the moment they are legitimately free to use their apps — they get "Nothing's stopping the scroll right now", while 17:00, when protection should have kicked in, passes silently.

**User impact**

The re-engagement nudge lands at the least relevant time for allow-only users and reads as a false alarm, so the one mechanism that would tell them their blocks have stopped is wasted.

**API semantics relied on**

`UNCalendarNotificationTrigger(dateMatching: [.hour,.minute], repeats: true)` fires daily at the given local time — standard UserNotifications behaviour, no unusual semantic relied on.

<details><summary>Ruled out by this lens</summary>

CUTOVER BOUNDARY ARITHMETIC (F9.13) — clean, no bug. `Grandfather.isGrandfathered` (AccessControl.swift:74-77) is total: nil → false, equal timestamps → false (strict `<`), later → false. The nil branch is unreachable from the only production call site: `AppTransaction.originalPurchaseDate` is declared non-optional `Foundation.Date` (iOS 26.2 SDK StoreKit.swiftinterface:973), so `Store.swift:74-76` can never pass nil. Equality is a measure-zero event (millisecond-precision purchase timestamps vs an exact-midnight-UTC constant) and, if it ever happened, "not grandfathered" is the documented intent and is unit-tested (AccessControlTests.swift:94-95). The constant itself is arithmetically right: 1_782_345_600 == 2026-06-25 00:00:00 UTC, matching its comment. The stale test constant 1_781_740_800 (AccessControlTests.swift:87) claims to "match PricingConfig.cutoverDate" but the tests use their own boundary throughout, so nothing is actually mis-tested — comment rot only, and status.md already notes it. The real cutover defect is the calendar one I did report.

trialDaysRemaining ROUNDING (F9.10) — the ceil() is correct at both edges. Immediately before expiry, `remaining` is a fraction of a second, `remaining > 0` holds, and `ceil` yields 1 → "1 days left", while `accessState` is still `.trial` (AccessControl.swift:57 uses the same `<`), so the two agree. At/after expiry, `remaining <= 0` → 0, and `accessState` is `.expired` at exactly the same instant, so `TrialChip` switches to "Trial ended" (TrialChip.swift:19-22) and the 0 is never rendered. There is no window where the chip says "0 days left" while still in trial. Monotonic non-increasing holds because `trial_start` is only written by `startTrialIfNeeded` under an `== nil` guard (AccessController.swift:84-90) and by the QA hooks; no ordinary path moves it (F9.1 holds for the paths in my lens). Staleness of the displayed number in a long-lived foreground session is bounded by the fact that `refreshAccess()` runs on every `scenePhase == .active` (ScreenTimeShieldApp.swift:95-103) and `@Published accessState` re-sends even on an equal assignment, so the chip refreshes on each foreground; I found no case where it shows a number that is too *low*.

EXPIRY LANDING MID-BLOCK, the "block continues" half (F9.11) — fine. If `inside_interval` is true when the trial lapses, the already-applied `ManagedSettingsStore` shields are untouched by `recomputeAccessState()` (AccessController.swift:112-120 writes only UserDefaults) and the still-registered `.daily` activity's `intervalDidEnd` clears them and resets `inside_interval` at the natural end (DeviceActivityMonitorExtension.swift:68-79, which has no gate check — correctly so). So the in-flight block runs to completion and is cleanly torn down; there is no lock-out. The incoherence is entirely in what happens on the *next* interval, which is the no-drain candidate.

PURCHASED (not grandfathered) USER OFFLINE (F9.5) — investigated, not promoted. `refreshPurchasedState` (Store.swift:58-67) has the same fail-to-false shape as the grandfather path: `purchased` starts false and is assigned unconditionally at :66, so an empty `Transaction.currentEntitlements` sequence yields `isPurchased = false` → `.expired` → `enforcement_allowed = false` for a paying user. I could not confirm the load-bearing semantic: Apple's `currentEntitlements` documentation (fetched) says nothing about offline behaviour, local caching, or network requirements, and the practical belief that it is served from the on-device signed transaction cache would make the failure unreachable. Rather than report a finding whose trace hinges on an unverified API behaviour, I am flagging it here: worth a device test (airplane mode + cold launch on a purchased account), and the fix is the same as for the grandfather candidate (persist the entitlement decision, only downgrade on a positive answer).

QA OVERRIDES (F9.12) — not my lens, but nothing in the date/expiry math reads them except `hasFullAccess` via `qaForceFullAccess` (AccessController.swift:69), which is a shared-app-group bool that a QA build could leave behind; left to whoever owns F9.12.

</details>

<details><summary>Noted outside lens (uninvestigated)</summary>

`Schedule.setSchedule` swallows `startMonitoring` errors (Schedule.swift:35-39), so an arm can fail while `Model.isArmed` stays true — F4.6, already flagged in status.md; not investigated further.
`ContentView.applySchedule()` fires from the selection `onChange` (ContentView.swift:218-229) and re-registers `.daily` via `stopMonitoring` + `startMonitoring` (Schedule.swift:32-40) while a block may be active — interaction with `inside_interval` is F4.8 territory, not examined.
`restrictForNextHour` registers the `.hourly` activity with `repeats: false` (ContentView.swift:109) and nothing ever calls `stopMonitoring([.hourly])`, and `stop()` only stops `[.daily, .notificationSchedule]` (ContentView.swift:84) — possible F4.7 gap, uninvestigated.
The trial-countdown string `"%lld days left in trial · Unlock"` has no plural variations in Localizable.xcstrings (single stringUnit per language), so the last day renders "1 days left in trial" in English and is grammatically wrong in the plural-sensitive locales (de/es/fr/it/pt) — trivial copy fix, not worth a finding slot.
`AccessController.qaResetToFreshInstall` calls `UserDefaults.standard.removePersistentDomain(forName: "group.screentimeshield")` (AccessController.swift:191) rather than operating on the suite instance used everywhere else — worth a check by whoever owns F9.12 that this actually clears the app-group domain.

</details>

---

## F9 · F9:gate-integrity

### `F9-INTEG-01` — Expired trial is fully restored by moving the device clock backward — free forever, no reinstall needed

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F9.9 · **Needs device** no
- **Anchor** `UnplugCore/Sources/UnplugCore/AccessControl.swift:57`

**Mechanism**

Access is decided purely by comparing wall-clock `Date()` against the stored `trial_start`: `AccessEvaluator.accessState` returns `.trial` whenever `now.timeIntervalSince(trialStart) < trialLength` (UnplugCore/Sources/UnplugCore/AccessControl.swift:57). `now` is `Date()` captured in `AccessController.recomputeAccessState()` (ScreenTimeShield/AccessController.swift:113), i.e. the user-settable system clock. `trial_start` is a plain absolute `Date` in the app group (ScreenTimeShield/AccessController.swift:55-58, AppGroupStore.swift:13). There is no monotonic anchor (no boot-time/uptime check, no `Date()`-vs-last-seen-max ratchet, no server time, no receipt date), and nothing records a high-water mark of the largest `now` ever seen, so a *negative* elapsed interval is silently accepted as "still in trial". `trialDaysRemaining` has the same hole: `remaining = trialLength - now.timeIntervalSince(trialStart)` (AccessControl.swift:66-68) grows without bound when `now < trialStart`.

**Failure trace**

1. User installs Unplug, taps "Start blocking" — `ContentView.performArm()` → `access.startTrialIfNeeded()` (ScreenTimeShield/ContentView.swift:77) writes `trial_start = 2026-07-01`. 2. Eight days pass; the user foregrounds the app, `refreshAccess()` → `recomputeAccessState()` computes `.expired`, writes `enforcement_allowed = false` (AccessController.swift:118), the paywall CTA appears, blocks stop being applied. 3. User opens iOS Settings → General → Date & Time, turns off "Set Automatically", sets the date to 2026-06-20. 4. User reopens Unplug: scenePhase `.active` → `refreshAccess()` (ScreenTimeShieldApp.swift:101-102) → `accessState(now: 2026-06-20, trialStart: 2026-07-01)` → `timeIntervalSince` is −11 days, which is `< trialLength`, so `.trial`. `enforcement_allowed` is rewritten `true`. 5. Persisted state: `trial_start` unchanged (2026-07-01), `enforcement_allowed = true`. 6. The user sees the full app: TrialChip reads "18 days left in trial · Unlock" (TrialChip.swift:21 via `trialDaysRemaining`), all CTAs enabled, and `intervalDidStart` in the extension passes its gate (DeviceActivityMonitorExtension.swift:56) so blocking works exactly as paid. Repeatable indefinitely; DeviceActivity schedules key off wall-clock hour/minute (Schedule.swift:76) so a back-dated clock does not disturb enforcement.

**User impact**

Any user who can reach Settings gets the paid product free, permanently, with a one-minute change and no jailbreak/reinstall. Also displays an impossible "18 days left in a 7-day trial" (F9.10).

**API semantics relied on**

Relies only on `Date()` reflecting the user-settable system clock, and on iOS allowing manual backdating via Settings → General → Date & Time when "Set Automatically" is off. No Apple-specific semantic beyond that; the access decision is pure UnplugCore logic covered by existing unit tests, which only feed forward-moving `now` values (UnplugCore/Tests/UnplugCoreTests/AccessControlTests.swift:20-66).

### `F9-INTEG-02` — Trial expiry is only enforced if the app is foregrounded after it expires — never open the app and blocking keeps working for free forever

- **Severity** Important · **Confidence (self-reported)** high · **Invariant** F9.2 · **Needs device** yes
- **Anchor** `ScreenTimeShield/AccessController.swift:118`

**Mechanism**

`enforcement_allowed` — the only thing the extensions consult — is written exclusively by `recomputeAccessState()` (ScreenTimeShield/AccessController.swift:118), which only ever runs from main-app entry points: `refreshAccess()` on scenePhase `.active` (ScreenTimeShieldApp.swift:101-102) and `ContentView.task` (ContentView.swift:256-262), plus purchase/restore/QA. Nothing recomputes it on a timer, on a background launch, or in the extension. The extension caches nothing of its own: it reads the key and defaults to `true` when absent (DeviceActivityMonitorExtension.swift:42-44), and it never derives expiry itself even though `trial_start` sits in the same app group and `PricingConfig.trialLength` is a compile-time constant. Meanwhile the `.daily` schedule is registered with `repeats: true` (Schedule.swift:26-29) and nothing unregisters it on expiry — `recomputeAccessState` does not call `Schedule.stopMonitoring`, and the only `stopMonitoring` calls are user-driven (ContentView.swift:84, :242). So the "gate-and-drain" claim at DeviceActivityMonitorExtension.swift:54-55 depends entirely on a foreground visit that may never happen. The same single code path also owns the trial-ended reminder (AccessController.swift:119 → :126-143), so the user is not even nudged.

**Failure trace**

1. Day 0: user picks apps, sets 09:00–17:00, taps "Start blocking". `startTrialIfNeeded()` writes `trial_start = day0`; `recomputeAccessState()` writes `enforcement_allowed = true`; `Schedule.setSchedule(..., repeats: true)` registers `.daily`. 2. User stops opening Unplug (they don't need to — the schedule repeats daily and the shield does the work). 3. Day 8, 09:00: the system launches CustomDeviceActivityMonitor and calls `intervalDidStart(.daily)`. `enforcementAllowed` reads the day-0 value, `true` (DeviceActivityMonitorExtension.swift:43), so the guard at :56 passes and `model.setRestrictions()` applies the shields (:60-63). 4. Persisted state: `trial_start = day0` (8 days old, i.e. `.expired` by AccessEvaluator), `enforcement_allowed = true`, `inside_interval = true`. 5. What the user sees: their apps are shielded exactly as during the trial, every day, indefinitely; no paywall, and no "Your blocks are off" notification either, because `updateTrialEndedNotification()` is only reachable from the same foreground recompute.

**User impact**

The full paid feature keeps working forever after the trial ends for anyone who simply doesn't reopen the app — a trivially discoverable free ride, and a silent revenue leak for ordinary set-and-forget users too.

**API semantics relied on**

Relies on DeviceActivityMonitor's documented contract that the *system* launches the monitor extension at each interval start of a registered schedule, independent of the host app running or being foregrounded (that is the whole basis of this app's enforcement, and the same assumption the shipped feature already depends on). It also relies on a registered `repeats: true` schedule surviving until explicitly stopped — consistent with ContentView.swift:248 re-deriving `isArmed` from `DeviceActivityCenter().activities` across launches. Not verified against docs: whether iOS ever proactively invalidates long-lived schedules; that would only shorten, not remove, the leak.

### `F9-INTEG-03` — Grandfathered/paid users are stamped with a trial_start and their entitlement verdict is never persisted — one failed AppTransaction locks them out and silently kills their blocks

- **Severity** Important · **Confidence (self-reported)** medium · **Invariant** F9.4 · **Needs device** yes
- **Anchor** `ScreenTimeShield/AccessController.swift:84`

**Mechanism**

Two defects compose. (a) `startTrialIfNeeded()` (ScreenTimeShield/AccessController.swift:84-90) writes `trial_start` whenever it is nil, with no check on `hasFullAccess`/`accessState`; it is called on every arm path (ContentView.swift:61, :77, :106). So grandfathered and purchased users also get a 7-day timer stamped the first time they arm. (b) The entitlement verdict that normally suppresses that timer is in-memory only: `Store.isPurchased`/`isGrandfathered` are plain `@Published` properties initialised to `false` on every cold launch (ScreenTimeShield/Store.swift:16-17) and are never mirrored into the app group. `refreshGrandfatheredState` returns early on `.unverified` (Store.swift:73) and swallows a throw with the comment "leave prior value untouched" (Store.swift:77-80) — but on a cold launch the prior value *is* `false`, so a failure means "not grandfathered", not "unknown". Grandfathering has no on-device entitlement at all (there is no transaction to fall back on), so `AppTransaction.shared` is a single point of failure. `recomputeAccessState()` then computes `.expired` from the stale `trial_start`, writes `enforcement_allowed = false` (AccessController.swift:118) and schedules the daily "Your blocks are off" reminder (:126-143). Nothing ever stops the registered `.daily` schedule, so the UI still believes it is armed (`isArmed` is re-derived from `DeviceActivityCenter().activities` at ContentView.swift:248).

**Failure trace**

1. Pre-cutover user (downloaded 2026-03, so grandfathered) updates to 1.3, taps "Start blocking": `startTrialIfNeeded()` writes `trial_start = today` (nobody checks that they already have full access), `.daily` registered. 2. For a week, launches succeed: `AppTransaction.shared` verifies, `isGrandfathered = true`, state `.fullAccess`, gate `true`. 3. Day 9, the user cold-launches on a plane / with no App Store network, or hits an `.unverified` AppTransaction result: `refreshGrandfatheredState` leaves `isGrandfathered = false` (Store.swift:73/:77), `isPurchased` is also `false` (they never bought). 4. `recomputeAccessState()` → `accessState(now: day9, trialStart: day1, hasFullAccess: false)` → `.expired`; persisted state: `enforcement_allowed = false`, trial-ended notification registered at their block-start time. 5. That evening `intervalDidStart(.daily)` fires and returns early at DeviceActivityMonitorExtension.swift:56 — no shields. 6. What the user sees: the header chip reads "Trial ended · Unlock Unplug" (TrialChip.swift:19-21), tapping the app card does nothing (`openPicker` bails at ContentView.swift:96), "Start blocking" opens the paywall (:71), a daily push says "Your blocks are off" — while the schedule is still registered so the CTA reads "Stop blocking", and their restricted apps simply open unshielded.

**User impact**

A grandfathered (or, via the same path, a purchased) user is paywalled and has their unskippable block silently stop enforcing — the exact failure the product promise forbids — triggered by nothing more than an offline or unverified StoreKit launch.

**API semantics relied on**

Depends on `AppTransaction.shared` being able to fail or return `.unverified` on a device that previously succeeded. Checked via Apple docs/forums: StoreKit returns a cached AppTransaction when offline *if one is cached*, but it needs network for an uncached/refreshed value, and developers report real-world throws (iOS 17 401s) and `.unverified` results (developer.apple.com/forums/thread/738772, /thread/780767, /thread/773604). The app's own comments corroborate that `AppTransaction` can block or prompt for Apple-ID sign-in (ScreenTimeShield/ContentView.swift:257-258, ScreenTimeShieldApp.swift:97-99). I could not confirm a documented guarantee that a once-cached AppTransaction always verifies offline, so confidence is medium; the app-side defects (stamping trial_start for full-access users, never persisting the verdict) are certain from the code.

### `F9-INTEG-04` — qa_force_full_access is read by release builds and, once set, can never be cleared — a stale QA/TestFlight value grants permanent free access

- **Severity** Important · **Confidence (self-reported)** medium · **Invariant** F9.12 · **Needs device** no
- **Anchor** `ScreenTimeShield/AccessController.swift:69`

**Mechanism**

`hasFullAccess` in the shipping build ORs in a persisted app-group flag: `var hasFullAccess: Bool { storeKit.hasFullAccess || qaForceFullAccess }` (ScreenTimeShield/AccessController.swift:69), where `qaForceFullAccess` is `kv.bool(forKey: "qa_force_full_access")` (AccessController.swift:151-154, AppGroupStore.swift:19). There is no `#if DEBUG`, no TestFlight/sandbox-receipt check, and no migration that clears the key on a production build — the file's own comment states it is "Present in release builds on purpose" (AccessController.swift:146-148). The only writer is `qaSetFullAccess` from `QAMenuView` (QAMenuView.swift:43-46), and the only other eraser is `qaResetToFreshInstall` (AccessController.swift:186-205) — both reachable solely from the QA entry that is now commented out (SettingsView.swift:25-29). So the value is write-once-and-stuck: the mechanism that could clear it was removed along with the mechanism that set it. Git history confirms the entry was live in shipped-shape builds between a3e4c07 and 7e88b58 (`git log -p -- ScreenTimeShield/SettingsView.swift`).

**Failure trace**

1. On a build in the a3e4c07..7e88b58 range (TestFlight/dev), the tester opens Settings → "QA / Debug" → toggles "Force full access" on. `qaSetFullAccess(true)` writes `qa_force_full_access = true` into `group.screentimeshield` (AccessController.swift:174-178). 2. That build is replaced by the App Store 1.3 build (an update, or a delete+reinstall — app-group UserDefaults are widely reported to survive reinstall on iOS 16+). 3. The production build launches: `refreshAccess()` → `recomputeAccessState()` → `hasFullAccess` is `true` purely from the stale flag → `accessState = .fullAccess`, `enforcement_allowed = true`. 4. Persisted state: `qa_force_full_access = true` forever; no code path in the production build can flip it back. 5. What the user sees: no TrialChip at all (`ContentView.swift:186` hides it for `.fullAccess`), no paywall ever, full unskippable blocking — indistinguishable from a paid user, and `trial_start` is irrelevant.

**User impact**

Every device that ever ran a QA build with the toggle on has permanent free full access with no way for the app to revoke it; the status.md claim that the QA scaffolding is "inert/unreachable in production" does not hold for values it left behind.

**API semantics relied on**

Depends on app-group UserDefaults surviving an app update (certain) and, for the delete+reinstall variant, on app-group container persistence. Verified against developer.apple.com/forums/thread/718449 and community reports: `UserDefaults(suiteName:)` for an app group is *not* reliably cleared on uninstall from iOS 16 onward, and Apple documents no cleanup guarantee. Blast radius (did such a build reach any tester?) is a distribution fact I cannot verify from the repo — the code path itself is certain.

### `F9-INTEG-05` — Trial resets on delete + reinstall — trial_start has no reinstall-proof anchor even though the receipt date the app already reads would provide one

- **Severity** Important · **Confidence (self-reported)** low · **Invariant** F9.9 · **Needs device** yes
- **Anchor** `ScreenTimeShield/AccessController.swift:55`

**Mechanism**

The only record that a trial was ever used is `trial_start` in the app-group `UserDefaults` (ScreenTimeShield/AccessController.swift:55-58, AppGroupStore.swift:13/:22-24). Nothing else records it: there is no Keychain item anywhere in the project, no NSUbiquitousKeyValueStore, no server (grep for `Keychain|kSecClass|NSUbiquitous` across the repo returns nothing), and `AppTransaction.originalPurchaseDate` — which the app already fetches for grandfathering (Store.swift:70-76) and which does survive reinstall — is never used to anchor or sanity-check the trial. `accessState` treats a nil `trial_start` as "trial not started yet" and returns `.trial` (UnplugCore/Sources/UnplugCore/AccessControl.swift:56), and `trialDaysRemaining` returns the full 7 (AccessControl.swift:63-65). So if the container is cleaned, the trial silently restarts from scratch.

**Failure trace**

1. User burns the 7-day trial, sees "Trial ended · Unlock Unplug" and dead CTAs. 2. Long-presses the icon → Remove App → Delete App, then reinstalls from the App Store. 3. If iOS reclaimed the `group.screentimeshield` container (the only app in the group was deleted), `trial_start` is absent. 4. First launch: `refreshAccess()` → `accessState(now:, trialStart: nil, hasFullAccess: false)` → `.trial`; `enforcement_allowed = true` is written; `trialDaysRemaining` returns 7. 5. What the user sees: "7 days left in trial · Unlock" and a fully working app; repeatable every week forever, with no code in the app able to notice the repeat.

**User impact**

Unlimited free 7-day trials via a 30-second delete/reinstall, if and when iOS reclaims the app-group container — and the app has no way to detect it.

**API semantics relied on**

Hinges on whether the app-group container is cleared on uninstall. My research points the other way as often as not: developer.apple.com/forums/thread/718449 and several write-ups report that from iOS 16 `UserDefaults(suiteName: "group.…")` is NOT cleared on delete+reinstall (while `UserDefaults.standard` is), and Apple documents no cleanup timing guarantee even when the last group member is removed. So this may not reproduce on current iOS — but the app is relying on undocumented OS behaviour for its entire trial-reset defence, with a receipt-based anchor sitting unused two files away. Cheap to settle: delete, reinstall, read the TrialChip. Note this candidate and the qa_force_full_access one are complementary — whichever way container persistence goes, one of the two bites.

### `F9-INTEG-06` — Trial-ended reminder never fires for users who never dragged the schedule slider

- **Severity** Nit · **Confidence (self-reported)** high · **Invariant** F9.12 · **Needs device** no
- **Anchor** `ScreenTimeShield/AccessController.swift:132`

**Mechanism**

`updateTrialEndedNotification()` bails unless the app group holds a `start` date: `guard let start = kv.date(forKey: "start") else { return }` (ScreenTimeShield/AccessController.swift:132). But `"start"` is only ever written from `Model.start`'s `didSet` (ScreenTimeShield/Model.swift:43-45); the 09:00 default is a computed fallback in the property initialiser (`?? Calendar.current.date(bySettingHour: 9…)`, Model.swift:41-42) and is never persisted. A user who accepts the default window never triggers `didSet`, so the key stays absent and the reminder is silently skipped.

**Failure trace**

1. Fresh install; user picks apps, leaves the default 09:00–17:00 window untouched, taps "Start blocking" — `trial_start` written, `.daily` registered, but `"start"` is never written to the app group. 2. Day 8, user foregrounds: `recomputeAccessState()` → `.expired`, `enforcement_allowed = false`, then `updateTrialEndedNotification()` returns at line 132. 3. Persisted state: no pending `unplug.trial.ended` request. 4. What the user sees: their blocks stop working and they receive no reminder at all — the intended daily 09:00 "Your blocks are off" nudge never exists.

**User impact**

The trial-ended win-back notification is missing for every user who kept the default schedule; they just quietly stop being protected.

**API semantics relied on**

none — pure UserDefaults key-presence logic; `UNCalendarNotificationTrigger` semantics are not involved because the request is never created.

<details><summary>Ruled out by this lens</summary>

**QA menu reachability (F9.12, the "is it genuinely unreachable" question) — clean.** `QAMenuView` is presented only by `SettingsView`'s `.sheet(isPresented: $showQAMenu)` (SettingsView.swift:38-41), and the sole writer of `showQAMenu` is the commented-out button at SettingsView.swift:26-28. A repo-wide grep for `QAMenuView|showQAMenu|qaReset|onOpenURL` finds no other trigger: no URL scheme (no `CFBundleURLSchemes` in any plist), no deep link handler, no shake/long-press debug gesture, no Notification/`UIApplicationDelegate` hook. `qaStartTrial/qaExpireTrial/qaResetTrial/qaSetFullAccess/qaSetTimesStopped/qaResetToFreshInstall` have exactly one caller each, all inside `QAMenuView`. So the *methods* are genuinely dead in production — the surviving problem is the persisted `qa_force_full_access` value they may have left behind (reported), not reachability.

**`UNPLUG_SKIP_FC` in production — clean.** All three uses read `ProcessInfo.processInfo.environment` (AccessController.swift:28, ContentView.swift:260, ScreenTimeShieldApp.swift:100/:112). Environment variables can only be injected by the launching process, i.e. an Xcode/`xcrun simctl` scheme, not by a user on a distributed build, so the FC bypass and the refreshAccess skip cannot fire in the field.

**`enforcement_allowed` defaulting to `true` when absent — intended, not a bug on its own.** DeviceActivityMonitorExtension.swift:42-44 is exactly F9.3 ("a missing value must not disable a paying or grandfathered user's blocks"). I checked the absent-key windows: (a) fresh install before any recompute — correct, the user is in trial; (b) after `qaResetToFreshInstall` wipes the domain — `recomputeAccessState()` runs on the next line (AccessController.swift:203) and rewrites the key `true`, and post-wipe `trial_start` is nil so `.trial` is the right verdict; (c) after a purchase/restore — `purchase()`/`restore()` both recompute (AccessController.swift:101-110). The exploitable problem is not the default, it is that the key is only *refreshed* from the foreground (reported).

**Purchase → gate propagation (F9.6/F9.7) — fine for the paths in my lens.** `purchase()` finishes the transaction then `refreshPurchasedState()` then `recomputeAccessState()`, so the gate flips to `true` before the paywall dismisses; `PaywallView.onChange(of: access.accessState)` (PaywallView.swift:120-122) also dismisses. Revoked purchases are excluded via `revocationDate == nil` (Store.swift:62) and the next foreground recompute writes `enforcement_allowed = false`, so refund abuse does not keep enforcement beyond one foreground cycle. (Absence of a `Transaction.updates` listener is F9.6's cell, not mine.)

**Clock moved *forward* — no exploit found.** It only shortens the trial (`now - trialStart` grows), which is self-harm, and `trialDaysRemaining` clamps at 0 (AccessControl.swift:67). Persisted `trial_start` is never rewritten by any non-QA path (`startTrialIfNeeded` writes only when nil, AccessController.swift:85), so F9.1 holds — a forward jump plus a later correction cannot move the start date.

**Timezone change — no effect.** Everything in the access path compares absolute `Date`s; `Calendar.current` is only used for the notification's hour/minute (AccessController.swift:139), which is intentionally local-time.

**Escaping an *active* block via the entitlement gate — not possible.** The gate is consulted only in `intervalDidStart` (DeviceActivityMonitorExtension.swift:56); `intervalDidEnd` clears unconditionally (:68-79) and nothing in the access layer calls `Model.clearRestrictions()` except `stop()` (ContentView.swift:82-86, disabled while `insideInterval`) and the QA reset. So forcing expiry mid-block (e.g. clock-forward) does not lift shields that are already applied.

</details>

<details><summary>Noted outside lens (uninvestigated)</summary>

- F4/F9 overlap: expiry never unregisters the `.daily` activity (nothing in `recomputeAccessState` calls `Schedule.stopMonitoring`), so after expiry `ContentView.swift:248` still re-derives `isArmed = true` and the CTA reads "Stop blocking" while the extension's gate (DeviceActivityMonitorExtension.swift:56) skips enforcement — the "armed but silently unenforced" state F9.11 forbids. Reported above only as the paying-user consequence; the trial-user version is F9.11's cell.
- `kv.setBool(..., forKey: enforcement_allowed)` (AccessController.swift:118) never calls `synchronize()`, unlike every other cross-process write in `Model` (Model.swift:36/:88). Almost certainly benign given the extension launches minutes later, but it is the one gate write that isn't flushed.
- `qaResetToFreshInstall` (AccessController.swift:191) calls `UserDefaults.standard.removePersistentDomain(forName: "group.screentimeshield")` — the standard suite removing an app-group domain — and the live `AppGroupStore`/`Model` `UserDefaults(suiteName:)` instances are not invalidated afterwards. QA-only path, not investigated.
- `Store.refreshPurchasedState` (Store.swift:58-67) unconditionally assigns `isPurchased = purchased`, so any launch where `Transaction.currentEntitlements` yields nothing (signed-out Apple Account, sandbox hiccup) demotes a real buyer for that session — same lockout shape as candidate 3 but through the purchased path; not separately traced.

</details>

---
