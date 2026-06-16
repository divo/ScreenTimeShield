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
    .expired // stub — Pass 3
  }

  static func trialDaysRemaining(now: Date,
                                 trialStart: Date?,
                                 trialLength: TimeInterval) -> Int {
    -1 // stub — Pass 3
  }
}

/// Decides whether a user predates the IAP and should be granted permanent access.
enum Grandfather {
  static func isGrandfathered(originalVersion: String?, cutoverBuild: Int) -> Bool {
    false // stub — Pass 3
  }
}

/// Gates whether the "times stopped" value stat is compelling enough to show.
enum StatGate {
  static func shouldShowStat(timesStopped: Int, threshold: Int) -> Bool {
    false // stub — Pass 3
  }
}

/// Collapses the system's repeated shield-presentation calls into one logical "stop".
enum StopDebouncer {
  static func shouldCount(now: Date, lastLogged: Date?, cooldown: TimeInterval) -> Bool {
    false // stub — Pass 3
  }
}
