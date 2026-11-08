//
//  AccessPolicy.swift
//  UnplugCore
//
//  The 1.3 access rules, as pure functions over facts Apple has confirmed plus the app's own trial
//  start. The app and the activity-monitor extension both decide from these, so expiry doesn't wait
//  for the app to be opened. Design: qa/design/trial-iap.md.
//

import Foundation

/// App-group keys shared by the app and the activity-monitor extension.
public enum AccessStorageKeys {
  /// `AppleFacts` as one encoded value, so the extension never reads half of an update.
  public static let appleFacts = "apple_facts"
  /// The app's own trial start: the first block, set once and only after Apple has answered. A new
  /// name, so a `trial_start` left by dev builds 17–21 is never read.
  public static let trialStart = "trial_started_at"
}

/// What Apple has confirmed. Changed only through the methods below, so a purchase can be cleared
/// only by a refund of that purchase.
public struct AppleFacts: Codable, Equatable {
  /// `AppTransaction.originalPurchaseDate` from the latest verified answer.
  public private(set) var downloadDate: Date?
  /// Whether that answer came from the real App Store. Nil until Apple has answered once.
  public private(set) var isProduction: Bool?
  /// `originalID` of the lifetime purchase that granted full access.
  public private(set) var grantingOriginalID: UInt64?

  public init() {}

  public var hasAppTransaction: Bool { isProduction != nil }

  /// The download date, but only when it came from the real App Store: test environments report a
  /// fixed 2013 date that must neither grandfather nor cap anything.
  public var productionDownloadDate: Date? { isProduction == true ? downloadDate : nil }

  public func withAppTransaction(downloadDate: Date, isProduction: Bool) -> AppleFacts {
    var facts = self
    facts.downloadDate = downloadDate
    facts.isProduction = isProduction
    return facts
  }

  public func granting(originalID: UInt64) -> AppleFacts {
    var facts = self
    facts.grantingOriginalID = originalID
    return facts
  }

  /// Only a refund of the purchase that granted access takes it away.
  public func revoking(originalID: UInt64) -> AppleFacts {
    guard originalID == grantingOriginalID else { return self }
    var facts = self
    facts.grantingOriginalID = nil
    return facts
  }

  /// Folds in a read of the purchase history. An unrevoked purchase grants; a revoked granting
  /// purchase revokes; anything the history doesn't mention, including an empty history, is kept.
  public func mergingLifetimeHistory(_ history: [LifetimePurchase]) -> AppleFacts {
    if let current = grantingOriginalID, history.contains(where: { $0.originalID == current && !$0.isRevoked }) {
      return self
    }
    if let owned = history.first(where: { !$0.isRevoked }) {
      return granting(originalID: owned.originalID)
    }
    if let current = grantingOriginalID, history.contains(where: { $0.originalID == current }) {
      return revoking(originalID: current)
    }
    return self
  }

  public init(storedData: Data) throws {
    self = try JSONDecoder().decode(AppleFacts.self, from: storedData)
  }

  public func storedData() throws -> Data {
    try JSONEncoder().encode(self)
  }
}

public struct LifetimePurchase: Equatable {
  public let originalID: UInt64
  public let isRevoked: Bool

  public init(originalID: UInt64, isRevoked: Bool) {
    self.originalID = originalID
    self.isRevoked = isRevoked
  }
}

public struct AccessTerms {
  public let trialDays: Int
  public let trialStartGraceDays: Int
  public let cutover: Date

  public init(trialDays: Int, trialStartGraceDays: Int, cutover: Date) {
    self.trialDays = trialDays
    self.trialStartGraceDays = trialStartGraceDays
    self.cutover = cutover
  }

  public static let current = AccessTerms(trialDays: PricingConfig.trialDays,
                                          trialStartGraceDays: PricingConfig.trialStartGraceDays,
                                          cutover: PricingConfig.cutoverDate)
}

