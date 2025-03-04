//
//  Schedule.swift
//  ScreenTimeShield
//
//  Created by Steven Diviney on 17/08/2023.
//

import Foundation
import DeviceActivity
import SwiftUI

extension DeviceActivityName {
  static let daily = Self("daily")
  static let hourly = Self("hourly")
  static let notificationSchedule = Self("notificationSchedule")
}

class Schedule {
  static public func setSchedule(start: Date, end: Date, event: DeviceActivityEvent, repeats: Bool = true) {
    let schedule = DeviceActivitySchedule(intervalStart: components(from: start),
                                        intervalEnd: components(from: end),
                                        repeats: repeats)
    
    let activityName: DeviceActivityName = repeats ? .daily : .hourly
    let center = DeviceActivityCenter()
    center.stopMonitoring([activityName])
    
    let eventName = DeviceActivityEvent.Name("ScreenTimeShield.Event")
    
    do {
      try center.startMonitoring(
        activityName,
        during: schedule,
        events: [
          eventName: event
        ]
      )
    } catch {
      print("Error setting schedule: \(error)")
    }
    
    // Get the model instance
    let model = Model.shared
    
    // Set up notification schedules
    if repeats {
      // For daily schedule, set up full notification schedules
      if model.notificationsEnabled {
        setNotificationSchedules(restrictionStart: start, restrictionEnd: end)
      } else {
        // Stop any notification schedules if disabled
        DeviceActivityCenter().stopMonitoring([.notificationSchedule])
      }
    } else {
      // For hourly quick restriction, set up notification for after the restriction ends
      if model.notificationsEnabled {
        setHourlyNotificationSchedule(restrictionEnd: end)
      } else {
        // Stop any notification schedules if disabled
        DeviceActivityCenter().stopMonitoring([.notificationSchedule])
      }
    }
  }
  
  static func components(from date: Date) -> DateComponents {
    Calendar.current.dateComponents([.hour, .minute], from: date)
  }
  
  static func setNotificationSchedules(restrictionStart: Date, restrictionEnd: Date) {
    // Get model instance
    let model = Model.shared
    
    // Create notification event with 15-minute threshold
    let notificationEvent = model.notificationEvent()
    let eventName = DeviceActivityEvent.Name("ScreenTimeShield.NotificationEvent")
    
    let center = DeviceActivityCenter()
    center.stopMonitoring([.notificationSchedule])
    
    // Create a notification schedule that's the inverse of the restriction schedule
    // This means it will be active when the restriction is NOT active
    let startComponents = components(from: restrictionEnd)
    let endComponents = components(from: restrictionStart)
    
    // Create a single schedule that's the inverse of the restriction period
    let notificationSchedule = DeviceActivitySchedule(
      intervalStart: startComponents,
      intervalEnd: endComponents,
      repeats: true
    )
    
    do {
      try center.startMonitoring(
        .notificationSchedule,
        during: notificationSchedule,
        events: [eventName: notificationEvent]
      )
    } catch {
      print("Error setting notification schedule: \(error)")
    }
  }
  
  static func setHourlyNotificationSchedule(restrictionEnd: Date) {
    // Get model instance
    let model = Model.shared
    
    // Create notification event with 15-minute threshold
    let notificationEvent = model.notificationEvent()
    let eventName = DeviceActivityEvent.Name("ScreenTimeShield.NotificationEvent")
    
    let center = DeviceActivityCenter()
    
    // Stop any existing hourly notification schedule
    center.stopMonitoring([.notificationSchedule])
    
    // Create a schedule from restriction end until the same time tomorrow
    let endComponents = components(from: restrictionEnd)
    let nextDayEnd = Calendar.current.date(byAdding: .day, value: 1, to: restrictionEnd)!
    let nextDayEndComponents = components(from: nextDayEnd)
    
    let hourlyNotificationSchedule = DeviceActivitySchedule(
      intervalStart: endComponents,
      intervalEnd: nextDayEndComponents,
      repeats: false
    )
    
    do {
      try center.startMonitoring(
        .notificationSchedule,
        during: hourlyNotificationSchedule,
        events: [eventName: notificationEvent]
      )
    } catch {
      print("Error setting hourly notification schedule: \(error)")
    }
  }
}
