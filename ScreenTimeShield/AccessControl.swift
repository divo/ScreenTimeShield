//
//  AccessControl.swift
//  ScreenTimeShield
//
//  Pure, injectable logic for the trial + lifetime-unlock pricing model.
//  No Date()/UserDefaults/StoreKit reach into these — callers pass everything in,
//  so the logic is unit-testable in isolation. System glue lives elsewhere.
//

import Foundation

enum AccessState: Equatable {
  case trial
  case expired
  case fullAccess
}

/// Central pricing constants.
enum PricingConfig {
  /// Build number of the release that introduces the IAP. Users whose original
  /// download predates this build are grandfathered. Must match the actual IAP release build.
  static let cutoverBuild = 12
  static let trialLength: TimeInterval = 7 * 24 * 60 * 60
  static let statThreshold = 5
  /// Debounce window for the noisy shield-presentation counter.
  static let stopCooldown: TimeInterval = 60
  static let secondsPerDay: TimeInterval = 24 * 60 * 60
}

/// Abstracts the StoreKit entitlement source so callers (and tests) don't depend on StoreKit directly.
protocol EntitlementProviding {
  var isPurchased: Bool { get }
  var originalAppVersion: String? { get }
}

/// Thin seam over the shared app-group UserDefaults for trial date + counters.
protocol KeyValueStore {
  func date(forKey key: String) -> Date?
  func setDate(_ date: Date?, forKey key: String)
  func integer(forKey key: String) -> Int
  func setInteger(_ value: Int, forKey key: String)
}

/// Resolves the user's current access level from trial timing + entitlement.
enum AccessEvaluator {
  static func accessState(now: Date,
                          trialStart: Date?,
                          hasFullAccess: Bool,
                          trialLength: TimeInterval) -> AccessState {
    if hasFullAccess { return .fullAccess }
    guard let trialStart else { return .trial } // trial not started yet
    return now.timeIntervalSince(trialStart) < trialLength ? .trial : .expired
  }

  static func trialDaysRemaining(now: Date,
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
enum Grandfather {
  static func isGrandfathered(originalVersion: String?, cutoverBuild: Int) -> Bool {
    guard let originalVersion, let original = Int(originalVersion) else { return false }
    return original < cutoverBuild
  }
}

/// Gates whether the "times stopped" value stat is compelling enough to show.
enum StatGate {
  static func shouldShowStat(timesStopped: Int, threshold: Int) -> Bool {
    timesStopped >= threshold
  }
}

/// Collapses the system's repeated shield-presentation calls into one logical "stop".
enum StopDebouncer {
  static func shouldCount(now: Date, lastLogged: Date?, cooldown: TimeInterval) -> Bool {
    guard let lastLogged else { return true }
    return now.timeIntervalSince(lastLogged) >= cooldown
  }
}
