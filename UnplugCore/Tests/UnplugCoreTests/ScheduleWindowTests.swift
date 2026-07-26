//
//  ScheduleWindowTests.swift
//  UnplugCoreTests
//
//  V01 — the end handle could not represent midnight: minute 1440 became `bySettingHour: 24`, which
//  returns nil, and the `?? Date()` fallback substituted the current time for the user's choice.
//  These tests pin the property that made that possible impossible: the mapping is total, so there
//  is no input for which it has to invent a value.
//

import XCTest
import UnplugCore

final class ScheduleWindowTests: XCTestCase {

  private let trackWidth = 329.0   // iPhone 17 Pro slider width, per V01's trace
  private let inset = 24.0

  // MARK: - MinuteOfDay is total

  /// V01 — every minute of the day, and the 1440 boundary, resolve to a real hour/minute.
  func testEveryMinuteMapsToARealClockTime() {
    for minute in 0...MinuteOfDay.perDay {
      let hour = MinuteOfDay.hour(minute)
      let minuteOfHour = MinuteOfDay.minuteOfHour(minute)
      XCTAssertTrue((0...23).contains(hour), "minute \(minute) produced hour \(hour)")
      XCTAssertTrue((0...59).contains(minuteOfHour), "minute \(minute) produced minute \(minuteOfHour)")
    }
  }

  /// V01 — 1440 is midnight, not a 25th hour. This is the exact value the old code handed to
  /// `Calendar.date(bySettingHour: 24, ...)`.
  func testMinute1440IsMidnight() {
    XCTAssertEqual(MinuteOfDay.normalized(1440), 0)
    XCTAssertEqual(MinuteOfDay.hour(1440), 0)
    XCTAssertEqual(MinuteOfDay.minuteOfHour(1440), 0)
    XCTAssertEqual(MinuteOfDay.hhmm(1440), "00:00")
  }

  func testNormalizedWrapsBothDirections() {
    XCTAssertEqual(MinuteOfDay.normalized(0), 0)
    XCTAssertEqual(MinuteOfDay.normalized(1439), 1439)
    XCTAssertEqual(MinuteOfDay.normalized(1441), 1)
    XCTAssertEqual(MinuteOfDay.normalized(2880), 0)
    XCTAssertEqual(MinuteOfDay.normalized(-1), 1439)
    XCTAssertEqual(MinuteOfDay.normalized(-1440), 0)
  }

  func testSnappingRoundsToTheNearestStep() {
    XCTAssertEqual(MinuteOfDay.snapped(0, step: 5), 0)
    XCTAssertEqual(MinuteOfDay.snapped(2, step: 5), 0)
    XCTAssertEqual(MinuteOfDay.snapped(3, step: 5), 5)
    XCTAssertEqual(MinuteOfDay.snapped(1437, step: 5), 1435)
    // Snapping up from 1438 reaches 1440, which is midnight rather than out of range.
    XCTAssertEqual(MinuteOfDay.snapped(1438, step: 5), 0)
  }

  // MARK: - The pixel mapping round-trips

  /// V01/F3.1 — `minute(forX: x(forMinute:))` is the identity for every snappable minute. The old
  /// pair were declared inverses in a comment; nothing checked it.
  func testMappingRoundTripsForEverySnappableMinute() {
    let mapping = TrackMapping(width: trackWidth, inset: inset)
    for minute in stride(from: 0, through: MinuteOfDay.perDay, by: 5) {
      let recovered = mapping.minute(forX: mapping.x(forMinute: minute))
      XCTAssertEqual(recovered, minute,
                     "minute \(minute) mapped to x \(mapping.x(forMinute: minute)) and back to \(recovered)")
    }
  }

  /// F3.2 — the track ends land exactly on the insets, so the fill and the axis agree with the handles.
  func testTrackEndsLandOnTheInsets() {
    let mapping = TrackMapping(width: trackWidth, inset: inset)
    XCTAssertEqual(mapping.x(forMinute: 0), inset, accuracy: 0.0001)
    XCTAssertEqual(mapping.x(forMinute: MinuteOfDay.perDay), trackWidth - inset, accuracy: 0.0001)
  }

  /// V01 — a finger past either end saturates. The old code let any x beyond the right inset clamp
  /// to 1440, which was the reachable, advertised value that then became "now".
  func testTouchesBeyondTheTrackSaturateRatherThanWrap() {
    let mapping = TrackMapping(width: trackWidth, inset: inset)
    for px in [-500.0, -1.0, 0.0, inset - 0.5] {
      XCTAssertEqual(mapping.minute(forX: px), 0, "x \(px) should saturate at midnight")
    }
    for px in [trackWidth - inset, trackWidth, trackWidth + 500] {
      XCTAssertEqual(mapping.minute(forX: px), MinuteOfDay.perDay,
                     "x \(px) should saturate at end-of-day, never wrap to the morning")
    }
  }

