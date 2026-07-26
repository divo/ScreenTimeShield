//
//  Model.swift
//  ScreenTimeShield
//
//  Created by Steven Diviney on 17/08/2023.
//

import Foundation
import FamilyControls
import ManagedSettings
import DeviceActivity
import SwiftUI
import UnplugCore

private let _model = Model()

class Model: ObservableObject {
  
  let store = ManagedSettingsStore()
  
  private let encoder = PropertyListEncoder()
  private let decoder = PropertyListDecoder()
  private let userDefaultsKey = "ScreenTimeSeletion"
  private static let userDefaultsSuite = "group.screentimeshield"

  @AppStorage("inside_interval", store: UserDefaults(suiteName: Model.userDefaultsSuite)) var insideInterval: Bool = false
  @AppStorage("notifications_enabled", store: UserDefaults(suiteName: Model.userDefaultsSuite)) var notificationsEnabled: Bool = true
  @AppStorage("has_selection", store: UserDefaults(suiteName: Model.userDefaultsSuite)) var hasSelection: Bool = false
  /// false = block the picked window; true = allow only the picked window (block the rest of the day).
  @AppStorage("block_outside_window", store: UserDefaults(suiteName: Model.userDefaultsSuite)) var blockOutsideWindow: Bool = false
  /// Whether the daily schedule is currently registered (armed). Editing never sets this — only the
  /// explicit "Start blocking" action does. Synced from DeviceActivityCenter on launch.
  @AppStorage("is_armed", store: UserDefaults(suiteName: Model.userDefaultsSuite)) var isArmed: Bool = false

  /// The interval actually handed to the schedule, in minutes-of-day. In allow-only mode it's the
  /// inverse of the picked window (start > end), which `DeviceActivitySchedule` interprets as
  /// wrapping midnight.
  var blockedInterval: (start: Int, end: Int) {
    blockOutsideWindow ? (start: end, end: start) : (start: start, end: end)
  }

  @Published var selectionToRestrict: FamilyActivitySelection = FamilyActivitySelection()

  /// Window bounds as minutes since midnight. Stored as integers rather than `Date` instants: an
  /// instant has to be re-interpreted through `Calendar.current` on every read, which is what made
  /// the window drift an hour at each DST change and shift again on travel (V02).
  @Published var start: Int = Model.storedMinutes(forKey: Model.startMinutesKey, fallback: 9 * 60) {
    didSet {
      UserDefaults(suiteName: Model.userDefaultsSuite)!.set(start, forKey: Model.startMinutesKey)
    }
  }

  @Published var end: Int = Model.storedMinutes(forKey: Model.endMinutesKey, fallback: 17 * 60) {
    didSet {
      UserDefaults(suiteName: Model.userDefaultsSuite)!.set(end, forKey: Model.endMinutesKey)
    }
  }

  class var shared: Model {
    return _model
  }

  // MARK: - Schedule storage (minutes-of-day) + one-time migration from Date instants

  static let startMinutesKey = "start_minutes"
  static let endMinutesKey = "end_minutes"

  private static func storedMinutes(forKey key: String, fallback: Int) -> Int {
    _ = migrateScheduleStorage
    let defaults = UserDefaults(suiteName: userDefaultsSuite)!
    guard let stored = defaults.object(forKey: key) as? Int else { return fallback }
    return MinuteOfDay.normalized(stored)
  }

  /// Runs once, before `start`/`end` are first read.
  ///
  /// The old `Date` instants can only be turned back into wall-clock times by applying *some* UTC
  /// offset, and the one in force when the user last dragged the slider was never recorded — so
  /// converting them is a guess that is an hour wrong for anyone who has since changed zone or
  /// crossed a DST boundary. The system holds the answer though: a registered `.daily` activity
  /// carries the hour/minute components as they were originally registered, undrifted. Prefer those,
  /// and fall back to converting the stored instants only for users with nothing registered — for
  /// whom nothing is being enforced, so a one-hour error costs them nothing before they next look.
  private static let migrateScheduleStorage: Void = {
    let defaults = UserDefaults(suiteName: userDefaultsSuite)!
    guard defaults.object(forKey: startMinutesKey) == nil else { return }

    let blockOutside = defaults.bool(forKey: "block_outside_window")

    if let schedule = DeviceActivityCenter().schedule(for: .daily),
       let registeredStart = minutes(from: schedule.intervalStart),
       let registeredEnd = minutes(from: schedule.intervalEnd) {
      // The registered interval is the *blocked* one, so undo the allow-only inversion.
      let picked = blockOutside ? (start: registeredEnd, end: registeredStart)
                                : (start: registeredStart, end: registeredEnd)
      defaults.set(picked.start, forKey: startMinutesKey)
      defaults.set(picked.end, forKey: endMinutesKey)
      return
    }

    if let legacyStart = defaults.object(forKey: "start") as? Date,
       let legacyEnd = defaults.object(forKey: "end") as? Date {
      defaults.set(minutesOfDay(legacyStart), forKey: startMinutesKey)
      defaults.set(minutesOfDay(legacyEnd), forKey: endMinutesKey)
    }
  }()

