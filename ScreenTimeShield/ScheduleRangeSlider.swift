//
//  ScheduleRangeSlider.swift
//  ScreenTimeShield
//

import SwiftUI
import UnplugCore

/// A horizontal 24-hour dual-handle range selector over minutes-of-day.
///
/// Bound to `Int` minutes rather than `Date` instants: the old version converted back and forth
/// through `Calendar`, which meant the right-hand edge asked for hour 24, got nil, and silently
/// substituted the current time (V01). The pixel↔minute mapping lives in `UnplugCore.TrackMapping`
/// so it can be tested; this view only draws.
struct ScheduleRangeSlider: View {
  @Binding var start: Int
  @Binding var end: Int
  var locked: Bool = false
  /// When non-nil, draws a "now" marker on the track (used while a block is active).
  var nowMinute: Int? = nil
  /// When true, the blocked region is *outside* the picked window (allow-only mode), so the fill
  /// is drawn as the two segments flanking the window rather than the window itself.
  var inverted: Bool = false

  /// Which handle the in-flight drag is moving, and where it was grabbed relative to that handle's
  /// centre. Held for the whole drag so a gesture can't switch handles halfway through, and so the
  /// handle moves with the finger instead of jumping to it.
  @State private var activeHandle: SliderHandle?
  @State private var grabOffsetX: CGFloat = 0

  private static let trackSpace = "ScheduleRangeSliderTrack"
  private let snapMinutes = 5
  private let minGap = 15            // minimum window length, in minutes
  private let trackHeight: CGFloat = 8
  private let thumbSize: CGFloat = 28
  // Half the widest hour-axis label. The track, fill, handles, and labels all map time onto
  // [labelInset, width - labelInset] so everything shares one coordinate system and the endpoint
  // labels never clip.
  private let labelInset: CGFloat = 24

  private func mapping(_ width: CGFloat) -> TrackMapping {
    TrackMapping(width: width, inset: labelInset, snapMinutes: snapMinutes)
  }

  private func x(for minute: Int, width: CGFloat) -> CGFloat {
    CGFloat(mapping(width).x(forMinute: minute))
  }

  var body: some View {
    VStack(spacing: 10) {
      GeometryReader { geo in
        let w = geo.size.width
        let startX = x(for: start, width: w)
        let endX = x(for: end, width: w)

        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color.secondary.opacity(0.18))
            .frame(height: trackHeight)
            .padding(.horizontal, labelInset)

          if inverted {
            fillBar(from: labelInset, to: startX)
            fillBar(from: endX, to: w - labelInset)
          } else {
            fillBar(from: startX, to: endX)
          }

          if let nowMinute {
            nowMarker(at: x(for: nowMinute, width: w), minute: nowMinute)
          }

          handle(at: startX, minute: start)
          handle(at: endX, minute: end)
        }
        .frame(height: thumbSize + 28, alignment: .center)
        .coordinateSpace(name: Self.trackSpace)
        // One gesture for both handles. Two per-handle gestures meant that when the thumbs
        // overlapped, whichever was drawn on top swallowed every touch and the other could not be
        // grabbed at all (V04).
        .contentShape(Rectangle())
        .gesture(locked ? nil : trackDrag(width: w))
      }
      .frame(height: thumbSize + 28)

