//
//  DeviceActivityMonitorExtension.swift
//  CustomDeviceActivityMonitor
//
//  Created by Steven Diviney on 18/08/2023.
//

import DeviceActivity
import UserNotifications
import ManagedSettings
import SwiftUI

// Extension to provide activity names
extension DeviceActivityName {
  static let daily = Self("daily")
  static let hourly = Self("hourly")
  static let notificationSchedule = Self("notificationSchedule")
}

// Optionally override any of the functions below.
// Make sure that your class name matches the NSExtensionPrincipalClass in your Info.plist.
class DeviceActivityMonitorExtension: DeviceActivityMonitor {
  private let defaults = UserDefaults(suiteName: "group.screentimeshield")
  let store = ManagedSettingsStore()
  
  var notificationsEnabled: Bool {
    return defaults?.bool(forKey: "notifications_enabled") ?? true
  }
  
  var insideInterval: Bool {
    get {
      return defaults?.bool(forKey: "inside_interval") ?? false
    }
    set {
      defaults?.set(newValue, forKey: "inside_interval")
      defaults?.synchronize()
    }
  }
  
  // This is called when the Schedule starts
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    
    print("Interval did start for: \(activity.rawValue)")
    
    // Only set restrictions for the main restriction schedule
    if activity.rawValue == "daily" || activity.rawValue == "hourly" {
      let model = Model.shared
      model.loadSelection()
      model.setRestrictions()
      model.insideInterval = true
    }
  }
  
  // This is called when the Schedule ends
  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    
    print("Interval did end for: \(activity.rawValue)")
    
    // Only clear restrictions for the main restriction schedule
    if activity.rawValue == "daily" || activity.rawValue == "hourly" {
      let model = Model.shared
      model.clearRestrictions()
      model.insideInterval = false
    }
  }
  
  private var lastNotificationTime: Date? {
    get { defaults?.object(forKey: "last_notification_time") as? Date }
    set {
      defaults?.set(newValue, forKey: "last_notification_time")
      defaults?.synchronize()
    }
  }

  private static let notificationCooldown: TimeInterval = 4 * 60

  override func eventDidReachThreshold(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
    super.eventDidReachThreshold(event, activity: activity)

    print("Event threshold reached: \(event.rawValue) for activity: \(activity.rawValue)")

    if activity.rawValue == "notificationSchedule" && notificationsEnabled {
      if let last = lastNotificationTime, Date().timeIntervalSince(last) < Self.notificationCooldown {
        print("Suppressing clumped notification: \(event.rawValue)")
        return
      }

      if let minuteString = event.rawValue.split(separator: ".").last,
         let minutes = Int(minuteString.replacingOccurrences(of: "min", with: "")) {
        lastNotificationTime = Date()
        sendUsageNotification(message: String(localized:"You've been using a restricted app for \(minutes) minutes, tap here to regain focus"))
      }
    }
  }
  
  private func sendUsageNotification(message: String) {
    // Create notification content
    let content = UNMutableNotificationContent()
    content.title = "App Usage Alert"
    content.body = message
    content.sound = .default
    
    // Add category for action when tapped
    content.categoryIdentifier = "APP_USAGE_ALERT"
    
    // Create a notification request with a unique identifier
    let request = UNNotificationRequest(
      identifier: UUID().uuidString,
      content: content,
      trigger: nil // Deliver immediately
    )
    
    // Schedule the notification
    UNUserNotificationCenter.current().add(request) { error in
      if let error = error {
        print("Error scheduling notification: \(error)")
      } else {
        print("Notification scheduled successfully")
      }
    }
  }
  
  override func intervalWillStartWarning(for activity: DeviceActivityName) {
    super.intervalWillStartWarning(for: activity)
  }
  
  override func intervalWillEndWarning(for activity: DeviceActivityName) {
    super.intervalWillEndWarning(for: activity)
  }
  
  override func eventWillReachThresholdWarning(_ event: DeviceActivityEvent.Name, activity: DeviceActivityName) {
    super.eventWillReachThresholdWarning(event, activity: activity)
  }
}