  private static func minutes(from components: DateComponents) -> Int? {
    guard let hour = components.hour else { return nil }
    return MinuteOfDay.normalized(hour * 60 + (components.minute ?? 0))
  }

  private static func minutesOfDay(_ date: Date) -> Int {
    let components = Calendar.current.dateComponents([.hour, .minute], from: date)
    return MinuteOfDay.normalized((components.hour ?? 0) * 60 + (components.minute ?? 0))
  }

  func loadSelection() {
    self.selectionToRestrict = savedSelection() ?? FamilyActivitySelection()
    if !isEmpty() {
      hasSelection = true
    }
  }
  
  private func savedSelection() -> FamilyActivitySelection? {
    let defaults = UserDefaults(suiteName: Model.userDefaultsSuite)!
    guard let data = defaults.data(forKey: userDefaultsKey) else { return nil }
    
    return try? decoder.decode(FamilyActivitySelection.self, from: data)
  }
  
  // Ensure the user is not removing any blocks
  func validateRestriction() -> Bool {
    guard let existingSelection = savedSelection() else {
      return true
    }
    return existingSelection.applicationTokens == existingSelection.applicationTokens.intersection(selectionToRestrict.applicationTokens)
      && existingSelection.webDomainTokens == existingSelection.webDomainTokens.intersection(selectionToRestrict.webDomainTokens)
      && existingSelection.categoryTokens == existingSelection.categoryTokens.intersection(selectionToRestrict.categoryTokens)
  }
  
  func saveSelection() {
    let defaults = UserDefaults(suiteName: Model.userDefaultsSuite)!
    let data = try? encoder.encode(selectionToRestrict)
    
    defaults.set(data, forKey: userDefaultsKey)
    defaults.synchronize()
    hasSelection = true
  }
  
  func setRestrictions() {
    let applications = self.selectionToRestrict
    
    store.shield.applications = applications.applicationTokens.isEmpty ? nil : applications.applicationTokens
    store.shield.applicationCategories = applications.categoryTokens.isEmpty ? nil : ShieldSettings.ActivityCategoryPolicy.specific(applications.categoryTokens)
    store.shield.webDomains = applications.webDomainTokens.isEmpty ? nil : applications.webDomainTokens
  }
  
  func clearRestrictions() {
    store.shield.applications = nil
    store.shield.applicationCategories = nil
    store.shield.webDomains = nil
  }
  
  func selectionIsInvalidated() -> Bool {
    return hasSelection && isEmpty()
  }

  func isEmpty() -> Bool {
    return selectionToRestrict.applicationTokens.isEmpty
      && selectionToRestrict.categoryTokens.isEmpty
      && selectionToRestrict.webDomainTokens.isEmpty
  }
  
  func activityEvent() -> DeviceActivityEvent {
    let applications = Model.shared.selectionToRestrict
    return DeviceActivityEvent(
      applications: applications.applicationTokens,
      categories: applications.categoryTokens,
      webDomains: applications.webDomainTokens,
      threshold: DateComponents(minute: 0)
    )
  }
  
  func notificationEvents() -> [DeviceActivityEvent.Name: DeviceActivityEvent] {
    Dictionary(uniqueKeysWithValues: (1...10).map { i in
        let minute = i * 5
        return (
            .init("ScreenTimeShield.NotificationEvent.\(minute)min"),
            DeviceActivityEvent(
                applications: selectionToRestrict.applicationTokens,
                categories: selectionToRestrict.categoryTokens,
                webDomains: selectionToRestrict.webDomainTokens,
                threshold: DateComponents(minute: minute)
            )
        )
    })
  }
}
