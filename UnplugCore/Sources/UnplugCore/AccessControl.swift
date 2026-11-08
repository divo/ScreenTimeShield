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
  /// Users whose Apple ID first got the app (`AppTransaction.originalPurchaseDate`) before this are
  /// grandfathered into permanent free access. `AccessPolicy` checks it only in the real App Store, so
  /// test environments, where Apple reports a fixed 2013 date, never grandfather.
  ///
  /// **Set it a few days after the 1.3 release day, when the final build is prepared, never earlier.**
  /// Erring early is the expensive direction: anyone who paid $0.99 between the cutover and the price
  /// change to Free is treated as a new user and asked to pay again. Erring late only grandfathers a
  /// few free downloads. `PricingBoundaryTests` V22 checks this against the last known pre-IAP sale day;
  /// it is marked as an expected failure while the placeholder is in, so remove those markers when the
  /// real value goes in. See status.md.
  ///
  /// ⚠️ **The 2020 placeholder must not be submitted**: in the real App Store it would treat every 1.2
  /// buyer as a new user.
  public static let cutoverDate = Date(timeIntervalSince1970: 1_577_836_800) // placeholder: 2020-01-01, not the release value
  /// Full local calendar days in the trial, after the day it starts (see `AccessEvaluator.trialEnd`).
  public static let trialDays = 7
  /// In the real App Store, a first block within this many days of Apple's download date still gets the
  /// full trial; a reinstall can't push a trial past `trialStartGraceDays + trialDays`.
  public static let trialStartGraceDays = 14
  public static let statThreshold = 5
  /// Debounce window for the noisy shield-presentation counter.
  public static let stopCooldown: TimeInterval = 60
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
