//
//  AccessControlTests.swift
//  ScreenTimeShieldTests
//
//  Unit tests for the pure trial/access/stat logic.
//

import XCTest
import UnplugCore

final class AccessControlTests: XCTestCase {

  private let sevenDays: TimeInterval = 7 * 24 * 60 * 60
  private let day0 = Date(timeIntervalSince1970: 1_700_000_000)

  // MARK: AccessEvaluator

  func testTrialActiveWithinSevenDays() {
    let now = day0.addingTimeInterval(3 * 24 * 60 * 60) // day 3
    let state = AccessEvaluator.accessState(now: now,
                                            trialStart: day0,
                                            hasFullAccess: false,
                                            trialLength: sevenDays)
    XCTAssertEqual(state, .trial)
  }

  func testTrialExpiresAfterSevenDays() {
    let now = day0.addingTimeInterval(8 * 24 * 60 * 60) // day 8
    let state = AccessEvaluator.accessState(now: now,
                                            trialStart: day0,
                                            hasFullAccess: false,
                                            trialLength: sevenDays)
    XCTAssertEqual(state, .expired)
  }

  func testFullAccessShortCircuitsRegardlessOfTrial() {
    let now = day0.addingTimeInterval(99 * 24 * 60 * 60) // long after expiry
    let state = AccessEvaluator.accessState(now: now,
                                            trialStart: day0,
                                            hasFullAccess: true,
                                            trialLength: sevenDays)
    XCTAssertEqual(state, .fullAccess)
  }

  func testNilTrialStartButFullAccessIsFullAccess() {
    let state = AccessEvaluator.accessState(now: day0,
                                            trialStart: nil,
                                            hasFullAccess: true,
                                            trialLength: sevenDays)
    XCTAssertEqual(state, .fullAccess)
  }

  func testNilTrialStartWithoutAccessIsTrial() {
    // Trial hasn't been started yet (no first block) and no purchase ⇒ still in trial-eligible state.
    let state = AccessEvaluator.accessState(now: day0,
                                            trialStart: nil,
                                            hasFullAccess: false,
                                            trialLength: sevenDays)
    XCTAssertEqual(state, .trial)
  }

  func testExactExpiryBoundaryIsExpired() {
    let now = day0.addingTimeInterval(sevenDays) // exactly at end
    let state = AccessEvaluator.accessState(now: now,
                                            trialStart: day0,
                                            hasFullAccess: false,
                                            trialLength: sevenDays)
    XCTAssertEqual(state, .expired)
  }

  func testTrialDaysRemainingRoundsUp() {
    let now = day0.addingTimeInterval(2.5 * 24 * 60 * 60) // 4.5 days left
    XCTAssertEqual(AccessEvaluator.trialDaysRemaining(now: now,
                                                      trialStart: day0,
                                                      trialLength: sevenDays), 5)
  }

  func testTrialDaysRemainingNeverNegative() {
    let now = day0.addingTimeInterval(20 * 24 * 60 * 60)
    XCTAssertEqual(AccessEvaluator.trialDaysRemaining(now: now,
                                                      trialStart: day0,
                                                      trialLength: sevenDays), 0)
  }

  // MARK: Grandfather

  func testGrandfatheredWhenOriginalBelowCutover() {
    XCTAssertTrue(Grandfather.isGrandfathered(originalVersion: "8", cutoverBuild: 12))
  }

  func testNotGrandfatheredWhenOriginalEqualsCutover() {
    XCTAssertFalse(Grandfather.isGrandfathered(originalVersion: "12", cutoverBuild: 12))
  }

  func testNotGrandfatheredWhenOriginalAboveCutover() {
    XCTAssertFalse(Grandfather.isGrandfathered(originalVersion: "15", cutoverBuild: 12))
  }

  func testNotGrandfatheredWhenOriginalMissing() {
    XCTAssertFalse(Grandfather.isGrandfathered(originalVersion: nil, cutoverBuild: 12))
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
