//
//  ScheduleCard.swift
//  ScreenTimeShield
//

import SwiftUI

/// Card wrapping the 24h schedule range slider, with a locked caption while active.
struct ScheduleCard: View {
  @EnvironmentObject var model: Model

  private let cardCorner = Style.Radius.card

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Picker("Schedule mode", selection: $model.blockOutsideWindow) {
        Text("Block these hours").tag(false)
        Text("Allow only these hours").tag(true)
      }
      .pickerStyle(.segmented)
      .disabled(model.insideInterval)

      ScheduleRangeSlider(
        start: $model.start,
        end: $model.end,
        locked: model.insideInterval,
        now: model.insideInterval ? Date() : nil,
        inverted: model.blockOutsideWindow
      )
      if model.insideInterval {
        Label("Schedule locked while a block is active", systemImage: "lock")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
      } else if model.blockOutsideWindow {
        Text("Blocking all day except this window")
          .font(.caption)
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, alignment: .center)
      }
    }
    .padding(Style.Spacing.md)
    .background(.background.opacity(0.6))
    .clipShape(RoundedRectangle(cornerRadius: cardCorner))
    .overlay(RoundedRectangle(cornerRadius: cardCorner).stroke(.secondary.opacity(0.12)))
  }
}

#Preview {
  ScheduleCard()
    .environmentObject(Model())
    .padding()
}
