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
  /// Build number of the release that introduces the IAP. Users whose original
  /// download predates this build are grandfathered. Must match the actual IAP release build.
  public static let cutoverBuild = 12
  public static let trialLength: TimeInterval = 7 * 24 * 60 * 60
  public static let statThreshold = 5
  /// Debounce window for the noisy shield-presentation counter.
  public static let stopCooldown: TimeInterval = 60
  public static let secondsPerDay: TimeInterval = 24 * 60 * 60
}

/// Abstracts the StoreKit entitlement source so callers (and tests) don't depend on StoreKit directly.
public protocol EntitlementProviding {
  var isPurchased: Bool { get }
  var originalAppVersion: String? { get }
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
  public static func accessState(now: Date,
                                 trialStart: Date?,
                                 hasFullAccess: Bool,
                                 trialLength: TimeInterval) -> AccessState {
    if hasFullAccess { return .fullAccess }
    guard let trialStart else { return .trial } // trial not started yet
    return now.timeIntervalSince(trialStart) < trialLength ? .trial : .expired
  }

  public static func trialDaysRemaining(now: Date,
                                        trialStart: Date?,
                                        trialLength: TimeInterval) -> Int {
    guard let trialStart else {
      return Int(ceil(trialLength / PricingConfig.secondsPerDay))
    }
    let remaining = trialLength - now.timeIntervalSince(trialStart)
    guard remaining > 0 else { return 0 }
    return Int(ceil(remaining / PricingConfig.secondsPerDay))
  }
}

/// Decides whether a user predates the IAP and should be granted permanent access.
public enum Grandfather {
  public static func isGrandfathered(originalVersion: String?, cutoverBuild: Int) -> Bool {
    guard let originalVersion, let original = Int(originalVersion) else { return false }
    return original < cutoverBuild
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