public enum FirstBlockDecision: Equatable {
  /// Full access, or a trial already running.
  case arm
  /// Show the trial notice; on confirm, store the trial start and arm.
  case startTrial
  /// No trial left to give: open the unlock screen.
  case unlock
  /// Nothing verified from Apple yet: ask `AppTransaction`, store the answer, decide again.
  case askApple
}

public enum AccessPolicy {
  /// The activity-monitor extension's decision at a block start. It has no last-known state in
  /// memory, so missing or unreadable facts apply the block: a paying user is never locked out by
  /// storage.
  public static func extensionAppliesBlock(now: Date, storedFacts: Data?, trialStart: Date?, terms: AccessTerms,
                                           calendar: Calendar) -> Bool {
    let facts: AppleFacts
    if let storedFacts {
      guard let decoded = try? AppleFacts(storedData: storedFacts) else { return true }
      facts = decoded
    } else {
      facts = AppleFacts()
    }
    return accessState(now: now, trialStart: trialStart, facts: facts, terms: terms, calendar: calendar) != .expired
  }

  public static func isGrandfathered(_ facts: AppleFacts, terms: AccessTerms) -> Bool {
    Grandfather.isGrandfathered(originalPurchaseDate: facts.productionDownloadDate, cutoverDate: terms.cutover)
  }

  public static func hasFullAccess(_ facts: AppleFacts, terms: AccessTerms) -> Bool {
    facts.grantingOriginalID != nil || isGrandfathered(facts, terms: terms)
  }

  /// Production only: the midnight after which a first block no longer starts a trial.
  static func lastStartBoundary(_ facts: AppleFacts, terms: AccessTerms, calendar: Calendar) -> Date? {
    guard let downloaded = facts.productionDownloadDate else { return nil }
    return AccessEvaluator.trialEnd(trialStart: downloaded, trialDays: terms.trialStartGraceDays, calendar: calendar)
  }

  /// When the trial ends, or nil while it can't end yet (not started, and no download date to cap it).
  public static func trialEnd(trialStart: Date?, facts: AppleFacts, terms: AccessTerms, calendar: Calendar) -> Date? {
    let boundary = lastStartBoundary(facts, terms: terms, calendar: calendar)
    guard let trialStart else { return boundary }
    let end = AccessEvaluator.trialEnd(trialStart: trialStart, trialDays: terms.trialDays, calendar: calendar)
    guard let downloaded = facts.productionDownloadDate else { return end }
    let ceiling = AccessEvaluator.trialEnd(trialStart: downloaded,
                                           trialDays: terms.trialStartGraceDays + terms.trialDays,
                                           calendar: calendar)
    return min(end, ceiling)
  }

  public static func accessState(now: Date, trialStart: Date?, facts: AppleFacts, terms: AccessTerms,
                                 calendar: Calendar) -> AccessState {
    if hasFullAccess(facts, terms: terms) { return .fullAccess }
    guard let end = trialEnd(trialStart: trialStart, facts: facts, terms: terms, calendar: calendar) else {
      return .trial
    }
    return now < end ? .trial : .expired
  }

  public static func trialDaysRemaining(now: Date, trialStart: Date?, facts: AppleFacts, terms: AccessTerms,
                                        calendar: Calendar) -> Int {
    guard let end = trialEnd(trialStart: trialStart, facts: facts, terms: terms, calendar: calendar) else {
      return terms.trialDays
    }
    guard now < end else { return 0 }
    guard trialStart != nil else { return terms.trialDays }
    let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: end).day ?? 0
    return min(terms.trialDays, max(0, days))
  }

  public static func firstBlock(now: Date, trialStart: Date?, facts: AppleFacts, terms: AccessTerms,
                                calendar: Calendar) -> FirstBlockDecision {
    if hasFullAccess(facts, terms: terms) { return .arm }
    if trialStart == nil && !facts.hasAppTransaction { return .askApple }
    if accessState(now: now, trialStart: trialStart, facts: facts, terms: terms, calendar: calendar) == .expired {
      return .unlock
    }
    return trialStart == nil ? .startTrial : .arm
  }
}
