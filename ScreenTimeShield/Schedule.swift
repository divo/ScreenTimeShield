//
//  Schedule.swift
//  ScreenTimeShield
//
//  Created by Steven Diviney on 17/08/2023.
//

import Foundation
import DeviceActivity

extension DeviceActivityName {
  static let daily = Self("daily")
  static let hourly = Self("hourly")
}

class Schedule {
  static public func setSchedule(start: Date, end: Date, event: DeviceActivityEvent, repeats: Bool = true) {
    let schedule = DeviceActivitySchedule(intervalStart: components(from: start),
                                        intervalEnd: components(from: end),
                                        repeats: repeats)
    
    let center = DeviceActivityCenter()
    center.stopMonitoring()
    
    let eventName = DeviceActivityEvent.Name("ScreenTimeShield.Event")
    let activityName: DeviceActivityName = repeats ? .daily : .hourly
    
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
  
  static func components(from date: Date) -> DateComponents {
    Calendar.current.dateComponents([.hour, .minute], from: date)
  }
}
