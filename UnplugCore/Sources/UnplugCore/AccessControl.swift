//
//  AccessControl.swift
//  UnplugCore
//
//  Pure, injectable logic for the trial + lifetime-unlock pricing model.
//  No Date()/UserDefaults/StoreKit reach into these — callers pass everything in,
//  so the logic is unit-testable natively (no simulator). System glue lives in the app.
//

import Foundation

public enum AccessState: Equatable {
  case trial
  case expired
  case fullAccess
}

/// Central pricing constants.
public enum PricingConfig {
  /// The moment the IAP release goes live. Users whose original download predates this
  /// date are grandfathered into permanent free access. Compared against
  /// `AppTransaction.originalPurchaseDate`, which is monotonic and immune to our
  /// per-version build-number resets (unlike the original `originalAppVersion` check).
  /// The IAP go-live date. Users whose original download predates this are grandfathered
  /// into permanent free access (compared against `AppTransaction.originalPurchaseDate`).
  ///
  /// **Must be at or after the actual 1.3 App Store release, and re-verified at every submission.**
  /// Erring late is the expensive direction: anyone who bought the pre-IAP paid app after this date
  /// is treated as a new user and asked to pay again. Erring early only gives a few $0.99 buyers
  /// free access. `PricingBoundaryTests` fails while this predates the last known pre-IAP sale day.
  ///
  /// ⚠️ **DEV BUILD — currently set to the past on purpose.** A cutover in the past means a fresh
  /// install is *not* grandfathered, so the trial, paywall and IAP purchase can actually be
  /// exercised. **This build must not be submitted.** For release, set it to 00:00 UTC on the day
  /// *after* the 1.3 release day, never to an old date: the app is on sale at $0.99 until the
  /// release day, and anyone who paid before the cutover must be grandfathered. Then remove the
  /// matching XCTExpectFailure markers in PricingBoundaryTests. See the release checklist in status.md.
  public static let cutoverDate = Date(timeIntervalSince1970: 1_577_836_800) // DEV: 2020-01-01 00:00 UTC
  /// Full local calendar days in the trial, after the day it starts (see `AccessEvaluator.trialEnd`).
  /// ⚠️ DEV BUILD — shortened to 1 day for trial→purchase QA. Restore to 7 days before submitting.
  public static let trialDays = 1 // DEV: 1 day
  public static let statThreshold = 5
  /// Debounce window for the noisy shield-presentation counter.
  public static let stopCooldown: TimeInterval = 60
}

/// Abstracts the StoreKit entitlement source so callers (and tests) don't depend on StoreKit directly.
public protocol EntitlementProviding {
  var isPurchased: Bool { get }
  var originalPurchaseDate: Date? { get }
}

/// Thin seam over the shared app-group UserDefaults for trial date + counters.
public protocol KeyValueStore {
  func date(forKey key: String) -> Date?
  func setDate(_ date: Date?, forKey key: String)
  func integer(forKey key: String) -> Int
  func setInteger(_ value: Int, forKey key: String)
}

/// Resolves the user's current access level from trial timing + entitlement.
public enum AccessEvaluator {
  /// The trial runs in whole local calendar days, so it ends at a midnight rather than at whatever
  /// time of day the user first armed a block. The rest of that first day is free, then `trialDays`
  /// full days follow. `calendar` carries the time zone, so DST and travel keep the end at midnight.
  public static func trialEnd(trialStart: Date, trialDays: Int, calendar: Calendar) -> Date {
    calendar.date(byAdding: .day, value: trialDays + 1, to: calendar.startOfDay(for: trialStart))!
  }

  public static func accessState(now: Date,
                                 trialStart: Date?,
                                 hasFullAccess: Bool,
                                 trialDays: Int,
                                 calendar: Calendar) -> AccessState {
    if hasFullAccess { return .fullAccess }
    guard let trialStart else { return .trial } // trial not started yet
    return now < trialEnd(trialStart: trialStart, trialDays: trialDays, calendar: calendar) ? .trial : .expired
  }

  public static func trialDaysRemaining(now: Date,
                                        trialStart: Date?,
                                        trialDays: Int,
                                        calendar: Calendar) -> Int {
    guard let trialStart else { return trialDays }
    let end = trialEnd(trialStart: trialStart, trialDays: trialDays, calendar: calendar)
    let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: now), to: end).day ?? 0
    // Clamped to the trial length: the free first day would otherwise read "8 days left" in a 7-day
    // trial, and an instant before trialStart would inflate the count further (V23).
    return min(trialDays, max(0, days))
  }
}

/// Decides whether a user predates the IAP and should be granted permanent access.
public enum Grandfather {
  public static func isGrandfathered(originalPurchaseDate: Date?, cutoverDate: Date) -> Bool {
    guard let originalPurchaseDate else { return false }
    return originalPurchaseDate < cutoverDate
  }
}

/// Gates whether the "times stopped" value stat is compelling enough to show.
public enum StatGate {
  public static func shouldShowStat(timesStopped: Int, threshold: Int) -> Bool {
    timesStopped >= threshold
  }
}

/// Collapses the system's repeated shield-presentation calls into one logical "stop".
public enum StopDebouncer {
  public static func shouldCount(now: Date, lastLogged: Date?, cooldown: TimeInterval) -> Bool {
    guard let lastLogged else { return true }
    return now.timeIntervalSince(lastLogged) >= cooldown
  }
}
