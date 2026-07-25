import XCTest
@testable import UnplugCore

/// Differential tests for `ScheduleMath` against an independent brute-force oracle over the whole
/// 1440-minute domain. Proves V05 (the risk gate measures the window with non-wrapping math while
/// the interval handed to DeviceActivity wraps midnight), V06 (allow-only inversion derives a
/// blocked interval that this math cannot see at all) and the minutes-of-day half of V02.
final class ScheduleMathBoundaryTests: XCTestCase {
  private static let minutesInDay = 1440

  /// Apple's documented floor for `DeviceActivityCenter.startMonitoring`
  /// (`MonitoringError.intervalTooShort`: "The minimum interval length ... is fifteen minutes").
  private static let minimumMonitoringInterval = 15

  private static let riskConfirmationThreshold = 30

  /// Coprime-ish stride so the sampled `now` values do not align with the 5-minute window grid.
  private static let representativeNows = Array(stride(from: 0, to: minutesInDay, by: 37))

  // MARK: - Oracle
  //
  // Derived from the definition of the schedule, not from ScheduleMath: the picked window is the
  // set of minutes you pass through walking the clock forward from `start` until you reach `end`.

  /// Every minute-of-day inside the half-open picked window `[start, end)`, found by walking the
  /// day one minute at a time. Wrapping windows and the empty `start == end` window both fall out
  /// of the walk rather than being special-cased.
  private func windowMinuteSet(start: Int, end: Int) -> Set<Int> {
    var minutes = Set<Int>()
    var minute = start
    while minute != end {
      minutes.insert(minute)
      minute = (minute + 1) % Self.minutesInDay
    }
    return minutes
  }

  /// The minutes the schedule actually blocks: the picked window in Block mode, everything outside
  /// it in Allow-only mode.
  private func blockedMinuteSet(start: Int, end: Int, blockOutsideWindow: Bool) -> Set<Int> {
    let window = windowMinuteSet(start: start, end: end)
    return blockOutsideWindow ? Set(0..<Self.minutesInDay).subtracting(window) : window
  }

  private func oracleFreeMinutes(start: Int, end: Int, blockOutsideWindow: Bool) -> Int {
    Self.minutesInDay - blockedMinuteSet(start: start,
                                         end: end,
                                         blockOutsideWindow: blockOutsideWindow).count
  }

  func testOracleWalksTheDayAsExpected() {
    XCTAssertEqual(windowMinuteSet(start: 540, end: 1020).count, 480)
    XCTAssertEqual(windowMinuteSet(start: 1320, end: 420).count, 540)
    XCTAssertTrue(windowMinuteSet(start: 1320, end: 420).contains(0))
    XCTAssertTrue(windowMinuteSet(start: 1320, end: 420).contains(1320))
    XCTAssertFalse(windowMinuteSet(start: 1320, end: 420).contains(420))
    XCTAssertFalse(windowMinuteSet(start: 1320, end: 420).contains(720))
    XCTAssertEqual(windowMinuteSet(start: 540, end: 540).count, 0)
    XCTAssertEqual(blockedMinuteSet(start: 540, end: 1020, blockOutsideWindow: true).count, 960)
    XCTAssertEqual(blockedMinuteSet(start: 540, end: 540, blockOutsideWindow: true).count, 1440)
  }

  // MARK: - windowContains (V05 control: this half of the pair IS wrap-aware)

  /// V05 control — `windowContains` handles wrapping, so it agrees with the oracle on every minute.
  func testWindowContainsMatchesOracleAcrossEveryMinuteOfKeyWindows() {
    let windows: [(label: String, start: Int, end: Int)] = [
      ("09:00–17:00 same-day", 540, 1020),
      ("22:00–07:00 overnight", 1320, 420),
      ("09:00–08:45 collapsed", 540, 525),
      ("00:00–23:59 near-full-day", 0, 1439),
      ("23:59–00:00 inverted near-full-day", 1439, 0),
      ("23:55–00:05 straddling midnight", 1435, 5),
      ("09:00–09:00 degenerate", 540, 540),
      ("00:00–12:00 first half", 0, 720),
      ("12:00–00:00 second half", 720, 0),
    ]

    for window in windows {
      let blocked = windowMinuteSet(start: window.start, end: window.end)
      for now in 0..<Self.minutesInDay {
        XCTAssertEqual(ScheduleMath.windowContains(now: now, start: window.start, end: window.end),
                       blocked.contains(now),
                       "V05: windowContains disagrees with the oracle at minute \(now) of \(window.label)")
      }
    }
  }

