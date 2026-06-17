import XCTest
@testable import UnplugCore

final class ScheduleMathTests: XCTestCase {
  // 9:00 = 540, 17:00 = 1020, 12:00 = 720, 22:00 = 1320, 7:00 = 420

  func testContainsSameDayWindow() {
    XCTAssertTrue(ScheduleMath.windowContains(now: 720, start: 540, end: 1020))   // noon in 9–17
    XCTAssertFalse(ScheduleMath.windowContains(now: 480, start: 540, end: 1020))  // 8am before
    XCTAssertFalse(ScheduleMath.windowContains(now: 1080, start: 540, end: 1020)) // 18:00 after
  }

  func testContainsIsHalfOpen() {
    XCTAssertTrue(ScheduleMath.windowContains(now: 540, start: 540, end: 1020))   // start inclusive
    XCTAssertFalse(ScheduleMath.windowContains(now: 1020, start: 540, end: 1020)) // end exclusive
  }

  func testContainsWrappingWindow() {
    // 22:00 → 07:00 (overnight)
    XCTAssertTrue(ScheduleMath.windowContains(now: 1380, start: 1320, end: 420))  // 23:00
    XCTAssertTrue(ScheduleMath.windowContains(now: 60, start: 1320, end: 420))    // 01:00
    XCTAssertFalse(ScheduleMath.windowContains(now: 720, start: 1320, end: 420))  // noon free
  }

  func testZeroLengthIsEmpty() {
    XCTAssertFalse(ScheduleMath.windowContains(now: 540, start: 540, end: 540))
  }

  func testFreeMinutesBlockMode() {
    // Block 9–17 → free = 24h - 8h = 16h = 960
    XCTAssertEqual(ScheduleMath.freeMinutes(windowStart: 540, windowEnd: 1020, blockOutsideWindow: false), 960)
  }

  func testFreeMinutesAllowOnlyMode() {
    // Allow only 12:00–13:00 → free = the 60-min window
    XCTAssertEqual(ScheduleMath.freeMinutes(windowStart: 720, windowEnd: 780, blockOutsideWindow: true), 60)
  }
}
