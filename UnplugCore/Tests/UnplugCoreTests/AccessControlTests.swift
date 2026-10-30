//
//  AccessControlTests.swift
//  ScreenTimeShieldTests
//
//  Unit tests for the pure trial/access/stat logic.
//

import XCTest
import UnplugCore

final class AccessControlTests: XCTestCase {

  private let day0 = Date(timeIntervalSince1970: 1_700_000_000)

  private func calendar(_ timeZone: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZone)!
    return calendar
  }

  private func date(_ calendar: Calendar, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour, minute: minute))!
  }

  // MARK: AccessEvaluator

  func testTrialEndsAtMidnightAfterTheFreeFirstDayAndSevenFullDays() {
    let utc = calendar("UTC")
    let armedMondayNight = date(utc, 11, 2, 23, 10)
    XCTAssertEqual(AccessEvaluator.trialEnd(trialStart: armedMondayNight, trialDays: 7, calendar: utc),
                   date(utc, 11, 10, 0))
  }

  func testTrialRunsUntilTheLastMinuteThenExpiresAtMidnight() {
    let utc = calendar("UTC")
    let start = date(utc, 11, 2, 23, 10)
    let lastMinute = date(utc, 11, 9, 23, 59)
    XCTAssertEqual(AccessEvaluator.accessState(now: lastMinute, trialStart: start, hasFullAccess: false,
                                               trialDays: 7, calendar: utc), .trial)
    XCTAssertEqual(AccessEvaluator.trialDaysRemaining(now: lastMinute, trialStart: start,
                                                      trialDays: 7, calendar: utc), 1)
    XCTAssertEqual(AccessEvaluator.accessState(now: date(utc, 11, 10, 0), trialStart: start, hasFullAccess: false,
                                               trialDays: 7, calendar: utc), .expired)
  }

  func testDaysRemainingCountsCalendarDaysAndTheFirstDayIsFree() {
    let utc = calendar("UTC")
    let start = date(utc, 11, 2, 23, 10)
    let remaining = [(11, 2), (11, 3), (11, 4), (11, 9)].map { month, day in
      AccessEvaluator.trialDaysRemaining(now: date(utc, month, day, 12), trialStart: start,
                                         trialDays: 7, calendar: utc)
    }
    XCTAssertEqual(remaining, [7, 7, 6, 1])
  }

  func testTrialEndsAtLocalMidnightAcrossADSTChange() {
    // Irish clocks go back on 2026-10-25, so this trial is 1 hour longer than 8 × 24 h.
    let dublin = calendar("Europe/Dublin")
    let end = AccessEvaluator.trialEnd(trialStart: date(dublin, 10, 22, 15), trialDays: 7, calendar: dublin)
    XCTAssertEqual(end, date(dublin, 10, 30, 0))
  }

  func testFullAccessShortCircuitsRegardlessOfTrial() {
    let now = day0.addingTimeInterval(99 * 24 * 60 * 60) // long after expiry
    XCTAssertEqual(AccessEvaluator.accessState(now: now, trialStart: day0, hasFullAccess: true,
                                               trialDays: 7, calendar: calendar("UTC")), .fullAccess)
  }

  func testNilTrialStartButFullAccessIsFullAccess() {
    XCTAssertEqual(AccessEvaluator.accessState(now: day0, trialStart: nil, hasFullAccess: true,
                                               trialDays: 7, calendar: calendar("UTC")), .fullAccess)
  }

  func testNilTrialStartWithoutAccessIsTrial() {
    // Trial hasn't been started yet (no first block) and no purchase ⇒ still in trial-eligible state.
    XCTAssertEqual(AccessEvaluator.accessState(now: day0, trialStart: nil, hasFullAccess: false,
                                               trialDays: 7, calendar: calendar("UTC")), .trial)
    XCTAssertEqual(AccessEvaluator.trialDaysRemaining(now: day0, trialStart: nil,
                                                      trialDays: 7, calendar: calendar("UTC")), 7)
  }

  func testTrialDaysRemainingNeverNegative() {
    let now = day0.addingTimeInterval(20 * 24 * 60 * 60)
    XCTAssertEqual(AccessEvaluator.trialDaysRemaining(now: now, trialStart: day0,
                                                      trialDays: 7, calendar: calendar("UTC")), 0)
  }

  // MARK: Grandfather

  private let cutover = Date(timeIntervalSince1970: 1_781_740_800) // matches PricingConfig.cutoverDate placeholder

  func testGrandfatheredWhenOriginalPurchasePredatesCutover() {
    let before = cutover.addingTimeInterval(-24 * 60 * 60) // one day before
    XCTAssertTrue(Grandfather.isGrandfathered(originalPurchaseDate: before, cutoverDate: cutover))
  }

  func testNotGrandfatheredWhenOriginalPurchaseEqualsCutover() {
    XCTAssertFalse(Grandfather.isGrandfathered(originalPurchaseDate: cutover, cutoverDate: cutover))
  }

  func testNotGrandfatheredWhenOriginalPurchaseAfterCutover() {
    let after = cutover.addingTimeInterval(24 * 60 * 60) // one day after
    XCTAssertFalse(Grandfather.isGrandfathered(originalPurchaseDate: after, cutoverDate: cutover))
  }

  func testNotGrandfatheredWhenOriginalPurchaseMissing() {
    XCTAssertFalse(Grandfather.isGrandfathered(originalPurchaseDate: nil, cutoverDate: cutover))
  }

  // MARK: StatGate

  func testStatHiddenBelowThreshold() {
    XCTAssertFalse(StatGate.shouldShowStat(timesStopped: 4, threshold: 5))
  }

  func testStatShownAtThreshold() {
    XCTAssertTrue(StatGate.shouldShowStat(timesStopped: 5, threshold: 5))
  }

  func testStatShownAboveThreshold() {
    XCTAssertTrue(StatGate.shouldShowStat(timesStopped: 23, threshold: 5))
  }

  // MARK: StopDebouncer

  func testFirstStopAlwaysCounts() {
    XCTAssertTrue(StopDebouncer.shouldCount(now: day0, lastLogged: nil, cooldown: 60))
  }

  func testStopWithinCooldownIsSkipped() {
    let now = day0.addingTimeInterval(30)
    XCTAssertFalse(StopDebouncer.shouldCount(now: now, lastLogged: day0, cooldown: 60))
  }

  func testStopBeyondCooldownCounts() {
    let now = day0.addingTimeInterval(90)
    XCTAssertTrue(StopDebouncer.shouldCount(now: now, lastLogged: day0, cooldown: 60))
  }
}