  /// V05 control — 288×288 five-minute windows, each probed at 39 spread minutes plus the four
  /// boundary minutes, to show the wrap-awareness `freeMinutes` is missing.
  func testWindowContainsMatchesOracleForEveryFiveMinuteWindow() {
    var mismatches = 0
    var examples: [String] = []

    for start in stride(from: 0, to: Self.minutesInDay, by: 5) {
      // One walk of the day per `start`: the window grows by five minutes as `end` advances.
      var window = Set<Int>()
      var end = start
      repeat {
        let probes = Self.representativeNows + [start,
                                                (start + Self.minutesInDay - 1) % Self.minutesInDay,
                                                end,
                                                (end + Self.minutesInDay - 1) % Self.minutesInDay]
        for now in probes {
          let actual = ScheduleMath.windowContains(now: now, start: start, end: end)
          let expected = window.contains(now)
          if actual != expected {
            mismatches += 1
            if examples.count < 5 {
              examples.append("now \(now) in [\(start),\(end)) → \(actual), oracle says \(expected)")
            }
          }
        }
        for offset in 0..<5 { window.insert((end + offset) % Self.minutesInDay) }
        end = (end + 5) % Self.minutesInDay
      } while end != start
    }

    XCTAssertEqual(mismatches, 0,
                   "V05: windowContains disagreed with the oracle \(mismatches) times: \(examples)")
  }

  // MARK: - freeMinutes (V05)

  /// V05 — `freeMinutes` must report the same day for every window `windowContains` accepts.
  func testFreeMinutesMatchesOracleForEveryWindowV05() {
    var mismatches = 0
    var wrappingPairs = 0
    var examples: [String] = []

    for start in 0..<Self.minutesInDay {
      // Walk the day forward from `start`. After `visited` steps the window [start, end) covers
      // exactly `visited` minutes, so the free-minute counts follow without any interval formula.
      var visited = 0
      var end = start
      repeat {
        let expectedBlockMode = Self.minutesInDay - visited
        let expectedAllowOnly = visited
        let blockMode = ScheduleMath.freeMinutes(windowStart: start, windowEnd: end, blockOutsideWindow: false)
        let allowOnly = ScheduleMath.freeMinutes(windowStart: start, windowEnd: end, blockOutsideWindow: true)

        if start > end { wrappingPairs += 1 }
        if blockMode != expectedBlockMode || allowOnly != expectedAllowOnly {
          mismatches += 1
          if examples.count < 5 {
            examples.append("[\(start),\(end)): block mode \(blockMode) (should be \(expectedBlockMode)), "
                            + "allow-only \(allowOnly) (should be \(expectedAllowOnly))")
          }
        }

        visited += 1
        end = (end + 1) % Self.minutesInDay
      } while end != start
    }

    XCTAssertEqual(mismatches, 0,
                   "V05: freeMinutes disagreed with the oracle for \(mismatches) of the "
                   + "\(Self.minutesInDay * Self.minutesInDay) windows (\(wrappingPairs) of them wrap "
                   + "midnight, which windowContains and Model.blockedInterval both accept). "
                   + "Examples: \(examples)")
  }

  /// V05 — a legacy 22:00→07:00 overnight window: 9h blocked, 15h free, in either mode's terms.
  func testFreeMinutesForOvernightWindowV05() {
    let start = 1320
    let end = 420

    XCTAssertEqual(oracleFreeMinutes(start: start, end: end, blockOutsideWindow: false), 900)
    XCTAssertEqual(oracleFreeMinutes(start: start, end: end, blockOutsideWindow: true), 540)

    XCTAssertEqual(ScheduleMath.freeMinutes(windowStart: start, windowEnd: end, blockOutsideWindow: false), 900,
                   "V05: blocking 22:00→07:00 leaves 15h free, so the risk gate must see 900 free minutes")
    XCTAssertEqual(ScheduleMath.freeMinutes(windowStart: start, windowEnd: end, blockOutsideWindow: true), 540,
                   "V05: allowing only 22:00→07:00 leaves 9h free, so the risk gate must see 540 free minutes")
  }

  /// V05 — the 09:00→08:45 window from the finding's trace B: 1425 blocked, 15 free, must confirm.
  func testCollapsedWindowTripsRiskConfirmationV05() {
    let free = ScheduleMath.freeMinutes(windowStart: 540, windowEnd: 525, blockOutsideWindow: false)

    XCTAssertEqual(oracleFreeMinutes(start: 540, end: 525, blockOutsideWindow: false), 15)
    XCTAssertEqual(free, 15,
                   "V05: a 09:00→08:45 block covers 1425 minutes of the day, leaving 15 free")
    XCTAssertLessThanOrEqual(free, Self.riskConfirmationThreshold,
                             "V05/F4.11: \(free) free minutes must trip the ≤\(Self.riskConfirmationThreshold)-minute "
                             + "arm confirmation; reporting a whole free day suppresses it entirely")
  }

