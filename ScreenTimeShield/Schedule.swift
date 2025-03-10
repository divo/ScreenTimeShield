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
  }
  
  static public func setNotificationSchedule(restrictionStart: Date, restrictionEnd: Date) {
    let model = Model.shared
    let center = DeviceActivityCenter()
    center.stopMonitoring([.notificationSchedule])
    
    // Create an inverse schedule (active when restrictions are not)
    let startComponents = components(from: restrictionEnd)
    let endComponents = components(from: restrictionStart)
    
    let notificationSchedule = DeviceActivitySchedule(
      intervalStart: startComponents,
      intervalEnd: endComponents,
      repeats: true
    )
    
    do {
      try center.startMonitoring(
        .notificationSchedule,
        during: notificationSchedule,
        events: model.notificationEvents()
      )
    } catch {
      print("Error setting notification schedule: \(error)")
    }
  }
  
  static func components(from date: Date) -> DateComponents {
    Calendar.current.dateComponents([.hour, .minute], from: date)
  }
}
