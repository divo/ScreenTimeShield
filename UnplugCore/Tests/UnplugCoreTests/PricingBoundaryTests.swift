//
//  PricingBoundaryTests.swift
//  UnplugCoreTests
//
//  Regression tests for the QA-pass findings against the pricing layer:
//  V22 (stale cutoverDate vs. the unshipped IAP build) and V23 (expired trial
//  restored by a backdated clock). Unlike AccessControlTests, the cutover cases
//  here assert against the PRODUCTION `PricingConfig.cutoverDate` — a private copy
//  of the constant is exactly why the shipped value can rot while `swift test` is green.
//

import XCTest
import UnplugCore

final class PricingBoundaryTests: XCTestCase {

  private let day: TimeInterval = 24 * 60 * 60
  private let sevenDays: TimeInterval = 7 * 24 * 60 * 60

  /// 2026-08-01 00:00 UTC. A day on which the live App Store build was still the pre-IAP
  /// paid build: the lifetime IAP was "Ready to Submit" and 1.3 had been pulled from review
  /// on 2026-06-19 (status.md). Anyone who paid $0.99 on this day bought the pre-IAP app and
  /// must therefore be grandfathered. Pinned as a literal rather than read from `Date()` so
  /// the verdict is deterministic; **bump it to the submission day whenever the release slips**,
  /// otherwise this guard silently stops covering the buyers who came after it.
  private let lastDayThePreIAPBuildWasOnSale = Date(timeIntervalSince1970: 1_785_542_400)

  /// 2026-07-01 00:00 UTC — the concrete buyer in V22's failure trace.
  private let midGapPurchase = Date(timeIntervalSince1970: 1_782_864_000)

  /// 2026-06-25 00:00 UTC — the release date `PricingConfig.cutoverDate` was pinned to, which
  /// slipped. Written as a literal, not read from the production constant, so this stays a
  /// statement about a real day rather than a self-referential tautology.
  private let slippedTargetReleaseDay = Date(timeIntervalSince1970: 1_782_345_600)

  // MARK: V22 — release-safety invariant on PricingConfig.cutoverDate

  func testV22_cutoverDateMustNotPredateTheLastPreIAPSaleDay() {
    // V22: the grandfathering promise only holds if the cutover postdates every pre-IAP purchase.
    XCTAssertGreaterThan(
      PricingConfig.cutoverDate, lastDayThePreIAPBuildWasOnSale,
      """
      V22: PricingConfig.cutoverDate is 2026-06-25, but the pre-IAP paid build was still the \
      only build on sale on 2026-07-25. Every $0.99 buyer in that gap is treated as a post-IAP \
      user: 7-day trial, then enforcement_allowed = false and a $4.99 paywall, with no restore path. \
      DO ONE OF TWO THINGS: (1) move PricingConfig.cutoverDate to the actual 1.3 App Store release \
      date — it must be set or re-verified at submission time, not once — or (2) accept the cohort \
      deliberately, and delete this test with a note in status.md saying who is being written off.
      """)
  }

  func testV22_everyBuyerInTheReleaseGapIsGrandfathered() {
    // V22: no purchase made while only the pre-IAP build shipped may fall outside grandfathering.
    let gapPurchases: [(String, Date)] = [
      ("2026-06-25 (the slipped target release day — 1.3 did not ship)", slippedTargetReleaseDay),
      ("2026-07-01 (V22's traced buyer)", midGapPurchase),
      ("2026-08-01 (last confirmed pre-IAP sale day)", lastDayThePreIAPBuildWasOnSale),
    ]
    for (label, purchase) in gapPurchases {
      XCTAssertTrue(
        Grandfather.isGrandfathered(originalPurchaseDate: purchase, cutoverDate: PricingConfig.cutoverDate),
        "V22: a customer who paid for the pre-IAP app on \(label) is not grandfathered.")
    }
  }

  // MARK: V22 — cutover boundary (F9.13: exact and total), asserted relative to the production constant

  func testV22Boundary_oneSecondBeforeCutoverIsGrandfathered() {
    // V22 boundary guard: the half-open cutover must survive the date being moved.
    let justBefore = PricingConfig.cutoverDate.addingTimeInterval(-1)
    XCTAssertTrue(Grandfather.isGrandfathered(originalPurchaseDate: justBefore,
                                              cutoverDate: PricingConfig.cutoverDate))
  }

  func testV22Boundary_exactlyAtCutoverIsNotGrandfathered() {
    // V22 boundary guard: the cutover instant belongs to the IAP era, not the legacy era.
    XCTAssertFalse(Grandfather.isGrandfathered(originalPurchaseDate: PricingConfig.cutoverDate,
                                               cutoverDate: PricingConfig.cutoverDate))
  }

  func testV22Boundary_oneSecondAfterCutoverIsNotGrandfathered() {
    // V22 boundary guard: fixing the date must not turn the comparison inclusive.
    let justAfter = PricingConfig.cutoverDate.addingTimeInterval(1)
    XCTAssertFalse(Grandfather.isGrandfathered(originalPurchaseDate: justAfter,
                                               cutoverDate: PricingConfig.cutoverDate))
  }

  func testV22Boundary_missingOriginalPurchaseDateIsNotGrandfathered() {
    // V22 boundary guard: the nil case stays defined (F9.13 totality), never an accidental grant.
    XCTAssertFalse(Grandfather.isGrandfathered(originalPurchaseDate: nil,
                                               cutoverDate: PricingConfig.cutoverDate))
  }