  // MARK: - Allow-only inversion (V06)

  /// V06 — allow 00:00–23:59 registers the inverted interval 23:59→00:00; that is a 1-minute block,
  /// below DeviceActivity's 15-minute minimum, and the math must not score it as no block at all.
  func testAllowOnlyInversionDerivesShortBlockedIntervalV06() {
    // Model.blockedInterval hands (start: end, end: start) to Schedule in allow-only mode.
    let registeredFree = ScheduleMath.freeMinutes(windowStart: 1439, windowEnd: 0, blockOutsideWindow: false)

    XCTAssertEqual(oracleFreeMinutes(start: 1439, end: 0, blockOutsideWindow: false), 1439)
    XCTAssertEqual(registeredFree, 1439,
                   "V06: the interval actually registered for an allow-only 00:00–23:59 window is "
                   + "23:59→00:00, i.e. 1 blocked minute and 1439 free — reporting \(registeredFree) free "
                   + "means the derived block is measured as zero-length, so nothing can notice that "
                   + "it is under the \(Self.minimumMonitoringInterval)-minute monitoring minimum and "
                   + "will be rejected by startMonitoring")
  }

  /// V06 — a wrapping allow-only window hides the same defect: 23:50→23:45 allows 1435 minutes and
  /// blocks 5, but the math reports the whole day blocked.
  func testAllowOnlyWrappingWindowHidesShortBlockedIntervalV06() {
    let free = ScheduleMath.freeMinutes(windowStart: 1430, windowEnd: 1425, blockOutsideWindow: true)

    XCTAssertEqual(oracleFreeMinutes(start: 1430, end: 1425, blockOutsideWindow: true), 1435)
    XCTAssertEqual(free, 1435,
                   "V06: allowing 23:50→23:45 leaves 1435 minutes free and derives a 5-minute blocked "
                   + "interval — under the \(Self.minimumMonitoringInterval)-minute minimum — yet "
                   + "freeMinutes reports \(free), i.e. a full-day block")
  }

  /// V06/F3.6 — allow-only over a window must equal Block mode over the inverted interval that is
  /// what actually gets registered. Excludes `start == end`, where the two modes legitimately
  /// differ (an empty window blocks nothing in Block mode and the whole day in Allow-only).
  func testAllowOnlyMatchesBlockModeOverInvertedIntervalV06() {
    var mismatches = 0
    var examples: [String] = []

    for start in stride(from: 0, to: Self.minutesInDay, by: 5) {
      for end in stride(from: 0, to: Self.minutesInDay, by: 5) where start != end {
        let allowOnly = ScheduleMath.freeMinutes(windowStart: start, windowEnd: end, blockOutsideWindow: true)
        let invertedBlock = ScheduleMath.freeMinutes(windowStart: end, windowEnd: start, blockOutsideWindow: false)
        if allowOnly != invertedBlock {
          mismatches += 1
          if examples.count < 5 {
            examples.append("allow-only [\(start),\(end)) → \(allowOnly) free, but the registered "
                            + "interval [\(end),\(start)) → \(invertedBlock) free")
          }
        }
      }
    }

    XCTAssertEqual(mismatches, 0,
                   "V06/F3.6: \(mismatches) windows where the free time the gate reports for allow-only "
                   + "mode contradicts the free time implied by the interval Model.blockedInterval "
                   + "actually registers. Examples: \(examples)")
  }

  // MARK: - Time-zone drift (V02, minutes-of-day half only)

  /// V02 — when the two handles were last minted in different UTC offsets, re-deriving hour/minute
  /// inverts the pair, and the drifted window must still be measured for what it is.
  func testWindowInvertedByTimeZoneDriftIsStillMeasuredV02() {
    // Allow-only 09:00–09:15. The end instant was minted before an autumn rollover, so it re-reads
    // one hour earlier: the pair becomes (09:00, 08:15) and now wraps midnight.
    let driftedStart = 540
    let driftedEnd = 495

    XCTAssertEqual(oracleFreeMinutes(start: driftedStart, end: driftedEnd, blockOutsideWindow: true), 1395)
    XCTAssertEqual(ScheduleMath.freeMinutes(windowStart: driftedStart,
                                            windowEnd: driftedEnd,
                                            blockOutsideWindow: true), 1395,
                   "V02: after the offset delta inverts the handles, the allow window covers 1395 of "
                   + "the day's minutes (a 45-minute block) — reporting 0 free minutes claims a "
                   + "full-day lockout that neither the oracle nor the registered interval describes")
  }
}