      hourAxis
    }
    // Headroom so the time pills floating above the handles clear the card's top edge.
    .padding(.top, 22)
  }

  // MARK: Pieces

  private func fillBar(from x0: CGFloat, to x1: CGFloat) -> some View {
    Capsule()
      .fill(Style.primaryGradient)
      .frame(width: max(0, x1 - x0), height: trackHeight)
      .offset(x: x0)
      .opacity(locked ? 0.45 : 1)
  }

  private func trackDrag(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0, coordinateSpace: .named(Self.trackSpace))
      .onChanged { value in
        let map = mapping(width)

        if activeHandle == nil {
          let chosen = map.handle(forTouchX: value.startLocation.x,
                                  startMinute: start,
                                  endMinute: end,
                                  thumbWidth: Double(thumbSize),
                                  movingRight: value.translation.width >= 0)
          activeHandle = chosen
          // Grabbing anywhere on the thumb should move it by the drag distance, not teleport its
          // centre to the finger. Taps on open track have no offset worth keeping.
          let handleX = map.x(forMinute: chosen == .start ? start : end)
          let offset = value.startLocation.x - CGFloat(handleX)
          grabOffsetX = abs(offset) <= thumbSize / 2 ? offset : 0
        }

        let target = map.minute(forX: Double(value.location.x - grabOffsetX))
        let candidate = MinuteOfDay.normalized(target)

        // The gap is enforced on the window's wrap-aware length, not on raw ordering. Comparing
        // integers directly underflows once an endpoint reaches midnight (end - minGap goes
        // negative and normalizes to 23:45), and a wrapping window is legitimate here — an
        // overnight block is the app's main use case.
        switch activeHandle {
        case .start:
          start = ScheduleMath.windowLength(windowStart: candidate, windowEnd: end) >= minGap
            ? candidate
            : MinuteOfDay.normalized(end - minGap)
        case .end:
          end = ScheduleMath.windowLength(windowStart: start, windowEnd: candidate) >= minGap
            ? candidate
            : MinuteOfDay.normalized(start + minGap)
        case nil:
          break
        }
      }
      .onEnded { _ in
        activeHandle = nil
        grabOffsetX = 0
      }
  }

  private func handle(at cx: CGFloat, minute: Int) -> some View {
    // The circle is the layout element — vertically centered in the track ZStack so it lands
    // on the track line. The time pill floats above it as an overlay (fixed upward offset) so
    // it doesn't shift the circle's center.
    Circle()
      .fill(.white)
      .frame(width: thumbSize, height: thumbSize)
      .overlay(Circle().stroke(Style.primaryColor.opacity(locked ? 0.4 : 1), lineWidth: 3))
      .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
      .overlay {
        Text(MinuteOfDay.localizedTime(minute))
          .font(.caption.weight(.semibold))
          .foregroundStyle(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Style.primaryColor.opacity(locked ? 0.4 : 1), in: Capsule())
          .fixedSize()
          .offset(y: -(thumbSize / 2 + 18))
      }
      .opacity(locked ? 0.6 : 1)
      .allowsHitTesting(false)   // the track owns the gesture; see trackDrag(width:)
      .offset(x: cx - thumbSize / 2)
  }

  private func nowMarker(at cx: CGFloat, minute: Int) -> some View {
    Rectangle()
      .fill(Style.primaryColor)
      .frame(width: 2, height: thumbSize + 6)
      .overlay {
        Text(MinuteOfDay.localizedTime(minute))
          .font(.caption2.weight(.semibold))
          .foregroundStyle(Style.primaryColor)
          .fixedSize()
          .offset(y: -(thumbSize / 2 + 16))
      }
      .offset(x: cx - 1)
  }

  private var hourAxis: some View {
    GeometryReader { geo in
      let w = geo.size.width
      ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
        let cx = x(for: hour * 60, width: w)
        // Labelled in the user's locale like the handle pills, so a 12-hour locale doesn't get a
        // 24-hour axis under 12-hour handles (F3.8).
        Text(MinuteOfDay.localizedTime(hour * 60))
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize()
          .frame(width: 2 * labelInset)
          .offset(x: cx - labelInset)
      }
    }
    .frame(height: 14)
  }
}

struct ScheduleRangeSlider_Previews: PreviewProvider {
  struct Harness: View {
    @State var start = 9 * 60
    @State var end = 17 * 60
    var locked: Bool
    var nowMinute: Int?
    var body: some View {
      ScheduleRangeSlider(start: $start, end: $end, locked: locked, nowMinute: nowMinute)
        .padding(24)
    }
  }
  static var previews: some View {
    Group {
      Harness(locked: false, nowMinute: nil)
        .previewDisplayName("Editable")
      Harness(locked: true, nowMinute: 13 * 60 + 36)
        .previewDisplayName("Locked + now")
    }
    .previewLayout(.sizeThatFits)
  }
}