  /// A collapsed or absurd layout must not divide by zero or produce a nonsense minute.
  func testDegenerateWidthsStayInRange() {
    for width in [0.0, 1.0, 2 * inset, 2 * inset + 1] {
      let mapping = TrackMapping(width: width, inset: inset)
      XCTAssertGreaterThanOrEqual(mapping.usableWidth, 1)
      for px in [-10.0, 0.0, width / 2, width, width + 10] {
        let minute = mapping.minute(forX: px)
        XCTAssertTrue((0...MinuteOfDay.perDay).contains(minute),
                      "width \(width), x \(px) produced \(minute)")
      }
    }
  }

  // MARK: - Handle selection (V04)

  /// V04 — with the thumbs far apart, proximity decides and direction is irrelevant.
  func testSeparatedHandlesAreChosenByProximity() {
    let mapping = TrackMapping(width: trackWidth, inset: inset)
    let start = 9 * 60
    let end = 17 * 60

    for movingRight in [true, false] {
      XCTAssertEqual(mapping.handle(forTouchX: mapping.x(forMinute: start),
                                    startMinute: start, endMinute: end,
                                    thumbWidth: 28, movingRight: movingRight), .start)
      XCTAssertEqual(mapping.handle(forTouchX: mapping.x(forMinute: end),
                                    startMinute: start, endMinute: end,
                                    thumbWidth: 28, movingRight: movingRight), .end)
    }
  }

  /// V04 — the bug itself: when the thumbs overlap, the start handle is unreachable by proximity,
  /// so direction must be able to select it.
  func testOverlappingHandlesAreSelectableByDragDirection() {
    let mapping = TrackMapping(width: trackWidth, inset: inset)
    let start = 9 * 60
    let end = start + 15   // the minimum window: the thumbs are drawn on top of each other

    XCTAssertLessThan(abs(mapping.x(forMinute: start) - mapping.x(forMinute: end)), 28,
                      "precondition: this window must actually overlap the thumbs")

    let touch = mapping.x(forMinute: end)
    XCTAssertEqual(mapping.handle(forTouchX: touch, startMinute: start, endMinute: end,
                                  thumbWidth: 28, movingRight: false), .start,
                   "V04: dragging left from an overlapping pair must be able to reach the start handle")
    XCTAssertEqual(mapping.handle(forTouchX: touch, startMinute: start, endMinute: end,
                                  thumbWidth: 28, movingRight: true), .end)
  }

  /// V04 — at every window length, each handle is reachable by *some* gesture: by touching it when
  /// the thumbs are apart, and by drag direction when they overlap. That is what "not occluded"
  /// means, and it is the property the old two-gesture version broke.
  func testBothHandlesRemainReachableAtEveryWindowLength() {
    let mapping = TrackMapping(width: trackWidth, inset: inset)
    let thumb = 28.0
    let start = 8 * 60

    for length in stride(from: 15, through: 1425, by: 5) {
      let end = MinuteOfDay.normalized(start + length)
      let startX = mapping.x(forMinute: start)
      let endX = mapping.x(forMinute: end)

      func selection(touchingX px: Double, movingRight: Bool) -> SliderHandle {
        mapping.handle(forTouchX: px, startMinute: start, endMinute: end,
                       thumbWidth: thumb, movingRight: movingRight)
      }

      if abs(startX - endX) < thumb {
        XCTAssertEqual(selection(touchingX: endX, movingRight: false), .start,
                       "length \(length): overlapping thumbs, dragging left cannot reach start")
        XCTAssertEqual(selection(touchingX: endX, movingRight: true), .end,
                       "length \(length): overlapping thumbs, dragging right cannot reach end")
      } else {
        // Separated: proximity decides and must win regardless of which way the finger moves.
        for movingRight in [true, false] {
          XCTAssertEqual(selection(touchingX: startX, movingRight: movingRight), .start,
                         "length \(length): touching the start thumb selected the wrong handle")
          XCTAssertEqual(selection(touchingX: endX, movingRight: movingRight), .end,
                         "length \(length): touching the end thumb selected the wrong handle")
        }
      }
    }
  }

  /// The mapping must hold across the device range, not just one width.
  func testRoundTripHoldsAcrossDeviceWidths() {
    for width in [320.0, 329.0, 361.0, 393.0, 430.0, 1024.0] {
      let mapping = TrackMapping(width: width, inset: inset)
      for minute in stride(from: 0, through: MinuteOfDay.perDay, by: 5) {
        XCTAssertEqual(mapping.minute(forX: mapping.x(forMinute: minute)), minute,
                       "width \(width) broke the round trip at minute \(minute)")
      }
    }
  }
}
