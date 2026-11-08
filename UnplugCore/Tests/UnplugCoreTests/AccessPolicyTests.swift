//
//  AccessPolicyTests.swift
//  UnplugCoreTests
//
//  The 1.3 access rules: trial from the first block, capped in the real App Store by Apple's download
//  date; grandfathering only in production; full access from the granting purchase until Apple
//  reports that exact purchase refunded. See qa/design/trial-iap.md.
//

import XCTest
import UnplugCore

final class AccessPolicyTests: XCTestCase {

  private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
  }()

  private func date(_ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
    utc.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
  }

  private lazy var terms = AccessTerms(trialDays: 7, trialStartGraceDays: 14, cutover: date(11, 20, 0))

  private let realisticOriginalID: UInt64 = 2_000_000_812_345_678

  private func production(downloaded: Date) -> AppleFacts {
    AppleFacts().withAppTransaction(downloadDate: downloaded, isProduction: true)
  }

  private func sandbox() -> AppleFacts {
    AppleFacts().withAppTransaction(downloadDate: Date(timeIntervalSince1970: 1_375_340_400), isProduction: false) // Apple's fixed 2013 date
  }

  private func state(_ now: Date, start: Date?, _ facts: AppleFacts) -> AccessState {
    AccessPolicy.accessState(now: now, trialStart: start, facts: facts, terms: terms, calendar: utc)
  }

  // MARK: Grandfathering

  func testA12BuyerInTheRealAppStoreHasFullAccess() {
    XCTAssertEqual(state(date(12, 1), start: nil, production(downloaded: date(3, 1))), .fullAccess)
  }

  func testTheFixed2013SandboxDateNeverGrandfathers() {
    XCTAssertEqual(state(date(12, 1), start: nil, sandbox()), .trial)
  }

  func testADownloadOnTheCutoverIsNotGrandfathered() {
    XCTAssertFalse(AccessPolicy.isGrandfathered(production(downloaded: date(11, 20, 0)), terms: terms))
  }

  // MARK: Purchase and refunds

  func testThePurchaseGrantsFullAccessEvenAfterTheTrialEnded() {
    XCTAssertEqual(state(date(12, 30), start: date(11, 1), sandbox().granting(originalID: 42)), .fullAccess)
  }

  func testARefundNeverRemovesGrandfatheredAccess() {
    let facts = production(downloaded: date(3, 1)).granting(originalID: 42).revoking(originalID: 42)
    XCTAssertEqual(state(date(12, 1), start: nil, facts), .fullAccess)
  }

  func testOnlyARefundOfTheGrantingPurchaseRevokes() {
    let bought = AppleFacts().granting(originalID: 42)
    XCTAssertEqual(bought.revoking(originalID: 7).grantingOriginalID, 42)
    XCTAssertNil(bought.revoking(originalID: 42).grantingOriginalID)
  }

  func testAnEmptyPurchaseHistoryNeverRevokes() {
    let bought = AppleFacts().granting(originalID: 42)
    XCTAssertEqual(bought.mergingLifetimeHistory([]).grantingOriginalID, 42)
  }

  func testThePurchaseHistoryGrantsOnAReinstallAndRevokesARefundedGrant() {
    let reinstalled = AppleFacts().mergingLifetimeHistory([.init(originalID: 42, isRevoked: false)])
    XCTAssertEqual(reinstalled.grantingOriginalID, 42)
    XCTAssertNil(reinstalled.mergingLifetimeHistory([.init(originalID: 42, isRevoked: true)]).grantingOriginalID)
  }

  func testARePurchaseReplacesARefundedGrantWhateverTheHistoryOrder() {
    let refunded = AppleFacts().granting(originalID: 42)
    let revokedFirst: [LifetimePurchase] = [.init(originalID: 42, isRevoked: true), .init(originalID: 43, isRevoked: false)]
    XCTAssertEqual(refunded.mergingLifetimeHistory(revokedFirst).grantingOriginalID, 43)
    XCTAssertEqual(refunded.mergingLifetimeHistory(revokedFirst.reversed()).grantingOriginalID, 43)
  }

  func testARefundedOldPurchaseDoesNotUndoANewOne() {
    let rebought = AppleFacts().granting(originalID: 43)
    let history: [LifetimePurchase] = [.init(originalID: 42, isRevoked: true), .init(originalID: 43, isRevoked: false)]
    XCTAssertEqual(rebought.mergingLifetimeHistory(history).grantingOriginalID, 43)
    XCTAssertEqual(rebought.mergingLifetimeHistory([.init(originalID: 42, isRevoked: true)]).grantingOriginalID, 43)
  }

  func testEachVerifiedAppTransactionReplacesTheLastOne() {
    let facts = sandbox().granting(originalID: 42).withAppTransaction(downloadDate: date(3, 1), isProduction: true)
    XCTAssertEqual(facts, production(downloaded: date(3, 1)).granting(originalID: 42))
  }

  func testTheStoredFormatIsPinned() throws {
    let stored = Data(#"{"downloadDate":805075200,"isProduction":true,"grantingOriginalID":2000000812345678}"#.utf8)
    XCTAssertEqual(try AppleFacts(storedData: stored),
                   production(downloaded: date(7, 7, 0)).granting(originalID: realisticOriginalID))
  }

  func testFactsSurviveTheirStoredForm() throws {
    let facts = production(downloaded: date(3, 1)).granting(originalID: realisticOriginalID)
    XCTAssertEqual(try AppleFacts(storedData: facts.storedData()), facts)
    XCTAssertNil(try? AppleFacts(storedData: Data("garbage".utf8)))
  }

  func testShippedTermsAreSevenDaysWithAFourteenDayStartWindow() {
    XCTAssertEqual(AccessTerms.current.trialDays, 7)
    XCTAssertEqual(AccessTerms.current.trialStartGraceDays, 14)
  }

  // MARK: Trial clock

  func testApplesFixed2013SandboxDateNeverCapsTheTrial() {
    let start = date(11, 2, 23)
    XCTAssertEqual(state(date(11, 9, 23), start: start, sandbox()), .trial)
    XCTAssertEqual(state(date(11, 10, 0), start: start, sandbox()), .expired)
  }

  func testInProductionEvenALateStoredStartEndsByDownloadPlusTwentyOneDays() {
    // A start after the last start day can't come from a first block; it can from an account switch
    // to an earlier download date. The ceiling still holds.
    let facts = production(downloaded: date(12, 1))
    let lateStart = date(12, 20)
    XCTAssertEqual(state(date(12, 22, 23), start: lateStart, facts), .trial)
    XCTAssertEqual(state(date(12, 23, 0), start: lateStart, facts), .expired)
  }

  func testAReinstallInsideTheStartWindowGivesAFreshTrialWithinTheCeiling() {
    let facts = production(downloaded: date(12, 1))
    XCTAssertEqual(AccessPolicy.trialEnd(trialStart: date(12, 10), facts: facts, terms: terms, calendar: utc),
                   date(12, 18, 0))
  }

  func testAFirstBlockOnTheLastAllowedDayStillGetsTheFullSevenDays() {
    let facts = production(downloaded: date(12, 1))
    XCTAssertEqual(AccessPolicy.trialEnd(trialStart: date(12, 15, 23), facts: facts, terms: terms, calendar: utc),
                   date(12, 23, 0))
  }

  func testWithoutAStartTheTrialLapsesWhenTheLastStartDayPasses() {
    let facts = production(downloaded: date(12, 1))
    XCTAssertEqual(state(date(12, 15, 23), start: nil, facts), .trial)
    XCTAssertEqual(state(date(12, 16, 0), start: nil, facts), .expired)
  }

  func testWithNothingKnownTheTrialNeverLapses() {
    XCTAssertEqual(state(date(12, 30), start: nil, AppleFacts()), .trial)
  }

  func testDaysLeftBeforeTheFirstBlockShowTheFullTrialUntilTheLastStartDay() {
    let facts = production(downloaded: date(12, 1))
    func daysLeft(_ now: Date) -> Int {
      AccessPolicy.trialDaysRemaining(now: now, trialStart: nil, facts: facts, terms: terms, calendar: utc)
    }
    XCTAssertEqual(daysLeft(date(12, 15, 23)), 7)
    XCTAssertEqual(daysLeft(date(12, 16, 0)), 0)
  }

  func testDaysLeftNeverExceedTheTrialLength() {
    func daysLeft(_ now: Date) -> Int {
      AccessPolicy.trialDaysRemaining(now: now, trialStart: date(11, 2), facts: sandbox(), terms: terms, calendar: utc)
    }
    XCTAssertEqual(daysLeft(date(11, 2)), 7)
    XCTAssertEqual(daysLeft(date(10, 20)), 7)
  }

  func testDaysLeftCountDownToTheCappedEnd() {
    let facts = production(downloaded: date(12, 1))
    XCTAssertEqual(AccessPolicy.trialDaysRemaining(now: date(12, 20), trialStart: date(12, 20), facts: facts,
                                                   terms: terms, calendar: utc), 3)
  }

  // MARK: First block

  private func firstBlock(_ now: Date, start: Date?, _ facts: AppleFacts) -> FirstBlockDecision {
    AccessPolicy.firstBlock(now: now, trialStart: start, facts: facts, terms: terms, calendar: utc)
  }

  func testAPurchaserWhoNeverBlockedArmsWithoutATrialEvenPastTheLastStartDay() {
    XCTAssertEqual(firstBlock(date(12, 30), start: nil, production(downloaded: date(12, 1)).granting(originalID: 42)),
                   .arm)
  }

  func testAnOldBuyerArmsWithoutATrial() {
    XCTAssertEqual(firstBlock(date(12, 1), start: nil, production(downloaded: date(3, 1))), .arm)
  }

  func testWithoutAnAppleAnswerTheAppMustAskFirst() {
    XCTAssertEqual(firstBlock(date(12, 1), start: nil, AppleFacts()), .askApple)
  }

  func testANewUserStartsTheTrialWithTheNotice() {
    XCTAssertEqual(firstBlock(date(12, 10), start: nil, production(downloaded: date(12, 1))), .startTrial)
    XCTAssertEqual(firstBlock(date(12, 10), start: nil, sandbox()), .startTrial)
  }

  func testALateFirstBlockOpensTheUnlockScreen() {
    let facts = production(downloaded: date(12, 1))
    XCTAssertEqual(firstBlock(date(12, 15, 23), start: nil, facts), .startTrial)
    XCTAssertEqual(firstBlock(date(12, 16, 0), start: nil, facts), .unlock)
  }

  func testAPurchaserWhoseTrialEndedArms() {
    XCTAssertEqual(firstBlock(date(12, 30), start: date(11, 1), sandbox().granting(originalID: 42)), .arm)
  }

  func testAStoredPurchaseArmsEvenWhenAppleHasNotAnswered() {
    XCTAssertEqual(firstBlock(date(12, 1), start: nil, AppleFacts().granting(originalID: 42)), .arm)
  }

  func testTheDownloadDayIsTheUsersLocalDay() {
    var tokyo = Calendar(identifier: .gregorian)
    tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    let downloaded = utc.date(from: DateComponents(year: 2026, month: 12, day: 1, hour: 23, minute: 30))! // Dec 2, 08:30 in Tokyo
    let lastStart = tokyo.date(from: DateComponents(year: 2026, month: 12, day: 16, hour: 23))!
    XCTAssertEqual(AccessPolicy.firstBlock(now: lastStart, trialStart: nil, facts: production(downloaded: downloaded),
                                           terms: terms, calendar: tokyo), .startTrial)
  }

  func testAStoredTrialStartArmsWithoutAskingApple() {
    XCTAssertEqual(firstBlock(date(11, 5), start: date(11, 2), AppleFacts()), .arm)
  }

  func testARunningTrialArmsAndAnEndedOneOpensTheUnlockScreen() {
    XCTAssertEqual(firstBlock(date(11, 5), start: date(11, 2), sandbox()), .arm)
    XCTAssertEqual(firstBlock(date(11, 12), start: date(11, 2), sandbox()), .unlock)
  }

  // MARK: Extension

  private func extensionApplies(_ now: Date, storedFacts: Data?, start: Date?) -> Bool {
    AccessPolicy.extensionAppliesBlock(now: now, storedFacts: storedFacts, trialStart: start, terms: terms, calendar: utc)
  }

  func testTheExtensionAppliesBlocksWhenNothingIsStored() {
    XCTAssertTrue(extensionApplies(date(12, 30), storedFacts: nil, start: nil))
  }

  func testTheExtensionAppliesBlocksWhenTheStoredFactsAreUnreadable() {
    XCTAssertTrue(extensionApplies(date(12, 30), storedFacts: Data("garbage".utf8), start: date(11, 1)))
  }

  func testTheExtensionSkipsBlocksOnceTheTrialHasEnded() throws {
    let facts = try sandbox().storedData()
    XCTAssertTrue(extensionApplies(date(11, 9, 23), storedFacts: facts, start: date(11, 2)))
    XCTAssertFalse(extensionApplies(date(11, 10, 0), storedFacts: facts, start: date(11, 2)))
  }

  func testWithATrialStartButNoStoredFactsTheExtensionStillEndsTheTrial() {
    XCTAssertTrue(extensionApplies(date(11, 9, 23), storedFacts: nil, start: date(11, 2)))
    XCTAssertFalse(extensionApplies(date(11, 10, 0), storedFacts: nil, start: date(11, 2)))
  }

  func testTheStorageKeysAreStable() {
    XCTAssertEqual(AccessStorageKeys.appleFacts, "apple_facts")
    XCTAssertEqual(AccessStorageKeys.trialStart, "trial_started_at")
  }

  func testTheExtensionKeepsApplyingBlocksForABuyer() throws {
    let facts = try sandbox().granting(originalID: realisticOriginalID).storedData()
    XCTAssertTrue(extensionApplies(date(12, 30), storedFacts: facts, start: date(11, 2)))
  }
}
