//
//  AppGroupStore.swift
//  ScreenTimeShield
//
//  Concrete KeyValueStore over the shared app-group UserDefaults. Used by the main
//  app and the shield extension (which increments the "times stopped" counter).
//

import Foundation
import UnplugCore

enum AppGroupKeys {
  static let trialStart = "trial_start"
  static let timesStopped = "times_stopped"
  static let lastStopLogged = "last_stop_logged"
  /// Cached gate the extensions read so they don't touch StoreKit themselves.
  static let enforcementAllowed = "enforcement_allowed"
  /// QA-only: forces full access without a real StoreKit transaction.
  static let qaForceFullAccess = "qa_force_full_access"
}

struct AppGroupStore: KeyValueStore {
  static let suiteName = "group.screentimeshield"
  private let defaults = UserDefaults(suiteName: AppGroupStore.suiteName)!

  func date(forKey key: String) -> Date? {
    defaults.object(forKey: key) as? Date
  }

  func setDate(_ date: Date?, forKey key: String) {
    defaults.set(date, forKey: key)
  }

  func integer(forKey key: String) -> Int {
    defaults.integer(forKey: key)
  }

  /// Distinguishes "absent" from "zero", which `integer(forKey:)` cannot — 0 is a legitimate
  /// minute-of-day (midnight), so callers reading a schedule time need the difference.
  func integerIfPresent(forKey key: String) -> Int? {
    defaults.object(forKey: key) as? Int
  }

  func setInteger(_ value: Int, forKey key: String) {
    defaults.set(value, forKey: key)
  }

  func bool(forKey key: String) -> Bool {
    defaults.bool(forKey: key)
  }

  func setBool(_ value: Bool, forKey key: String) {
    defaults.set(value, forKey: key)
  }
}
