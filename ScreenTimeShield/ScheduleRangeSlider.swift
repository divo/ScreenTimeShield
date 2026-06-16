//
//  ScheduleRangeSlider.swift
//  ScreenTimeShield
//

import SwiftUI

/// A horizontal 24-hour dual-handle range selector bound to two `Date` values
/// (hour/minute only). Same-day window for now — overnight (end < start) is a
/// known follow-up.
struct ScheduleRangeSlider: View {
  @Binding var start: Date
  @Binding var end: Date
  var locked: Bool = false
  /// When non-nil, draws a "now" marker on the track (used while a block is active).
  var now: Date? = nil

  private static let trackSpace = "ScheduleRangeSliderTrack"
  private let snapMinutes = 5
  private let minGap = 15            // minimum window length, in minutes
  private let totalMinutes = 24 * 60
  private let trackHeight: CGFloat = 8
  private let thumbSize: CGFloat = 28

  private func minutes(of date: Date) -> Int {
    let c = Calendar.current.dateComponents([.hour, .minute], from: date)
    return (c.hour ?? 0) * 60 + (c.minute ?? 0)
  }

  private func dateAtMinute(_ minute: Int) -> Date {
    let m = max(0, min(totalMinutes, minute))
    return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
  }

  private func x(for minute: Int, width: CGFloat) -> CGFloat {
    width * CGFloat(minute) / CGFloat(totalMinutes)
  }

  private func minute(forX px: CGFloat, width: CGFloat) -> Int {
    let raw = Int((px / max(width, 1)) * CGFloat(totalMinutes))
    let snapped = Int((Double(raw) / Double(snapMinutes)).rounded()) * snapMinutes
    return max(0, min(totalMinutes, snapped))
  }

  private func label(_ date: Date) -> String {
    date.formatted(date: .omitted, time: .shortened)
  }

  var body: some View {
    VStack(spacing: 10) {
      GeometryReader { geo in
        let w = geo.size.width
        let startX = x(for: minutes(of: start), width: w)
        let endX = x(for: minutes(of: end), width: w)

        ZStack(alignment: .leading) {
          Capsule()
            .fill(Color.secondary.opacity(0.18))
            .frame(height: trackHeight)

          Capsule()
            .fill(LinearGradient(colors: [Style.primaryColor, .purple],
                                 startPoint: .leading, endPoint: .trailing))
            .frame(width: max(0, endX - startX), height: trackHeight)
            .offset(x: startX)
            .opacity(locked ? 0.45 : 1)

          if let now {
            nowMarker(at: x(for: minutes(of: now), width: w), date: now)
          }

          handle(at: startX, date: start, edge: .start, width: w)
          handle(at: endX, date: end, edge: .end, width: w)
        }
        .frame(height: thumbSize + 28, alignment: .center)
        .coordinateSpace(name: Self.trackSpace)
      }
      .frame(height: thumbSize + 28)

      hourAxis
    }
  }

  // MARK: Pieces

  private enum Edge { case start, end }

  private func handle(at cx: CGFloat, date: Date, edge: Edge, width: CGFloat) -> some View {
    VStack(spacing: 6) {
      Text(label(date))
        .font(.caption.weight(.semibold))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Style.primaryColor.opacity(locked ? 0.4 : 1), in: Capsule())

      Circle()
        .fill(.white)
        .frame(width: thumbSize, height: thumbSize)
        .overlay(Circle().stroke(Style.primaryColor.opacity(locked ? 0.4 : 1), lineWidth: 3))
        .shadow(color: .black.opacity(0.12), radius: 3, y: 1)
    }
    .opacity(locked ? 0.6 : 1)
    .offset(x: cx - thumbSize / 2)
    .gesture(locked ? nil : DragGesture(coordinateSpace: .named(Self.trackSpace))
      .onChanged { value in
        let m = minute(forX: value.location.x, width: width)
        switch edge {
        case .start:
          start = dateAtMinute(min(m, minutes(of: end) - minGap))
        case .end:
          end = dateAtMinute(max(m, minutes(of: start) + minGap))
        }
      })
  }

  private func nowMarker(at cx: CGFloat, date: Date) -> some View {
    VStack(spacing: 2) {
      Text("now \(label(date))")
        .font(.caption2.weight(.semibold))
        .foregroundStyle(Style.primaryColor)
        .fixedSize()
      Rectangle()
        .fill(Style.primaryColor)
        .frame(width: 2, height: thumbSize + 6)
    }
    .offset(x: cx - 1, y: -2)
  }

  private var hourAxis: some View {
    GeometryReader { geo in
      let w = geo.size.width
      ForEach([0, 6, 12, 18, 24], id: \.self) { hour in
        let cx = w * CGFloat(hour) / 24
        Text(hour == 24 ? "24:00" : String(format: "%02d:00", hour))
          .font(.caption2)
          .foregroundStyle(.secondary)
          .fixedSize()
          .frame(width: 44)
          .offset(x: min(max(cx - 22, 0), w - 44))
      }
    }
    .frame(height: 14)
  }
}

struct ScheduleRangeSlider_Previews: PreviewProvider {
  struct Harness: View {
    @State var start = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
    @State var end = Calendar.current.date(bySettingHour: 17, minute: 0, second: 0, of: Date())!
    var locked: Bool
    var now: Date?
    var body: some View {
      ScheduleRangeSlider(start: $start, end: $end, locked: locked, now: now)
        .padding(24)
    }
  }
  static var previews: some View {
    Group {
      Harness(locked: false, now: nil)
        .previewDisplayName("Editable")
      Harness(locked: true, now: Calendar.current.date(bySettingHour: 13, minute: 36, second: 0, of: Date()))
        .previewDisplayName("Locked + now")
    }
    .previewLayout(.sizeThatFits)
  }
}
