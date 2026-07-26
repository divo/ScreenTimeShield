//
//  ScheduleWindow.swift
//  UnplugCore
//
//  Minutes-of-day representation of the schedule window, and the pure pixel<->minute mapping the
//  range slider draws with. Both existed only inside the SwiftUI view before, built on `Date`
//  instants — which is what let a failed `Calendar.date(bySettingHour:)` substitute "now" for the
//  user's chosen end time, and what made the window drift an hour at every DST change.
//
//  No `Date`, no `Calendar`, nothing to fail: a minute-of-day is an Int in 0..<1440.
//

import Foundation

/// A time of day as minutes since midnight, in `0..<1440`.
public enum MinuteOfDay {
  public static let perDay = 24 * 60
  public static let max = perDay - 1

  /// Wraps any integer into `0..<1440`, so 1440 becomes midnight rather than an invalid 25th hour.
  /// The slider's right-hand edge maps to 1440, and an end of midnight is meaningful — a
  /// 22:00 -> 00:00 window is a wrapping interval of 120 minutes, which the schedule math handles.
  public static func normalized(_ minute: Int) -> Int {
    ((minute % perDay) + perDay) % perDay
  }

  /// Clamps to `0...1439` without wrapping. For values that must stay on the same day.
  public static func clamped(_ minute: Int) -> Int {
    Swift.min(Swift.max(minute, 0), max)
  }

  /// Rounds to the nearest `step` minutes, then normalizes.
  public static func snapped(_ minute: Int, step: Int) -> Int {
    guard step > 1 else { return normalized(minute) }
    let rounded = Int((Double(minute) / Double(step)).rounded()) * step
    return normalized(rounded)
  }

  public static func hour(_ minute: Int) -> Int { normalized(minute) / 60 }
  public static func minuteOfHour(_ minute: Int) -> Int { normalized(minute) % 60 }

  /// 24-hour `HH:mm`. Only for contexts that need a locale-independent label; user-facing times
  /// should use `localizedTime(_:)`.
  public static func hhmm(_ minute: Int) -> String {
    String(format: "%02d:%02d", hour(minute), minuteOfHour(minute))
  }

  /// Time of day in the user's locale (so a 12-hour locale gets "10:30 PM"). The `Calendar` call
  /// cannot fail here — `hour` is always 0...23 — and falls back to a real 24-hour label rather
  /// than to `Date()`, which is the substitution that caused V01.
  public static func localizedTime(_ minute: Int) -> String {
    var components = DateComponents()
    components.hour = hour(minute)
    components.minute = minuteOfHour(minute)
    guard let date = Calendar.current.date(from: components) else { return hhmm(minute) }
    return date.formatted(date: .omitted, time: .shortened)
  }
}

/// Maps minutes-of-day onto a horizontal track and back. The track is inset at both ends so the
/// endpoint axis labels don't clip, and everything — track, fill, handles, labels — shares this one
/// coordinate system.
public struct TrackMapping {
  public let width: Double
  public let inset: Double
  public let snapMinutes: Int

  public init(width: Double, inset: Double, snapMinutes: Int = 5) {
    self.width = width
    self.inset = inset
    self.snapMinutes = snapMinutes
  }

  /// Never zero, so the mapping can't divide by zero on a collapsed layout.
  public var usableWidth: Double {
    Swift.max(width - 2 * inset, 1)
  }

  /// Position of a minute on the track. Accepts 1440 so the right-hand edge can be drawn at the
  /// "24:00" tick, even though a stored value is always normalized.
  public func x(forMinute minute: Int) -> Double {
    let bounded = Swift.min(Swift.max(minute, 0), MinuteOfDay.perDay)
    return inset + usableWidth * Double(bounded) / Double(MinuteOfDay.perDay)
  }

  /// Minute under a touch, snapped. Clamped to `0...1440` before snapping so a finger past either
  /// end of the track saturates instead of wrapping to the opposite end of the day.
  public func minute(forX px: Double) -> Int {
    let raw = ((px - inset) / usableWidth) * Double(MinuteOfDay.perDay)
    let bounded = Swift.min(Swift.max(raw, 0), Double(MinuteOfDay.perDay))
    let snapped = Int((bounded / Double(snapMinutes)).rounded()) * snapMinutes
    return Swift.min(Swift.max(snapped, 0), MinuteOfDay.perDay)
  }

  /// Which handle a drag should move.
  ///
  /// Normally the nearer one. When the two thumbs overlap, the touch cannot disambiguate them — the
  /// one drawn on top would win every time and the other would be unreachable (V04) — so the drag
  /// direction decides instead: dragging left takes the start handle, right takes the end handle.
  /// That makes the buried handle reachable by dragging away from its neighbour, which is the
  /// gesture someone would try anyway.
  public func handle(forTouchX px: Double,
                     startMinute: Int,
                     endMinute: Int,
                     thumbWidth: Double,
                     movingRight: Bool) -> SliderHandle {
    let startX = x(forMinute: startMinute)
    let endX = x(forMinute: endMinute)
    if abs(startX - endX) < thumbWidth {
      return movingRight ? .end : .start
    }
    return abs(px - startX) <= abs(px - endX) ? .start : .end
  }
}

public enum SliderHandle: Equatable {
  case start
  case end
}
