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

  /// Minutes left unblocked given the picked same-day window `[windowStart, windowEnd)` and the mode.
  /// Block mode blocks the window (free = the rest of the day); allow-only blocks the rest (free =
  /// the window itself).
  public static func freeMinutes(windowStart: Int, windowEnd: Int, blockOutsideWindow: Bool) -> Int {
    let windowLength = max(0, windowEnd - windowStart)
    return blockOutsideWindow ? windowLength : (minutesPerDay - windowLength)
  }
}
