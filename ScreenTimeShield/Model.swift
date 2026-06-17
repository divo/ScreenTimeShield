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

  /// The interval actually handed to the schedule. In allow-only mode it's the inverse of the
  /// picked window (start > end), which `DeviceActivitySchedule` interprets as wrapping midnight.
  var blockedInterval: (start: Date, end: Date) {
    blockOutsideWindow ? (start: end, end: start) : (start: start, end: end)
  }
  
  @Published var selectionToRestrict: FamilyActivitySelection = FamilyActivitySelection()
  @Published var start: Date = (UserDefaults(suiteName: Model.userDefaultsSuite)?.object(forKey: "start") as? Date) ??
    Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date.now)! {
    didSet {
      UserDefaults(suiteName: Model.userDefaultsSuite)!.set(start, forKey: "start")
    }
  }
  
  @Published var end: Date = (UserDefaults(suiteName: Model.userDefaultsSuite)?.object(forKey: "end") as? Date) ??
    Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date.now)! {
    didSet {
      UserDefaults(suiteName: Model.userDefaultsSuite)!.set(end, forKey: "end")
    }
  }
  
  class var shared: Model {
    return _model
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
