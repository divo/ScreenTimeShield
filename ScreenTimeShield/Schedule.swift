//
//  Schedule.swift
//  ScreenTimeShield
//
//  Created by Steven Diviney on 17/08/2023.
//

import Foundation
import DeviceActivity
import UnplugCore

extension DeviceActivityName {
  static let daily = Self("daily")
  static let hourly = Self("hourly")
  static let notificationSchedule = Self("notificationSchedule")
}

class Schedule {
  /// `DeviceActivityCenter` start/stop are synchronous XPC calls to the system daemon and are
  /// slow enough to stall the UI if run on the main thread (e.g. right after the arm-confirm
  /// alert). Run them on a private serial queue: off-main, and serial so a stop→start (or a
  /// rapid arm→disarm) can't reorder. Callers compute all Model-derived values on the main
  /// thread first, so nothing here touches Model off-main.
  private static let queue = DispatchQueue(label: "com.halfspud.unplug.deviceactivity")

  /// `completion` reports the registration outcome on the main queue. It must not be ignored for the
  /// arming path: a thrown `startMonitoring` leaves nothing registered, so a caller that assumes
  /// success shows a user a block that will never fire.
  static public func setSchedule(start: Int, end: Int, event: DeviceActivityEvent,
                                 repeats: Bool = true,
                                 completion: ((Error?) -> Void)? = nil) {
    let schedule = DeviceActivitySchedule(intervalStart: components(fromMinutes: start),
                                          intervalEnd: components(fromMinutes: end),
                                          repeats: repeats)
    let activityName: DeviceActivityName = repeats ? .daily : .hourly
    let eventName = DeviceActivityEvent.Name("ScreenTimeShield.Event")

    queue.async {
      let center = DeviceActivityCenter()
      center.stopMonitoring([activityName])
      var failure: Error?
      do {
        try center.startMonitoring(activityName, during: schedule, events: [eventName: event])
      } catch {
        failure = error
        print("Error setting schedule: \(error)")
      }
      if let completion {
        DispatchQueue.main.async { completion(failure) }
      }
    }
  }

  static public func setNotificationSchedule(restrictionStart: Int,
                                             restrictionEnd: Int,
                                             events: [DeviceActivityEvent.Name: DeviceActivityEvent],
                                             completion: ((Error?) -> Void)? = nil) {
    // Inverse schedule: active when restrictions are *not* (the gap between restrictionEnd and the
    // next restrictionStart), so refocus notifications fire outside blocked hours.
    let notificationSchedule = DeviceActivitySchedule(intervalStart: components(fromMinutes: restrictionEnd),
                                                      intervalEnd: components(fromMinutes: restrictionStart),
                                                      repeats: true)
    queue.async {
      let center = DeviceActivityCenter()
      center.stopMonitoring([.notificationSchedule])
      var failure: Error?
      do {
        try center.startMonitoring(.notificationSchedule, during: notificationSchedule, events: events)
      } catch {
        failure = error
        print("Error setting notification schedule: \(error)")
      }
      if let completion {
        DispatchQueue.main.async { completion(failure) }
      }
    }
  }

  /// Off-main stop, on the same serial queue as the start calls so ordering is preserved.
  static public func stopMonitoring(_ names: [DeviceActivityName]) {
    queue.async {
      DeviceActivityCenter().stopMonitoring(names)
    }
  }

  /// Minutes-of-day straight to hour/minute components. No `Calendar`, so no time zone is involved
  /// and the registered schedule can't drift with the device's offset (V02).
  static func components(fromMinutes minute: Int) -> DateComponents {
    DateComponents(hour: MinuteOfDay.hour(minute), minute: MinuteOfDay.minuteOfHour(minute))
  }
}
