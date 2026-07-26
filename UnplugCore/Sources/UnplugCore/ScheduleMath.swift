//
//  ScheduleMath.swift
//  UnplugCore
//
//  Pure helpers for reasoning about the block schedule in minutes-of-day. Used by the app to
//  decide when arming a block is "risky" enough to warrant a confirmation. No Date()/system glue.
//

import Foundation

public enum ScheduleMath {
  public static let minutesPerDay = 24 * 60

  /// Whether `now` (minutes-of-day) falls inside the half-open block interval `[start, end)`,
  /// handling intervals that wrap past midnight (start > end). A zero-length interval is empty.
  public static func windowContains(now: Int, start: Int, end: Int) -> Bool {
    guard start != end else { return false }
    if start < end {
      return now >= start && now < end
    } else {
      // Wrapping interval, e.g. 22:00 → 07:00.
      return now >= start || now < end
    }
  }

  /// Length of the window `[windowStart, windowEnd)` in minutes, wrapping past midnight when
  /// `windowStart > windowEnd`. A zero-length window (equal endpoints) is 0, matching
  /// `windowContains`, which treats it as empty.
  public static func windowLength(windowStart: Int, windowEnd: Int) -> Int {
    (windowEnd - windowStart + minutesPerDay) % minutesPerDay
  }

  /// Minutes actually blocked by the given window and mode. Block mode blocks the window itself;
  /// allow-only blocks the rest of the day.
  public static func blockedMinutes(windowStart: Int, windowEnd: Int, blockOutsideWindow: Bool) -> Int {
    let length = windowLength(windowStart: windowStart, windowEnd: windowEnd)
    return blockOutsideWindow ? (minutesPerDay - length) : length
  }

  /// Minutes left unblocked given the picked window `[windowStart, windowEnd)` and the mode.
  ///
  /// Handles windows that wrap past midnight, which the overnight blocks this app exists for always
  /// do. The previous `max(0, windowEnd - windowStart)` clamped a wrapping window to zero length and
  /// so reported a whole free day for a 22:00–07:00 block — suppressing the arm confirmation exactly
  /// where it was needed.
  public static func freeMinutes(windowStart: Int, windowEnd: Int, blockOutsideWindow: Bool) -> Int {
    minutesPerDay - blockedMinutes(windowStart: windowStart,
                                   windowEnd: windowEnd,
                                   blockOutsideWindow: blockOutsideWindow)
  }
}