  func testV22Boundary_distantPastIsGrandfatheredAndDistantFutureIsNot() {
    // V22 boundary guard: the decision is total across the whole date range, with no wraparound.
    XCTAssertTrue(Grandfather.isGrandfathered(originalPurchaseDate: .distantPast,
                                              cutoverDate: PricingConfig.cutoverDate))
    XCTAssertFalse(Grandfather.isGrandfathered(originalPurchaseDate: .distantFuture,
                                               cutoverDate: PricingConfig.cutoverDate))
  }

  // MARK: V23 — an expired trial must not be restored by a backdated clock
  //
  // ACCEPTED RISK, 2026-07-26. Steven's call: "That's fine, no one will bother doing that." Rolling
  // the device clock back does revive an expired trial, and we are choosing to live with it — it
  // takes a deliberate trip into Settings and the prize is one $4.99 unlock.
  //
  // The two tests below therefore assert behaviour the app does NOT have, and are marked as expected
  // failures rather than deleted: the reasoning stays discoverable, and if anything ever makes
  // accessState monotonic these turn into unexpected passes and ask to be re-enabled.
  //
  // Closing it properly is roughly five lines — persist a high-water mark of the largest instant
  // seen and never let `now` regress below it — worth doing if the Keychain work (V18/V25) lands
  // and this code is open anyway.

  func testV23_expiredTrialIsNotRestoredWhenTheSuppliedInstantMovesBackwards() {
    XCTExpectFailure("V23 accepted as won't-fix on 2026-07-26 — see the note above this test.")

    // V23: accessState has no monotonic anchor, so a decreasing `now` currently revives the trial.
    let trialStart = midGapPurchase

    let atDay8 = AccessEvaluator.accessState(now: trialStart.addingTimeInterval(8 * day),
                                            trialStart: trialStart,
                                            hasFullAccess: false,
                                            trialLength: sevenDays)
    XCTAssertEqual(atDay8, .expired, "V23 precondition: the trial must be expired on day 8.")

    // Settings → General → Date & Time, "Set Automatically" off, date set to 2026-06-20.
    let afterRollback = AccessEvaluator.accessState(now: trialStart.addingTimeInterval(-11 * day),
                                                   trialStart: trialStart,
                                                   hasFullAccess: false,
                                                   trialLength: sevenDays)
    XCTAssertEqual(afterRollback, .expired,
                   """
                   V23: rolling the device clock back to before trial_start restored the expired \
                   trial. `now.timeIntervalSince(trialStart) < trialLength` is a signed compare with \
                   no lower bound, so a negative elapsed interval reads as "in trial" and the app \
                   re-persists enforcement_allowed = true. A supplied instant earlier than \
                   trial_start is impossible on an honest clock and must be treated as expired.
                   """)
  }

  func testV23_noInstantBeforeTrialStartYieldsTrial() {
    XCTExpectFailure("V23 accepted as won't-fix on 2026-07-26 — see the note above.")

    // V23: sweep the supplied instant downwards past trial_start; none of it may read as .trial.
    let trialStart = midGapPurchase
    let offsets: [TimeInterval] = [8 * day, -1, -60, -day, -11 * day, -365 * day]
    var expiryObserved = false
    for offset in offsets {
      let state = AccessEvaluator.accessState(now: trialStart.addingTimeInterval(offset),
                                             trialStart: trialStart,
                                             hasFullAccess: false,
                                             trialLength: sevenDays)
      if state == .expired { expiryObserved = true }
      XCTAssertEqual(state, .expired,
                     "V23: now = trialStart \(offset)s reads as \(state), expected .expired — the "
                     + "trial must not be open past day 7, nor for any instant before trial_start.")
    }
    XCTAssertTrue(expiryObserved)
  }

  func testV23_instantExactlyAtTrialStartIsStillTrial() {
    // V23 guard: the fix must reject negative elapsed time only — day 0 is a legitimate trial.
    let state = AccessEvaluator.accessState(now: midGapPurchase,
                                           trialStart: midGapPurchase,
                                           hasFullAccess: false,
                                           trialLength: sevenDays)
    XCTAssertEqual(state, .trial)
  }

  func testV23_fullAccessSurvivesABackdatedClock() {
    // V23 guard: the tamper fix must not demote a paying or grandfathered user.
    let state = AccessEvaluator.accessState(now: midGapPurchase.addingTimeInterval(-11 * day),
                                           trialStart: midGapPurchase,
                                           hasFullAccess: true,
                                           trialLength: sevenDays)
    XCTAssertEqual(state, .fullAccess)
  }

  func testV23_trialDaysRemainingNeverExceedsTheTrialLength() {
    // V23: the same unbounded subtraction prints "18 days left" in a 7-day trial (F9.10).
    let trialStart = midGapPurchase
    let days = AccessEvaluator.trialDaysRemaining(now: trialStart.addingTimeInterval(-11 * day),
                                                  trialStart: trialStart,
                                                  trialLength: sevenDays)
    XCTAssertLessThanOrEqual(days, 7,
                             """
                             V23: trialDaysRemaining returned \(days) for a 7-day trial because \
                             `trialLength - now.timeIntervalSince(trialStart)` has no upper clamp. \
                             A backdated clock must never inflate the count shown in TrialChip.
                             """)
    XCTAssertGreaterThanOrEqual(days, 0)
  }
}
